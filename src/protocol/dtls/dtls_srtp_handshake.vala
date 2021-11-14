/*
 * Solas: Real-Time WebRTC Media Engine
 * DTLS-SRTP Handshake and RFC 5764 Keying Material Exporter
 */

using Solas.Core;
using Solas.Crypto;

namespace Solas.Protocol.Dtls {

    public class DtlsSrtpExporter : Object {
        public const string SRTP_LABEL = "EXTRACTOR-dtls_srtp";

        /**
         * Derives RFC 5764 SRTP key material using HMAC-SHA256 expansion.
         * Required output length: 2 * (master_key_len + master_salt_len)
         * For AES-128: 2 * (16 + 14) = 60 bytes.
         */
        public static SrtpKeyMaterial export_keys(uint8[] master_secret, uint8[] client_random, uint8[] server_random,
                                                 SrtpProtectionProfile profile = SrtpProtectionProfile.SRTP_AES128_CM_HMAC_SHA1_80) throws CryptoError {
            size_t key_len = (profile == SrtpProtectionProfile.SRTP_AEAD_AES_256_GCM) ? 32 : 16;
            size_t salt_len = (profile == SrtpProtectionProfile.SRTP_AEAD_AES_128_GCM || profile == SrtpProtectionProfile.SRTP_AEAD_AES_256_GCM) ? 12 : 14;
            size_t total_len = 2 * (key_len + salt_len);

            /* Seed = label + client_random + server_random */
            var seed_writer = new ByteWriter(SRTP_LABEL.length + client_random.length + server_random.length);
            seed_writer.write_string(SRTP_LABEL);
            seed_writer.write_bytes(client_random);
            seed_writer.write_bytes(server_random);
            uint8[] seed = seed_writer.to_array();

            /* TLS 1.2 PRF Expansion: A(1) = HMAC(secret, seed) */
            uint8[] a1 = Solas.Crypto.Engine.hmac_sha256(master_secret, seed);
            var a1_seed_writer = new ByteWriter(a1.length + seed.length);
            a1_seed_writer.write_bytes(a1);
            a1_seed_writer.write_bytes(seed);
            uint8[] p1 = Solas.Crypto.Engine.hmac_sha256(master_secret, a1_seed_writer.to_array());

            /* A(2) = HMAC(secret, A(1)) */
            uint8[] a2 = Solas.Crypto.Engine.hmac_sha256(master_secret, a1);
            var a2_seed_writer = new ByteWriter(a2.length + seed.length);
            a2_seed_writer.write_bytes(a2);
            a2_seed_writer.write_bytes(seed);
            uint8[] p2 = Solas.Crypto.Engine.hmac_sha256(master_secret, a2_seed_writer.to_array());

            /* Concatenate p1 + p2 (64 bytes generated, need total_len) */
            var out_writer = new ByteWriter(64);
            out_writer.write_bytes(p1);
            out_writer.write_bytes(p2);
            uint8[] full_keystream = out_writer.to_array();

            var mat = new SrtpKeyMaterial(key_len, salt_len);
            size_t offset = 0;

            for (size_t i = 0; i < key_len; i++) mat.client_master_key[i] = full_keystream[offset++];
            for (size_t i = 0; i < key_len; i++) mat.server_master_key[i] = full_keystream[offset++];
            for (size_t i = 0; i < salt_len; i++) mat.client_master_salt[i] = full_keystream[offset++];
            for (size_t i = 0; i < salt_len; i++) mat.server_master_salt[i] = full_keystream[offset++];

            return mat;
        }

        /**
         * Negotiates an agreed SRTP protection profile from client's offered list.
         */
        public static SrtpProtectionProfile negotiate_profile(SrtpProtectionProfile[] offered_profiles) {
            foreach (var p in offered_profiles) {
                if (p == SrtpProtectionProfile.SRTP_AEAD_AES_128_GCM) return p;
                if (p == SrtpProtectionProfile.SRTP_AES128_CM_HMAC_SHA1_80) return p;
            }
            return SrtpProtectionProfile.NONE;
        }
    }
}
