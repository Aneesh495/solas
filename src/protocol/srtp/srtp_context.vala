/*
 * Solas: Real-Time WebRTC Media Engine
 * SRTP Key Derivation Function (KDF RFC 3711 Section 4.3)
 */

using Solas.Core;
using Solas.Crypto;

namespace Solas.Protocol.Srtp {

    public enum SrtpCryptoSuite {
        AES_CM_128_HMAC_SHA1_80 = 1,
        AES_CM_128_HMAC_SHA1_32 = 2
    }

    public class SrtpKeys : Object {
        public uint8[] rtp_enc_key;
        public uint8[] rtp_auth_key;
        public uint8[] rtp_salt;
        public uint8[] rtcp_enc_key;
        public uint8[] rtcp_auth_key;
        public uint8[] rtcp_salt;

        public SrtpKeys() {
            this.rtp_enc_key = new uint8[16];
            this.rtp_auth_key = new uint8[20];
            this.rtp_salt = new uint8[14];
            this.rtcp_enc_key = new uint8[16];
            this.rtcp_auth_key = new uint8[20];
            this.rtcp_salt = new uint8[14];
        }
    }

    public class SrtpContext : Object {

        /**
         * Derives session keys from master key and master salt using AES-128-CTR PRF (RFC 3711).
         * Key label constants:
         * 0x00: SRTP encryption
         * 0x01: SRTP authentication
         * 0x02: SRTP salting key
         * 0x03: SRTCP encryption
         * 0x04: SRTCP authentication
         * 0x05: SRTCP salting key
         */
        public static SrtpKeys derive_keys(uint8[] master_key, uint8[] master_salt) throws CryptoError {
            if (master_key.length != 16 || master_salt.length != 14) {
                throw new CryptoError.INVALID_KEY_LENGTH("Master key must be 16 bytes and salt 14 bytes");
            }

            var keys = new SrtpKeys();
            keys.rtp_enc_key = prf(master_key, master_salt, 0x00, 16);
            keys.rtp_auth_key = prf(master_key, master_salt, 0x01, 20);
            keys.rtp_salt = prf(master_key, master_salt, 0x02, 14);

            keys.rtcp_enc_key = prf(master_key, master_salt, 0x03, 16);
            keys.rtcp_auth_key = prf(master_key, master_salt, 0x04, 20);
            keys.rtcp_salt = prf(master_key, master_salt, 0x05, 14);

            return keys;
        }

        private static uint8[] prf(uint8[] key, uint8[] salt, uint8 label, size_t out_len) throws CryptoError {
            /* IV = salt XOR (label << 48) */
            uint8[] iv = new uint8[16];
            Memory.copy(iv, salt, 14);
            iv[14] = 0;
            iv[15] = 0;

            /* XOR label into byte 7 */
            iv[7] ^= label;

            uint8[] input = new uint8[out_len]; /* Zero input for CTR keystream generation */
            return Engine.aes_ctr(key, iv, input);
        }
    }
}
