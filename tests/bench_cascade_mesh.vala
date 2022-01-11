/*
 * Solas: Real-Time WebRTC Media Engine
 * High-Throughput Inter-SFU Cascade Mesh Routing Stress Benchmark
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Cluster;

class Solas.BenchCascadeMesh {

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/bench/cluster/cascade_mesh_throughput", () => {
            var router = new CascadeRouter("sfu-origin-core");

            // Setup 16 edge nodes across 4 geo regions
            string[] regions = new string[] { "us-east-1", "us-west-2", "eu-central-1", "ap-southeast-1" };
            for (int r = 0; r < regions.length; r++) {
                for (int n = 0; n < 4; n++) {
                    string node_id = "edge-%s-%d".printf(regions[r], n);
                    var node = new CascadeNode(node_id, regions[r], "10.%d.%d.1".printf(r + 1, n + 1), 7000);
                    router.register_node(node);
                }
            }

            // Create 20 rooms with different node distribution
            for (int room_idx = 0; room_idx < 20; room_idx++) {
                string room_id = "room-stream-%d".printf(room_idx);
                // Subscribe 4 specific nodes to this room
                for (int r = 0; r < 4; r++) {
                    string target = "edge-%s-%d".printf(regions[r], room_idx % 4);
                    router.subscribe_node(room_id, target);
                }
            }

            // Prepare synthetic RTP media packet
            var packet = new RtpPacket();
            packet.ssrc = (uint32) 0xA1B2C3D4;
            packet.sequence_number = 1;
            packet.timestamp = 90000;
            packet.payload = new uint8[] { 0x90, 0x80, 0x01, 0x02 };

            int64 start_time = Clock.get_monotonic_time_us();
            int total_packets = 10000;
            uint64 total_forwards = 0;

            for (int i = 0; i < total_packets; i++) {
                packet.sequence_number = (uint16) (i & 0xFFFF);
                string room_id = "room-stream-%d".printf(i % 20);
                int forwarded = router.route_packet(room_id, packet);
                total_forwards += (uint64) forwarded;
            }

            int64 elapsed_us = Clock.get_monotonic_time_us() - start_time;
            if (elapsed_us <= 0) elapsed_us = 1;

            double ops_per_sec = ((double) total_forwards / (double) elapsed_us) * 1000000.0;
            printerr("Cascade Mesh Stress Test: %llu forwards in %lld us (%.2f forwards/sec)\n",
                     total_forwards, elapsed_us, ops_per_sec);

            // Assert 4 forwards per packet (4 subscribed nodes per room)
            assert(total_forwards == (uint64) (total_packets * 4));
            assert(ops_per_sec > 100000.0);
        });

        return Test.run();
    }
}
