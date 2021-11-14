/*
 * Solas: Real-Time WebRTC Media Engine
 * DTLS-SRTP Protocol Types and Protection Profiles (RFC 5764 / RFC 7714)
 */

namespace Solas.Protocol.Dtls {

    public enum DtlsContentType {
        NONE = 0,
        CHANGE_CIPHER_SPEC = 20,
        ALERT = 21,
        HANDSHAKE = 22,
        APPLICATION_DATA = 23
    }

    public enum DtlsHandshakeType {
        HELLO_REQUEST = 0,
        CLIENT_HELLO = 1,
        SERVER_HELLO = 2,
        HELLO_VERIFY_REQUEST = 3,
        CERTIFICATE = 11,
        SERVER_KEY_EXCHANGE = 12,
        CERTIFICATE_REQUEST = 13,
        SERVER_HELLO_DONE = 14,
        CERTIFICATE_VERIFY = 15,
        CLIENT_KEY_EXCHANGE = 16,
        FINISHED = 20
    }

    public enum SrtpProtectionProfile {
        NONE = 0x0000,
        SRTP_AES128_CM_HMAC_SHA1_80 = 0x0001,
        SRTP_AES128_CM_HMAC_SHA1_32 = 0x0002,
        SRTP_AEAD_AES_128_GCM = 0x0007,
        SRTP_AEAD_AES_256_GCM = 0x0008
    }

    public class SrtpKeyMaterial : Object {
        public uint8[] client_master_key;
        public uint8[] server_master_key;
        public uint8[] client_master_salt;
        public uint8[] server_master_salt;

        public SrtpKeyMaterial(size_t key_len = 16, size_t salt_len = 14) {
            this.client_master_key = new uint8[key_len];
            this.server_master_key = new uint8[key_len];
            this.client_master_salt = new uint8[salt_len];
            this.server_master_salt = new uint8[salt_len];
        }
    }
}
