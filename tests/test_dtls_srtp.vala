/*
 * Solas: Real-Time WebRTC Media Engine
 * DTLS-SRTP RFC 5764 Exporter and Record Layer Verification Suite
 */

using Solas.Core;
using Solas.Crypto;
using Solas.Protocol.Dtls;

public class TestDtlsSrtp : Object {

    public static void test_dtls_record_layer() {
        uint8[] payload = { 0x01, 0x02, 0x03, 0x04, 0x05 };
        var record = new DtlsRecord(DtlsContentType.HANDSHAKE, payload, 1, 42, DTLS_VERSION_1_2);

        uint8[] wire = record.serialize();
        /* Header is 13 bytes + 5 bytes payload = 18 bytes */
        assert(wire.length == 18);
        assert(wire[0] == (uint8) DtlsContentType.HANDSHAKE);
        assert(wire[1] == 0xFE && wire[2] == 0xFD);
        assert(wire[3] == 0x00 && wire[4] == 0x01); /* Epoch 1 */
        assert(wire[11] == 0x00 && wire[12] == 0x05); /* Length: 5 bytes */

        /* Parse */
        var parsed = DtlsRecord.parse(wire);
        assert(parsed != null);
        assert(parsed.content_type == DtlsContentType.HANDSHAKE);
        assert(parsed.version == DTLS_VERSION_1_2);
        assert(parsed.epoch == 1);
        assert(parsed.sequence_number == 42);
        assert(parsed.fragment.length == 5);
        assert(parsed.fragment[0] == 0x01);
        assert(parsed.fragment[4] == 0x05);
    }

    public static void test_srtp_key_exporter() {
        uint8[] master_secret = new uint8[48];
        for (int i = 0; i < 48; i++) master_secret[i] = (uint8) (i + 1);

        uint8[] client_random = new uint8[32];
        for (int i = 0; i < 32; i++) client_random[i] = (uint8) (0x10 ^ i);

        uint8[] server_random = new uint8[32];
        for (int i = 0; i < 32; i++) server_random[i] = (uint8) (0x20 ^ i);

        try {
            /* 1. AES-128 CM HMAC-SHA1-80: 16 key + 14 salt */
            var keys = DtlsSrtpExporter.export_keys(master_secret, client_random, server_random,
                                                    SrtpProtectionProfile.SRTP_AES128_CM_HMAC_SHA1_80);
            assert(keys.client_master_key.length == 16);
            assert(keys.server_master_key.length == 16);
            assert(keys.client_master_salt.length == 14);
            assert(keys.server_master_salt.length == 14);

            /* Keys must not be zeroed */
            bool client_key_nonzero = false;
            for (int i = 0; i < 16; i++) {
                if (keys.client_master_key[i] != 0) client_key_nonzero = true;
            }
            assert(client_key_nonzero);

            /* 2. AEAD-AES-128-GCM: 16 key + 12 salt */
            var gcm_keys = DtlsSrtpExporter.export_keys(master_secret, client_random, server_random,
                                                        SrtpProtectionProfile.SRTP_AEAD_AES_128_GCM);
            assert(gcm_keys.client_master_key.length == 16);
            assert(gcm_keys.server_master_key.length == 16);
            assert(gcm_keys.client_master_salt.length == 12);
            assert(gcm_keys.server_master_salt.length == 12);
        } catch (GLib.Error e) {
            assert_not_reached();
        }

        /* Profile Negotiation */
        SrtpProtectionProfile[] offered = {
            SrtpProtectionProfile.SRTP_AES128_CM_HMAC_SHA1_32,
            SrtpProtectionProfile.SRTP_AES128_CM_HMAC_SHA1_80
        };
        var negotiated = DtlsSrtpExporter.negotiate_profile(offered);
        assert(negotiated == SrtpProtectionProfile.SRTP_AES128_CM_HMAC_SHA1_80);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/dtls_srtp/record_layer", test_dtls_record_layer);
        Test.add_func("/dtls_srtp/key_exporter", test_srtp_key_exporter);

        return Test.run();
    }
}
