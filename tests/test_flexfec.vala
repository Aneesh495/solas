/*
 * Solas: Real-Time WebRTC Media Engine
 * FlexFEC Packet Recovery Test Suite (RFC 8627)
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Engine.Fec;

public class TestFlexFec : Object {

    public static void test_flexfec_packet_serialization() {
        var fec = new FlexFecPacket(0x12345678, 100, 0x000F);
        fec.length_recovery = 120;
        fec.timestamp_recovery = 90000;
        uint8[] dummy_parity = { 0xDE, 0xAD, 0xBE, 0xEF };
        fec.parity_payload = dummy_parity;

        uint8[] wire = fec.serialize();
        assert(wire.length >= 20);

        try {
            var parsed = FlexFecPacket.parse(wire);
            assert(parsed.protected_ssrc == 0x12345678);
            assert(parsed.seq_base == 100);
            assert(parsed.mask == 0x000F);
            assert(parsed.length_recovery == 120);
            assert(parsed.timestamp_recovery == 90000);
            assert(parsed.parity_payload.length == 4);
            assert(parsed.parity_payload[0] == 0xDE && parsed.parity_payload[3] == 0xEF);
        } catch (FecError e) {
            assert_not_reached();
        }
    }

    public static void test_flexfec_recovery_single_loss() {
        uint32 ssrc = (uint32) 0xAABBCCDD;
        var encoder = new FlexFecEncoder(ssrc, 4);
        var decoder = new FlexFecDecoder(ssrc);

        /* Create 4 media packets */
        var p0 = new RtpPacket();
        p0.ssrc = ssrc;
        p0.sequence_number = 500;
        p0.timestamp = 1000;
        p0.payload = new uint8[] { 0x11, 0x22, 0x33, 0x44 };

        var p1 = new RtpPacket();
        p1.ssrc = ssrc;
        p1.sequence_number = 501;
        p1.timestamp = 4000;
        p1.payload = new uint8[] { 0x55, 0x66, 0x77, 0x88 };

        var p2 = new RtpPacket(); /* THIS PACKET WILL BE LOST! */
        p2.ssrc = ssrc;
        p2.sequence_number = 502;
        p2.timestamp = 7000;
        p2.payload = new uint8[] { 0x99, 0xAA, 0xBB, 0xCC, 0xDD }; /* 5 bytes */

        var p3 = new RtpPacket();
        p3.ssrc = ssrc;
        p3.sequence_number = 503;
        p3.timestamp = 10000;
        p3.payload = new uint8[] { 0x01, 0x02, 0x03, 0x04 };

        /* Feed into encoder */
        assert(encoder.add_packet(p0) == null);
        assert(encoder.add_packet(p1) == null);
        assert(encoder.add_packet(p2) == null);
        var fec_pkt = encoder.add_packet(p3);
        assert(fec_pkt != null);
        assert(fec_pkt.mask == 0x000F); /* bits 0, 1, 2, 3 set */

        /* Deliver p0, p1, p3 to decoder (p2 is missing / dropped) */
        decoder.add_media_packet(p0);
        decoder.add_media_packet(p1);
        decoder.add_media_packet(p3);

        /* Execute FEC loss recovery */
        var recovered = decoder.try_recover(fec_pkt);
        assert(recovered != null);
        assert(recovered.ssrc == ssrc);
        assert(recovered.sequence_number == 502);
        assert(recovered.timestamp == 7000);
        assert(recovered.payload != null);
        assert(recovered.payload.length == 5);
        assert(recovered.payload[0] == 0x99);
        assert(recovered.payload[1] == 0xAA);
        assert(recovered.payload[2] == 0xBB);
        assert(recovered.payload[3] == 0xCC);
        assert(recovered.payload[4] == 0xDD);
    }

    public static void test_flexfec_no_recovery_on_multiple_losses() {
        uint32 ssrc = 0x11112222;
        var encoder = new FlexFecEncoder(ssrc, 4);
        var decoder = new FlexFecDecoder(ssrc);

        var p0 = new RtpPacket(); p0.sequence_number = 10; p0.timestamp = 100; p0.payload = new uint8[] { 1 };
        var p1 = new RtpPacket(); p1.sequence_number = 11; p1.timestamp = 200; p1.payload = new uint8[] { 2 };
        var p2 = new RtpPacket(); p2.sequence_number = 12; p2.timestamp = 300; p2.payload = new uint8[] { 3 };
        var p3 = new RtpPacket(); p3.sequence_number = 13; p3.timestamp = 400; p3.payload = new uint8[] { 4 };

        encoder.add_packet(p0);
        encoder.add_packet(p1);
        encoder.add_packet(p2);
        var fec = encoder.add_packet(p3);
        assert(fec != null);

        /* Only deliver p0 and p3 (2 packets missing: p1 and p2) */
        decoder.add_media_packet(p0);
        decoder.add_media_packet(p3);

        var recovered = decoder.try_recover(fec);
        assert(recovered == null); /* Cannot recover 2 simultaneous losses in 1D FEC */
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/flexfec/serialization", test_flexfec_packet_serialization);
        Test.add_func("/flexfec/single_loss_recovery", test_flexfec_recovery_single_loss);
        Test.add_func("/flexfec/multiple_losses_unrecoverable", test_flexfec_no_recovery_on_multiple_losses);

        return Test.run();
    }
}
