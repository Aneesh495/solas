/*
 * Unit tests for Solas.Protocol.Srtp
 */
using Solas.Core;
using Solas.Crypto;
using Solas.Protocol.Rtp;
using Solas.Protocol.Srtp;

void test_srtp_kdf_and_replay_window() {
    uint8[] master_key = {
        0xE1, 0xF9, 0x7A, 0x0D, 0x3E, 0x01, 0x8B, 0xE0,
        0xD6, 0x4F, 0xA3, 0x2C, 0x06, 0xDE, 0x41, 0x39
    };
    uint8[] master_salt = {
        0x0E, 0xC6, 0x75, 0xAD, 0x49, 0x8A, 0xFE, 0xEB,
        0xB6, 0x96, 0x0B, 0x3A, 0xAB, 0xE6
    };

    try {
        var keys = SrtpContext.derive_keys(master_key, master_salt);
        assert(keys.rtp_enc_key.length == 16);
        assert(keys.rtp_auth_key.length == 20);
        assert(keys.rtp_salt.length == 14);
        assert(keys.rtcp_enc_key.length == 16);
        assert(keys.rtcp_auth_key.length == 20);
        assert(keys.rtcp_salt.length == 14);
    } catch (GLib.Error e) {
        assert_not_reached();
    }

    /* Replay window test */
    var rw = new ReplayWindow();
    assert(rw.check(10));
    rw.update(10);
    assert(!rw.check(10)); /* Replay duplicate rejected */

    assert(rw.check(11));
    rw.update(11);

    assert(rw.check(9)); /* Within window of 64 packets */
    rw.update(9);
    assert(!rw.check(9)); /* Duplicate rejected */

    /* Packet too old (>64 packets behind highest) */
    assert(rw.check(200));
    rw.update(200);
    assert(!rw.check(10)); /* Old packet rejected */
}

void test_srtp_packet_protection_roundtrip() {
    uint8[] master_key = {
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
    };
    uint8[] master_salt = {
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
        0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D
    };

    try {
        var keys = SrtpContext.derive_keys(master_key, master_salt);
        var session = new SrtpSession(keys);

        var rtp = new RtpPacket();
        rtp.payload_type = 96;
        rtp.sequence_number = 100;
        rtp.timestamp = 90000;
        rtp.ssrc = 0x12345678U;
        rtp.payload = "Encrypted WebRTC Media Payload".data;

        uint8[] raw_rtp = rtp.serialize();
        size_t header_len = 12;

        /* Protect */
        uint8[] protected_bytes = session.protect_rtp(raw_rtp, header_len);
        assert(protected_bytes.length == raw_rtp.length + session.auth_tag_length);

        /* Payload in protected_bytes must be encrypted (different from original) */
        bool payload_different = false;
        for (size_t i = 0; i < rtp.payload.length; i++) {
            if (protected_bytes[header_len + i] != rtp.payload[i]) {
                payload_different = true;
                break;
            }
        }
        assert(payload_different);

        /* Unprotect with receiver session */
        var rx_session = new SrtpSession(keys);
        uint8[] unprotected_bytes = rx_session.unprotect_rtp(protected_bytes, header_len);
        assert(unprotected_bytes.length == raw_rtp.length);

        var parsed = RtpPacket.parse(unprotected_bytes);
        assert(parsed.sequence_number == 100);
        assert((string) parsed.payload == "Encrypted WebRTC Media Payload");

        /* Replay attack test: second unprotect of identical packet must fail */
        bool caught_replay = false;
        try {
            rx_session.unprotect_rtp(protected_bytes, header_len);
        } catch (SrtpError.REPLAY_DETECTED e) {
            caught_replay = true;
        }
        assert(caught_replay);

        /* Tampering test: corrupt 1 byte of auth tag */
        protected_bytes[protected_bytes.length - 1] ^= 0xFF;
        bool caught_tamper = false;
        try {
            var rx_session2 = new SrtpSession(keys);
            rx_session2.unprotect_rtp(protected_bytes, header_len);
        } catch (SrtpError.AUTH_FAILED e) {
            caught_tamper = true;
        }
        assert(caught_tamper);

    } catch (GLib.Error e) {
        assert_not_reached();
    }
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/srtp/kdf_and_replay", test_srtp_kdf_and_replay_window);
    Test.add_func("/solas/srtp/packet_protection_roundtrip", test_srtp_packet_protection_roundtrip);
    Test.run();
}
