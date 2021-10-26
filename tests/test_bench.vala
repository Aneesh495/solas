/*
 * Solas: Real-Time WebRTC Media Engine
 * Benchmarking and Synthetic Stream Generator Verification Suite
 */

using Solas.Core;
using Solas.Bench;
using Solas.Protocol.Rtp;

public class TestBench : Object {

    public static void test_synthetic_publisher() {
        var pub = new SyntheticPublisher("test-pub", 11111, 22222, 2000);

        /* 1. Test audio packet generation */
        var a1 = pub.generate_audio_packet();
        assert(a1.payload_type == 111);
        assert(a1.ssrc == 11111);
        assert(a1.payload.length == 80);

        var a2 = pub.generate_audio_packet();
        assert(a2.sequence_number == (uint16) (a1.sequence_number + 1));
        assert(a2.timestamp == (a1.timestamp + 960));

        /* 2. Test video frame generation */
        var v_packets = pub.generate_video_frame(false);
        assert(v_packets.size > 0);
        /* Last packet in frame must have marker bit set */
        assert(v_packets.get(v_packets.size - 1).marker == true);
        /* If multiple packets, intermediate ones must not have marker set */
        if (v_packets.size > 1) {
            assert(v_packets.get(0).marker == false);
        }

        /* Keyframes should generate more or equal packets */
        var k_packets = pub.generate_video_frame(true);
        assert(k_packets.size >= v_packets.size);
        assert(k_packets.get(k_packets.size - 1).marker == true);
    }

    public static void test_network_impairment() {
        /* Zero impairment passes all packets unmodified */
        var clean = new NetworkImpairment(0.0, 0.0, 0.0);
        var pkt1 = new RtpPacket();
        pkt1.sequence_number = 100;
        var res1 = clean.process_packet(pkt1);
        assert(res1.size == 1);
        assert(res1.get(0).sequence_number == 100);
        assert(clean.total_processed == 1);
        assert(clean.total_dropped == 0);

        /* 100% loss drops all packets */
        var lossy = new NetworkImpairment(100.0, 0.0, 0.0);
        for (int i = 0; i < 20; i++) {
            var p = new RtpPacket();
            p.sequence_number = (uint16) i;
            var res = lossy.process_packet(p);
            assert(res.size == 0);
        }
        assert(lossy.total_processed == 20);
        assert(lossy.total_dropped == 20);
        assert(lossy.actual_loss_rate == 100.0);
    }

    public static void test_bench_runner_execution() {
        var runner = new BenchRunner(2, 4, 15);
        var res = runner.execute();

        assert(res.num_publishers == 2);
        assert(res.num_subscribers == 4);
        assert(res.total_packets_routed > 0);
        assert(res.total_bytes_routed > 0);
        assert(res.duration_seconds > 0.0);
        assert(res.packets_per_second > 0.0);
        assert(res.latency_p50_us >= 0.0);
        assert(res.latency_max_us >= res.latency_p50_us);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/bench/synthetic_publisher", test_synthetic_publisher);
        Test.add_func("/bench/network_impairment", test_network_impairment);
        Test.add_func("/bench/runner_execution", test_bench_runner_execution);

        return Test.run();
    }
}
