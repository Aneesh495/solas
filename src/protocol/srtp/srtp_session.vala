/*
 * Solas: Real-Time WebRTC Media Engine
 * SRTP and SRTCP Packet Protection and Unprotection Engine (RFC 3711)
 */

using Solas.Core;
using Solas.Crypto;
using Solas.Protocol.Rtp;
using Solas.Protocol.Rtcp;

namespace Solas.Protocol.Srtp {

    public errordomain SrtpError {
        AUTH_FAILED,
        REPLAY_DETECTED,
        PACKET_TOO_SHORT,
        CRYPTO_FAILURE
    }

    public class SrtpSession : Object {
        private SrtpKeys keys;
        private SrtpCryptoSuite suite;
        private ReplayWindow rtp_replay;
        private ReplayWindow rtcp_replay;
        private uint32 roc;
        private uint16 s_l;
        private uint32 rtcp_index;

        public const size_t AUTH_TAG_LEN_80 = 10;
        public const size_t AUTH_TAG_LEN_32 = 4;

        public SrtpSession(SrtpKeys keys, SrtpCryptoSuite suite = SrtpCryptoSuite.AES_CM_128_HMAC_SHA1_80) {
            this.keys = keys;
            this.suite = suite;
            this.rtp_replay = new ReplayWindow();
            this.rtcp_replay = new ReplayWindow();
            this.roc = 0;
            this.s_l = 0;
            this.rtcp_index = 0;
        }

        public size_t auth_tag_length {
            get { return (this.suite == SrtpCryptoSuite.AES_CM_128_HMAC_SHA1_80) ? AUTH_TAG_LEN_80 : AUTH_TAG_LEN_32; }
        }

        /**
         * Protects an RTP packet in place: encrypts payload and appends HMAC-SHA1 auth tag.
         */
        public uint8[] protect_rtp(uint8[] rtp_data, size_t header_len) throws SrtpError {
            if (rtp_data.length < header_len) {
                throw new SrtpError.PACKET_TOO_SHORT("RTP data shorter than header length");
            }

            var reader = new ByteReader(rtp_data);
            uint16 seq = 0;
            uint32 ssrc = 0;
            try {
                reader.skip(2);
                seq = reader.read_uint16_be();
                reader.skip(4);
                ssrc = reader.read_uint32_be();
            } catch (ReaderError e) {
                throw new SrtpError.PACKET_TOO_SHORT("Cannot parse header fields for SRTP: %s".printf(e.message));
            }

            /* Update ROC */
            if (this.s_l == 0 && this.roc == 0) {
                this.s_l = seq;
            } else {
                if (this.s_l < 32768) {
                    if (seq - this.s_l > 32768) {
                        /* Wrap backwards or huge misorder */
                    } else if (seq > this.s_l) {
                        this.s_l = seq;
                    }
                } else {
                    if (this.s_l - seq > 32768) {
                        this.roc++;
                        this.s_l = seq;
                    } else if (seq > this.s_l) {
                        this.s_l = seq;
                    }
                }
            }

            uint64 packet_index = ((uint64) this.roc << 16) | (uint64) seq;

            /* Compute AES-CTR IV (16 bytes):
             * IV = (salt * 2^16) XOR (ssrc * 2^64) XOR (packet_index * 2^16) */
            uint8[] iv = build_rtp_iv(ssrc, packet_index);

            size_t payload_len = rtp_data.length - header_len;
            uint8[] payload = new uint8[payload_len];
            Memory.copy(payload, &rtp_data[header_len], payload_len);

            try {
                uint8[] enc_payload = Engine.aes_ctr(this.keys.rtp_enc_key, iv, payload);

                /* Compute auth tag over: [RTP Header | Encrypted Payload | ROC (4 bytes)] */
                var auth_writer = new ByteWriter(rtp_data.length + 4);
                uint8[] header = new uint8[header_len];
                Memory.copy(header, rtp_data, header_len);
                auth_writer.write_bytes(header);
                auth_writer.write_bytes(enc_payload);
                auth_writer.write_uint32_be(this.roc);

                uint8[] full_mac = Engine.hmac_sha1(this.keys.rtp_auth_key, auth_writer.to_array());
                uint8[] tag = new uint8[this.auth_tag_length];
                Memory.copy(tag, full_mac, this.auth_tag_length);

                /* Output: [RTP Header | Encrypted Payload | Auth Tag] */
                var out_writer = new ByteWriter(rtp_data.length + this.auth_tag_length);
                out_writer.write_bytes(header);
                out_writer.write_bytes(enc_payload);
                out_writer.write_bytes(tag);
                return out_writer.to_array();

            } catch (CryptoError e) {
                throw new SrtpError.CRYPTO_FAILURE("SRTP encryption failed: %s".printf(e.message));
            }
        }

        /**
         * Unprotects an SRTP packet: verifies auth tag, updates replay window, and decrypts.
         */
        public uint8[] unprotect_rtp(uint8[] srtp_data, size_t header_len) throws SrtpError {
            if (srtp_data.length < header_len + this.auth_tag_length) {
                throw new SrtpError.PACKET_TOO_SHORT("SRTP packet smaller than header + tag");
            }

            size_t enc_payload_len = srtp_data.length - header_len - this.auth_tag_length;
            var reader = new ByteReader(srtp_data);
            uint16 seq = 0;
            uint32 ssrc = 0;
            try {
                reader.skip(2);
                seq = reader.read_uint16_be();
                reader.skip(4);
                ssrc = reader.read_uint32_be();
            } catch (ReaderError e) {
                throw new SrtpError.PACKET_TOO_SHORT("Cannot parse header fields: %s".printf(e.message));
            }

            uint32 est_roc = estimate_roc(seq);
            uint64 packet_index = ((uint64) est_roc << 16) | (uint64) seq;

            if (!this.rtp_replay.check(packet_index)) {
                throw new SrtpError.REPLAY_DETECTED("Replayed or duplicate SRTP packet rejected");
            }

            /* Verify HMAC tag */
            size_t tag_offset = srtp_data.length - this.auth_tag_length;
            try {
                var auth_writer = new ByteWriter(tag_offset + 4);
                uint8[] protected_bytes = new uint8[tag_offset];
                Memory.copy(protected_bytes, srtp_data, tag_offset);
                auth_writer.write_bytes(protected_bytes);
                auth_writer.write_uint32_be(est_roc);

                uint8[] computed_mac = Engine.hmac_sha1(this.keys.rtp_auth_key, auth_writer.to_array());
                for (size_t i = 0; i < this.auth_tag_length; i++) {
                    if (srtp_data[tag_offset + i] != computed_mac[i]) {
                        throw new SrtpError.AUTH_FAILED("SRTP authentication tag mismatch");
                    }
                }

                /* Authenticated successfully: update replay window */
                this.rtp_replay.update(packet_index);

                /* Decrypt payload */
                uint8[] iv = build_rtp_iv(ssrc, packet_index);
                uint8[] enc_payload = new uint8[enc_payload_len];
                Memory.copy(enc_payload, &srtp_data[header_len], enc_payload_len);
                uint8[] dec_payload = Engine.aes_ctr(this.keys.rtp_enc_key, iv, enc_payload);

                var out_writer = new ByteWriter(header_len + enc_payload_len);
                uint8[] hdr = new uint8[header_len];
                Memory.copy(hdr, srtp_data, header_len);
                out_writer.write_bytes(hdr);
                out_writer.write_bytes(dec_payload);
                return out_writer.to_array();

            } catch (CryptoError e) {
                throw new SrtpError.CRYPTO_FAILURE("Decryption failure: %s".printf(e.message));
            }
        }

        private uint32 estimate_roc(uint16 seq) {
            if (this.s_l < 32768) {
                if (seq - this.s_l > 32768) {
                    return (this.roc > 0) ? (this.roc - 1) : 0;
                } else {
                    return this.roc;
                }
            } else {
                if (this.s_l - seq > 32768) {
                    return this.roc + 1;
                } else {
                    return this.roc;
                }
            }
        }

        private uint8[] build_rtp_iv(uint32 ssrc, uint64 packet_index) {
            uint8[] iv = new uint8[16];
            Memory.copy(iv, this.keys.rtp_salt, 14);

            /* XOR SSRC at bytes 4..7 */
            iv[4] ^= (uint8) ((ssrc >> 24) & 0xFF);
            iv[5] ^= (uint8) ((ssrc >> 16) & 0xFF);
            iv[6] ^= (uint8) ((ssrc >> 8) & 0xFF);
            iv[7] ^= (uint8) (ssrc & 0xFF);

            /* XOR packet index at bytes 8..13 */
            for (int i = 0; i < 6; i++) {
                iv[13 - i] ^= (uint8) ((packet_index >> (i * 8)) & 0xFF);
            }

            return iv;
        }
    }
}
