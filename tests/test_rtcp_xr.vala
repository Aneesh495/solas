/*
 * Solas: Real-Time WebRTC Media Engine
 * RTCP Extended Reports (RFC 3611 XR) Test Suite
 */

using Solas.Core;
using Solas.Protocol.Rtcp;

public class TestRtcpXr : Object {

    public static void test_voip_metrics_serialization() {
        var voip = new XrVoipMetricsBlock(0x11223344);
        voip.loss_rate = 25;       /* ~10% loss */
        voip.discard_rate = 5;      /* ~2% discard */
        voip.burst_density = 40;
        voip.gap_density = 10;
        voip.burst_duration = 120;
        voip.gap_duration = 800;
        voip.round_trip_delay = 45;
        voip.end_system_delay = 20;
        voip.signal_level = -18;
        voip.noise_level = -65;
        voip.rerl = 50;
        voip.r_factor = 92;
        voip.mos_lq = 44;          /* 4.4 MOS */
        voip.mos_cq = 42;          /* 4.2 MOS */

        var pkt = new RtcpXrPacket((uint32) 0xAABBCCDD);
        pkt.add_block(voip);

        uint8[] wire = pkt.to_array();
        assert(wire.length >= 8 + 32);

        try {
            var parsed = RtcpXrPacket.parse(wire);
            assert(parsed.ssrc == 0xAABBCCDD);
            assert(parsed.blocks.size == 1);

            var b = parsed.blocks[0] as XrVoipMetricsBlock;
            assert(b != null);
            assert(b.ssrc == 0x11223344);
            assert(b.loss_rate == 25);
            assert(b.discard_rate == 5);
            assert(b.round_trip_delay == 45);
            assert(b.signal_level == -18);
            assert(b.noise_level == -65);
            assert(b.mos_lq == 44);
            assert(b.mos_cq == 42);
        } catch (RtcpError e) {
            assert_not_reached();
        }
    }

    public static void test_loss_rle_serialization() {
        var rle = new XrLossRleBlock(0x55667788, 1000, 1050);
        rle.add_chunk(0x0005); /* Run of 5 packets received */
        rle.add_chunk(0x8001); /* Run of 1 packet lost */
        rle.add_chunk(0x002A); /* Run of 42 packets received */

        var pkt = new RtcpXrPacket((uint32) 0x99887766);
        pkt.add_block(rle);

        uint8[] wire = pkt.to_array();

        try {
            var parsed = RtcpXrPacket.parse(wire);
            assert(parsed.ssrc == (uint32) 0x99887766);
            assert(parsed.blocks.size == 1);

            var b = parsed.blocks[0] as XrLossRleBlock;
            assert(b != null);
            assert(b.ssrc == 0x55667788);
            assert(b.begin_seq == 1000);
            assert(b.end_seq == 1050);
            assert(b.chunks.size >= 3);
            assert(b.chunks[0] == 0x0005);
            assert(b.chunks[1] == 0x8001);
            assert(b.chunks[2] == 0x002A);
        } catch (RtcpError e) {
            assert_not_reached();
        }
    }

    public static void test_composite_xr_packet() {
        var pkt = new RtcpXrPacket(0x12345678);

        var voip = new XrVoipMetricsBlock((uint32) 0xDEADBEEF);
        voip.mos_lq = 45;
        pkt.add_block(voip);

        var rle = new XrLossRleBlock((uint32) 0xDEADBEEF, 500, 520);
        rle.add_chunk(0x0014);
        pkt.add_block(rle);

        uint8[] wire = pkt.to_array();

        try {
            var parsed = RtcpXrPacket.parse(wire);
            assert(parsed.blocks.size == 2);
            assert(parsed.blocks[0].block_type == XrBlockType.VOIP_METRICS);
            assert(parsed.blocks[1].block_type == XrBlockType.LOSS_RLE);
        } catch (RtcpError e) {
            assert_not_reached();
        }
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/rtcp/xr_voip_metrics", test_voip_metrics_serialization);
        Test.add_func("/rtcp/xr_loss_rle", test_loss_rle_serialization);
        Test.add_func("/rtcp/xr_composite", test_composite_xr_packet);

        return Test.run();
    }
}
