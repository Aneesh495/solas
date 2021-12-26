/*
 * Solas: Real-Time WebRTC Media Engine
 * RFC 9605 Secure Frame (SFrame) Media Encryptor and Transformer
 */

using Solas.Core;

namespace Solas.Crypto {

    public errordomain SFrameError {
        UNKNOWN_KEY,
        BUFFER_TOO_SMALL,
        AUTHENTICATION_FAILED,
        REPLAY_DETECTED,
        INVALID_HEADER
    }

    public class SFrameKey : Object {
        public uint64 key_id { get; private set; }
        public uint8[] enc_key;
        public uint8[] auth_key;
        public uint64 max_counter { get; set; default = 0; }

        public SFrameKey(uint64 key_id, uint8[] enc_key, uint8[] auth_key) {
            this.key_id = key_id;
            this.enc_key = enc_key;
            this.auth_key = auth_key;
            this.max_counter = 0;
        }
    }

    public class SFrameCipher : Object {
        private Gee.HashMap<string, SFrameKey> keys;
        public int tag_length { get; construct set; default = 16; }

        public SFrameCipher(int tag_len = 16) {
            this.keys = new Gee.HashMap<string, SFrameKey>();
            this.tag_length = tag_len;
        }

        public void add_key(uint64 key_id, uint8[] enc_key, uint8[] auth_key) {
            this.keys.set(key_id.to_string(), new SFrameKey(key_id, enc_key, auth_key));
        }

        public bool has_key(uint64 key_id) {
            return this.keys.has_key(key_id.to_string());
        }

        /**
         * Encrypt a raw media frame using SFrame format.
         * Format:
         *   [1 byte Header: (kid_len << 4) | ctr_len]
         *   [kid_len bytes: Key ID (big endian)]
         *   [ctr_len bytes: Counter (big endian)]
         *   [Ciphertext: AES-CTR(enc_key, iv, plaintext)]
         *   [Tag: HMAC-SHA256(auth_key, header + ciphertext)[0:tag_len]]
         */
        public uint8[] encrypt_frame(uint64 key_id, uint64 counter, uint8[] plaintext) throws SFrameError {
            string kid_str = key_id.to_string();
            if (!this.keys.has_key(kid_str)) {
                throw new SFrameError.UNKNOWN_KEY("Key ID %llu not configured".printf(key_id));
            }
            var sframe_key = this.keys.get(kid_str);

            // Compute variable length sizes
            uint8 kid_len = get_varint_len(key_id);
            uint8 ctr_len = get_varint_len(counter);

            var writer = new ByteWriter();
            // Header byte: upper 4 bits = kid_len, lower 4 bits = ctr_len
            uint8 header_byte = (uint8) (((kid_len & 0x0F) << 4) | (ctr_len & 0x0F));
            writer.write_uint8(header_byte);

            write_varint(writer, key_id, kid_len);
            write_varint(writer, counter, ctr_len);

            uint8[] header_bytes = writer.to_array();

            // Construct 16-byte AES-CTR IV: IV = Big-Endian Counter placed in lower 8 bytes
            uint8[] iv = new uint8[16];
            for (int i = 0; i < 8; i++) {
                iv[15 - i] = (uint8) ((counter >> (i * 8)) & 0xFF);
            }

            uint8[] ciphertext;
            try {
                ciphertext = Engine.aes_ctr(sframe_key.enc_key, iv, plaintext);
            } catch (CryptoError e) {
                throw new SFrameError.AUTHENTICATION_FAILED("AES-CTR failure: " + e.message);
            }

            // Authenticate header + ciphertext
            uint8[] to_auth = new uint8[header_bytes.length + ciphertext.length];
            for (int i = 0; i < header_bytes.length; i++) {
                to_auth[i] = header_bytes[i];
            }
            for (int i = 0; i < ciphertext.length; i++) {
                to_auth[header_bytes.length + i] = ciphertext[i];
            }

            uint8[] full_tag;
            try {
                full_tag = Engine.hmac_sha256(sframe_key.auth_key, to_auth);
            } catch (CryptoError e) {
                throw new SFrameError.AUTHENTICATION_FAILED("HMAC computation failed: " + e.message);
            }

            // Assemble output: header + ciphertext + truncated tag
            var final_writer = new ByteWriter();
            final_writer.write_bytes(header_bytes);
            final_writer.write_bytes(ciphertext);

            uint8[] tag = new uint8[this.tag_length];
            for (int i = 0; i < this.tag_length; i++) {
                tag[i] = full_tag[i];
            }
            final_writer.write_bytes(tag);

            if (counter > sframe_key.max_counter) {
                sframe_key.max_counter = counter;
            }
            return final_writer.to_array();
        }

        /**
         * Decrypt and authenticate an SFrame packet.
         */
        public uint8[] decrypt_frame(uint8[] packet, out uint64 out_key_id, out uint64 out_counter) throws SFrameError {
            if (packet.length < 1 + this.tag_length) {
                throw new SFrameError.BUFFER_TOO_SMALL("Packet too small for SFrame");
            }

            var reader = new ByteReader(packet);
            uint8 header_byte;
            try {
                header_byte = reader.read_uint8();
            } catch (ReaderError e) {
                throw new SFrameError.INVALID_HEADER("Failed reading header byte");
            }

            uint8 kid_len = (uint8) ((header_byte >> 4) & 0x0F);
            uint8 ctr_len = (uint8) (header_byte & 0x0F);

            if (kid_len == 0 || kid_len > 8 || ctr_len == 0 || ctr_len > 8) {
                throw new SFrameError.INVALID_HEADER("Invalid kid_len or ctr_len");
            }

            if (packet.length < (1 + kid_len + ctr_len + this.tag_length)) {
                throw new SFrameError.BUFFER_TOO_SMALL("Packet too small for SFrame variable header and tag");
            }

            uint64 kid = 0;
            uint64 ctr = 0;
            try {
                for (int i = 0; i < kid_len; i++) {
                    kid = (kid << 8) | (uint64) reader.read_uint8();
                }
                for (int i = 0; i < ctr_len; i++) {
                    ctr = (ctr << 8) | (uint64) reader.read_uint8();
                }
            } catch (ReaderError e) {
                throw new SFrameError.INVALID_HEADER("Failed reading kid/counter");
            }

            out_key_id = kid;
            out_counter = ctr;

            string kid_str = kid.to_string();
            if (!this.keys.has_key(kid_str)) {
                throw new SFrameError.UNKNOWN_KEY("Key ID %llu not found".printf(kid));
            }
            var sframe_key = this.keys.get(kid_str);

            // Replay protection: if counter is strictly less than max_counter minus window (128), reject
            if (ctr + 128 < sframe_key.max_counter) {
                throw new SFrameError.REPLAY_DETECTED("Frame counter too old or replayed: %llu vs %llu".printf(ctr, sframe_key.max_counter));
            }

            size_t header_len = 1 + kid_len + ctr_len;
            size_t ciphertext_len = packet.length - header_len - this.tag_length;

            // Split into to_auth (header + ciphertext) and tag
            uint8[] to_auth = new uint8[header_len + ciphertext_len];
            for (size_t i = 0; i < header_len + ciphertext_len; i++) {
                to_auth[i] = packet[i];
            }

            uint8[] expected_tag;
            try {
                expected_tag = Engine.hmac_sha256(sframe_key.auth_key, to_auth);
            } catch (CryptoError e) {
                throw new SFrameError.AUTHENTICATION_FAILED("HMAC verification failed");
            }

            // Constant-time compare tag
            uint8 diff = 0;
            for (int i = 0; i < this.tag_length; i++) {
                diff |= (uint8) (packet[header_len + ciphertext_len + i] ^ expected_tag[i]);
            }
            if (diff != 0) {
                throw new SFrameError.AUTHENTICATION_FAILED("Authentication tag mismatch");
            }

            // Extract ciphertext
            uint8[] ciphertext = new uint8[ciphertext_len];
            for (size_t i = 0; i < ciphertext_len; i++) {
                ciphertext[i] = packet[header_len + i];
            }

            // Decrypt AES-CTR
            uint8[] iv = new uint8[16];
            for (int i = 0; i < 8; i++) {
                iv[15 - i] = (uint8) ((ctr >> (i * 8)) & 0xFF);
            }

            uint8[] plaintext;
            try {
                plaintext = Engine.aes_ctr(sframe_key.enc_key, iv, ciphertext);
            } catch (CryptoError e) {
                throw new SFrameError.AUTHENTICATION_FAILED("AES-CTR decryption failure");
            }

            if (ctr > sframe_key.max_counter) {
                sframe_key.max_counter = ctr;
            }

            return plaintext;
        }

        private static uint8 get_varint_len(uint64 val) {
            if (val <= 0xFF) return 1;
            if (val <= 0xFFFF) return 2;
            if (val <= 0xFFFFFF) return 3;
            if (val <= 0xFFFFFFFF) return 4;
            return 8;
        }

        private static void write_varint(ByteWriter writer, uint64 val, uint8 len) {
            for (int i = len - 1; i >= 0; i--) {
                writer.write_uint8((uint8) ((val >> (i * 8)) & 0xFF));
            }
        }
    }
}
