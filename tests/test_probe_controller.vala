/*
 * Solas: Real-Time WebRTC Media Engine
 * Bandwidth Prober and Probe Cluster Controller Test Suite
 */

using Solas.Core;
using Solas.Engine.Congestion;

public class TestProbeController : Object {

    public static void test_cluster_creation() {
        var controller = new ProbeController();
        var c1 = controller.create_cluster(1500000);
        var c2 = controller.create_cluster(3000000);

        assert(c1.cluster_id == 1);
        assert(c1.target_bitrate_bps == 1500000);
        assert(c2.cluster_id == 2);
        assert(c2.target_bitrate_bps == 3000000);
    }

    public static void test_clean_probe_success() {
        var controller = new ProbeController();
        var cluster = controller.create_cluster(2000000);

        bool completed = false;
        ProbeResult? final_res = null;
        controller.probe_completed.connect((res) => {
            completed = true;
            final_res = res;
        });

        int64 base_send_us = 1000000;
        int64 base_recv_us = 1020000;

        /* Send 5 packets of 1200 bytes every 2ms */
        for (int i = 0; i < 5; i++) {
            uint16 seq = (uint16) (100 + i);
            int64 send_t = base_send_us + (i * 2000);
            int64 recv_t = base_recv_us + (i * 2100); /* Minimal delay jitter */

            controller.record_sent_packet(cluster.cluster_id, seq, 1200, send_t);
            controller.record_recv_packet(cluster.cluster_id, seq, recv_t);
        }

        var res = controller.evaluate_cluster(cluster.cluster_id);
        assert(res != null);
        assert(res.is_valid);
        assert(res.measured_bitrate_bps > 1000000);
        assert(completed);
        assert(final_res != null && final_res.cluster_id == cluster.cluster_id);
    }

    public static void test_congested_probe_failure() {
        var controller = new ProbeController();
        var cluster = controller.create_cluster(5000000);

        int64 base_send_us = 2000000;
        int64 base_recv_us = 2020000;

        /* Send 5 packets over 8ms, but receiver takes 40ms to receive them (bottleneck queue) */
        for (int i = 0; i < 5; i++) {
            uint16 seq = (uint16) (200 + i);
            int64 send_t = base_send_us + (i * 2000);      /* 8ms total delta */
            int64 recv_t = base_recv_us + (i * 10000);     /* 40ms total delta */

            controller.record_sent_packet(cluster.cluster_id, seq, 1200, send_t);
            controller.record_recv_packet(cluster.cluster_id, seq, recv_t);
        }

        var res = controller.evaluate_cluster(cluster.cluster_id);
        assert(res != null);
        assert(!res.is_valid); /* Queue bottleneck detected, probe marked invalid */
    }

    public static void test_insufficient_packets_pending() {
        var controller = new ProbeController();
        var cluster = controller.create_cluster(1000000);

        /* Only acknowledge 2 packets when minimum is 5 */
        controller.record_sent_packet(cluster.cluster_id, 1, 1200, 1000);
        controller.record_recv_packet(cluster.cluster_id, 1, 2000);
        controller.record_sent_packet(cluster.cluster_id, 2, 1200, 3000);
        controller.record_recv_packet(cluster.cluster_id, 2, 4000);

        var res = controller.evaluate_cluster(cluster.cluster_id);
        assert(res == null); /* Pending */
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/probe/cluster_creation", test_cluster_creation);
        Test.add_func("/probe/clean_success", test_clean_probe_success);
        Test.add_func("/probe/congested_failure", test_congested_probe_failure);
        Test.add_func("/probe/insufficient_packets", test_insufficient_packets_pending);

        return Test.run();
    }
}
