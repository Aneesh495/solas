/*
 * Solas: Real-Time WebRTC Media Engine
 * Cryptographic Services and Security Abstractions
 */

using Solas.Core;

namespace Solas.Crypto {

    public errordomain CryptoError {
        CIPHER_ERROR,
        HMAC_ERROR,
        RNG_ERROR,
        INVALID_KEY_LENGTH
    }

    public class Engine : Object {

        public static uint32 crc32(uint8[] data) {
            return Native.crc32(data);
        }

        public static uint32 stun_fingerprint(uint8[] data) {
            return Native.stun_fingerprint(data);
        }

        public static uint8[] sha1(uint8[] data) throws CryptoError {
            uint8[] md = new uint8[20];
            if (!Native.sha1(data, md)) {
                throw new CryptoError.CIPHER_ERROR("Failed to compute SHA-1 digest");
            }
            return md;
        }

        public static uint8[] sha256(uint8[] data) throws CryptoError {
            uint8[] md = new uint8[32];
            if (!Native.sha256(data, md)) {
                throw new CryptoError.CIPHER_ERROR("Failed to compute SHA-256 digest");
            }
            return md;
        }

        public static uint8[] hmac_sha1(uint8[] key, uint8[] data) throws CryptoError {
            uint8[] mac = new uint8[20];
            size_t mac_len;
            if (!Native.hmac_sha1(key, data, mac, out mac_len)) {
                throw new CryptoError.HMAC_ERROR("Failed to compute HMAC-SHA1");
            }
            return mac;
        }

        public static uint8[] hmac_sha256(uint8[] key, uint8[] data) throws CryptoError {
            uint8[] mac = new uint8[32];
            size_t mac_len;
            if (!Native.hmac_sha256(key, data, mac, out mac_len)) {
                throw new CryptoError.HMAC_ERROR("Failed to compute HMAC-SHA256");
            }
            return mac;
        }

        public static uint8[] aes_ctr(uint8[] key, uint8[] iv_16, uint8[] input) throws CryptoError {
            if (key.length != 16 && key.length != 32) {
                throw new CryptoError.INVALID_KEY_LENGTH("AES-CTR key length must be 16 or 32 bytes");
            }
            if (iv_16.length != 16) {
                throw new CryptoError.CIPHER_ERROR("AES-CTR IV must be 16 bytes");
            }
            uint8[] output = new uint8[input.length];
            if (!Native.aes_ctr(key, iv_16, input, output)) {
                throw new CryptoError.CIPHER_ERROR("AES-CTR encryption/decryption failed");
            }
            return output;
        }

        public static uint8[] random_bytes(size_t count) throws CryptoError {
            uint8[] buf = new uint8[count];
            if (!Native.random_bytes(buf)) {
                throw new CryptoError.RNG_ERROR("Cryptographic RNG failure");
            }
            return buf;
        }

        public static uint32 random_uint32() throws CryptoError {
            uint8[] r = random_bytes(4);
            return (((uint32) r[0] << 24) | ((uint32) r[1] << 16) | ((uint32) r[2] << 8) | (uint32) r[3]);
        }

        public static string random_hex_string(size_t byte_count) throws CryptoError {
            uint8[] r = random_bytes(byte_count);
            var sb = new StringBuilder();
            for (size_t i = 0; i < byte_count; i++) {
                sb.append_printf("%02x", r[i]);
            }
            return sb.str;
        }

        public static string sha256_fingerprint(uint8[] cert_der) throws CryptoError {
            uint8[] hash = sha256(cert_der);
            var sb = new StringBuilder();
            for (int i = 0; i < 32; i++) {
                if (i > 0) sb.append(":");
                sb.append_printf("%02X", hash[i]);
            }
            return sb.str;
        }
    }
}
