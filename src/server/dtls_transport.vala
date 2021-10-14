/*
 * Solas: Real-Time WebRTC Media Engine
 * DTLS Transport and Key Exporter State Machine (RFC 5764 / RFC 8844)
 */

using Solas.Core;
using Solas.Crypto;

namespace Solas.Server {

    public enum DtlsRole {
        AUTO = 0,
        ACTIVE = 1,
        PASSIVE = 2,
        ACTPASS = 3
    }

    public enum DtlsState {
        NEW = 0,
        CONNECTING = 1,
        CONNECTED = 2,
        FAILED = 3,
        CLOSED = 4
    }

    public class DtlsTransport : Object {
        public DtlsRole role { get; set; }
        public DtlsState state { get; private set; }
        public string local_fingerprint { get; private set; }
        public string remote_fingerprint { get; set; }

        /* SRTP 30-byte extracted key material (16-byte master key + 14-byte salt) */
        public uint8[] client_write_key;
        public uint8[] server_write_key;

        public signal void on_state_changed(DtlsState new_state);
        public signal void on_keys_derived();

        public DtlsTransport(DtlsRole role = DtlsRole.ACTPASS) {
            this.role = role;
            this.state = DtlsState.NEW;
            this.remote_fingerprint = "";
            this.client_write_key = new uint8[30];
            this.server_write_key = new uint8[30];

            /* Generate deterministic mock self-signed cert fingerprint for server */
            this.generate_fingerprint();
        }

        private void generate_fingerprint() {
            /* SHA-256 digest of simulated server X.509 certificate */
            uint8[] cert_seed = new uint8[64];
            for (int i = 0; i < 64; i++) {
                cert_seed[i] = (uint8) (0x5A ^ i);
            }

            try {
                uint8[] digest = Solas.Crypto.Engine.sha256(cert_seed);
                var sb = new StringBuilder();
                for (int i = 0; i < digest.length; i++) {
                    if (i > 0) sb.append_c(':');
                    sb.append_printf("%02X", digest[i]);
                }
                this.local_fingerprint = sb.str;
            } catch (CryptoError e) {
                this.local_fingerprint = "00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00";
            }
        }

        /**
         * Simulates completion of the DTLS handshake and derivation of SRTP keys (RFC 5764).
         * RFC 5764 exports 60 bytes: 16-byte client master, 16-byte server master,
         * 14-byte client salt, 14-byte server salt.
         */
        public void simulate_handshake_completion(uint8[] shared_secret) {
            this.state = DtlsState.CONNECTED;

            /* Derive 60 bytes of keying material from shared secret via HMAC-SHA256 */
            uint8[] srtp_label = new uint8[19];
            string label_str = "EXTRACTOR-dtls_srtp";
            Memory.copy(srtp_label, (uint8[]) label_str, 19);

            try {
                uint8[] prf1 = Solas.Crypto.Engine.hmac_sha256(shared_secret, srtp_label);
                uint8[] prf2 = Solas.Crypto.Engine.hmac_sha256(shared_secret, prf1);

                /* Split into client key+salt (30 bytes) and server key+salt (30 bytes) */
                Memory.copy(this.client_write_key, prf1, 30);
                Memory.copy(this.server_write_key, prf2, 30);

                this.on_state_changed(DtlsState.CONNECTED);
                this.on_keys_derived();
            } catch (CryptoError e) {
                this.state = DtlsState.FAILED;
                this.on_state_changed(DtlsState.FAILED);
            }
        }

        public void close() {
            this.state = DtlsState.CLOSED;
            this.on_state_changed(DtlsState.CLOSED);
        }
    }
}
