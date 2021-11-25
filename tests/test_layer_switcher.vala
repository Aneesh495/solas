/*
 * Solas: Real-Time WebRTC Media Engine
 * Simulcast Layer Switcher and Keyframe Alignment Test Suite
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Engine.Sfu;

public class TestLayerSwitcher : Object {

    public static void test_steady_state_forwarding() {
        var switcher = new LayerSwitcher("sub-1", SpatialLayer.HIGH);
        assert(switcher.current_layer == SpatialLayer.HIGH);
        assert(!switcher.is_switching);

        var pkt1 = new RtpPacket();
        pkt1.sequence_number = 400;
        pkt1.timestamp = 90000;
        pkt1.payload = new uint8[100];

        var out1 = switcher.process_packet(SpatialLayer.HIGH, pkt1, false);
        assert(out1 != null);
        assert(out1.sequence_number == 1000);
        assert(out1.timestamp == 10000);

        var pkt2 = new RtpPacket();
        pkt2.sequence_number = 401;
        pkt2.timestamp = 93000;
        pkt2.payload = new uint8[100];

        var out2 = switcher.process_packet(SpatialLayer.HIGH, pkt2, false);
        assert(out2 != null);
        assert(out2.sequence_number == 1001);
        assert(out2.timestamp == 13000); /* 10000 + 3000 delta */
    }

    public static void test_bandwidth_triggered_switch() {
        var switcher = new LayerSwitcher("sub-2", SpatialLayer.HIGH);

        bool kf_requested = false;
        SpatialLayer requested_layer = SpatialLayer.HIGH;
        switcher.keyframe_requested.connect((layer) => {
            kf_requested = true;
            requested_layer = layer;
        });

        /* Bandwidth drops to 1200 kbps (between med 800 and high 2500) -> selects MEDIUM */
        switcher.update_bandwidth(1200);
        assert(switcher.is_switching);
        assert(switcher.target_layer == SpatialLayer.MEDIUM);
        assert(kf_requested);
        assert(requested_layer == SpatialLayer.MEDIUM);
    }

    public static void test_keyframe_gated_seamless_switch() {
        var switcher = new LayerSwitcher("sub-3", SpatialLayer.HIGH);

        /* Send 2 packets on HIGH */
        var h1 = new RtpPacket();
        h1.sequence_number = 10;
        h1.timestamp = 1000;
        var out_h1 = switcher.process_packet(SpatialLayer.HIGH, h1, false);
        assert(out_h1.sequence_number == 1000);

        var h2 = new RtpPacket();
        h2.sequence_number = 11;
        h2.timestamp = 4000;
        var out_h2 = switcher.process_packet(SpatialLayer.HIGH, h2, false);
        assert(out_h2.sequence_number == 1001);

        /* Request switch to LOW */
        switcher.request_layer_switch(SpatialLayer.LOW);
        assert(switcher.is_switching);

        /* Target layer non-keyframe delta packet arrives -> MUST BE DROPPED */
        var l_delta = new RtpPacket();
        l_delta.sequence_number = 80;
        l_delta.timestamp = 5000;
        var out_drop = switcher.process_packet(SpatialLayer.LOW, l_delta, false);
        assert(out_drop == null);
        assert(switcher.get_dropped_packets() == 1);

        /* Current layer packet continues forwarding in interim */
        var h3 = new RtpPacket();
        h3.sequence_number = 12;
        h3.timestamp = 7000;
        var out_h3 = switcher.process_packet(SpatialLayer.HIGH, h3, false);
        assert(out_h3 != null);
        assert(out_h3.sequence_number == 1002);

        /* Target layer KEYFRAME arrives -> EXECUTES SWITCH */
        var l_key = new RtpPacket();
        l_key.sequence_number = 81;
        l_key.timestamp = 8000;
        var out_switch = switcher.process_packet(SpatialLayer.LOW, l_key, true);
        assert(out_switch != null);
        /* Sequence number continues monotonically with NO gap! */
        assert(out_switch.sequence_number == 1003);
        assert(!switcher.is_switching);
        assert(switcher.current_layer == SpatialLayer.LOW);
        assert(switcher.get_switch_count() == 1);

        /* Now older HIGH layer packets are dropped */
        var h4 = new RtpPacket();
        h4.sequence_number = 13;
        h4.timestamp = 10000;
        var out_old_h = switcher.process_packet(SpatialLayer.HIGH, h4, false);
        assert(out_old_h == null);

        /* Next LOW layer packet forwards seamlessly */
        var l2 = new RtpPacket();
        l2.sequence_number = 82;
        l2.timestamp = 11000;
        var out_l2 = switcher.process_packet(SpatialLayer.LOW, l2, false);
        assert(out_l2 != null);
        assert(out_l2.sequence_number == 1004);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/layer_switcher/steady_state", test_steady_state_forwarding);
        Test.add_func("/layer_switcher/bwe_switch", test_bandwidth_triggered_switch);
        Test.add_func("/layer_switcher/keyframe_gated_seamless", test_keyframe_gated_seamless_switch);

        return Test.run();
    }
}
