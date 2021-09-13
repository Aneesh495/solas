/*
 * Unit tests for Solas.Protocol.Rtp
 */
using Solas.Core;
using Solas.Protocol.Rtp;

void test_rtp_packet_roundtrip() {
    var pkt = new RtpPacket();
    pkt.payload_type = 96; /* VP8 */
    pkt.sequence_number = 42100;
    pkt.timestamp = 3600000;
    pkt.ssrc = 0xA1B2C3D4U;
    pkt.marker = true;
    pkt.payload = "Mock VP8 Keyframe Data Bytes".data;

    /* Add Audio Level Extension (ID 1) */
    pkt.add_extension(RtpHeaderExtension.create_audio_level(1, true, 45));

    /* Add TWCC sequence number extension (ID 2) */
    pkt.add_extension(RtpHeaderExtension.create_transport_sequence_number(2, 512));

    uint8[] wire = pkt.serialize();
    assert(wire.length > 12);

    try {
        var parsed = RtpPacket.parse(wire);
        assert(parsed.version == 2);
        assert(parsed.payload_type == 96);
        assert(parsed.sequence_number == 42100);
        assert(parsed.timestamp == 3600000);
        assert(parsed.ssrc == 0xA1B2C3D4U);
        assert(parsed.marker == true);
        assert(parsed.extension == true);
        assert(parsed.extensions.size == 2);

        var ext1 = parsed.find_extension_by_id(1);
        assert(ext1 != null);
        bool vad;
        uint8 level;
        assert(ext1.parse_audio_level(out vad, out level));
        assert(vad == true);
        assert(level == 45);

        var ext2 = parsed.find_extension_by_id(2);
        assert(ext2 != null);
        uint16 tseq;
        assert(ext2.parse_transport_sequence_number(out tseq));
        assert(tseq == 512);

        assert(parsed.payload.length == pkt.payload.length);
        assert((string) parsed.payload == "Mock VP8 Keyframe Data Bytes");
    } catch (GLib.Error e) {
        assert_not_reached();
    }
}

void test_sequence_unwrapper_rollover() {
    var unwrapper = new SequenceUnwrapper();

    /* Start at 65534 */
    uint64 u0 = unwrapper.unwrap(65534);
    assert(u0 == 65534ULL);

    uint64 u1 = unwrapper.unwrap(65535);
    assert(u1 == 65535ULL);

    /* Rollover to 0 */
    uint64 u2 = unwrapper.unwrap(0);
    assert(u2 == 65536ULL);

    uint64 u3 = unwrapper.unwrap(1);
    assert(u3 == 65537ULL);

    /* Out of order: arrival of 0 after 1 */
    uint64 u_dup = unwrapper.unwrap(0);
    assert(u_dup == 65536ULL);

    assert(unwrapper.highest_sequence_number == 65537ULL);
    assert(unwrapper.packets_received == 5);
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/rtp/packet_roundtrip", test_rtp_packet_roundtrip);
    Test.add_func("/solas/rtp/sequence_unwrapper_rollover", test_sequence_unwrapper_rollover);
    Test.run();
}
