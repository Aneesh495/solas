/*
 * Solas: Real-Time WebRTC Media Engine
 * Multi-Client Stress Benchmark and Throughput Harness
 */

using Solas.Core;
using Solas.Engine.Sfu;
using Solas.Protocol.Rtp;
using Solas.Protocol.Sdp;

namespace Solas.Bench {

    public class BenchmarkResult : Object {
        public int num_publishers { get; set; }
        public int num_subscribers { get; set; }
        public uint64 total_packets_routed { get; set; }
        public uint64 total_bytes_routed { get; set; }
        public double duration_seconds { get; set; }
        public double packets_per_second { get; set; }
        public double throughput_mbps { get; set; }
        public double latency_p50_us { get; set; }
        public double latency_p95_us { get; set; }
        public double latency_p99_us { get; set; }
        public double latency_max_us { get; set; }

        public void print_report() {
            print("=================================================================\n");
            print("                 SOLAS SFU BENCHMARK REPORT                      \n");
            print("=================================================================\n");
            print("  Publishers / Subscribers:     %d / %d\n", this.num_publishers, this.num_subscribers);
            print("  Total Packets Routed:         %llu pkts\n", this.total_packets_routed);
            print("  Total Media Transferred:      %.2f MB\n", (double) this.total_bytes_routed / (1024.0 * 1024.0));
            print("  Benchmark Duration:           %.3f seconds\n", this.duration_seconds);
            print("-----------------------------------------------------------------\n");
            print("  Throughput (Packets):         %.2f pkts/sec\n", this.packets_per_second);
            print("  Throughput (Bandwidth):       %.2f Mbps\n", this.throughput_mbps);
            print("-----------------------------------------------------------------\n");
            print("  Forwarding Latency p50:       %.2f microseconds (%.4f ms)\n", this.latency_p50_us, this.latency_p50_us / 1000.0);
            print("  Forwarding Latency p95:       %.2f microseconds (%.4f ms)\n", this.latency_p95_us, this.latency_p95_us / 1000.0);
            print("  Forwarding Latency p99:       %.2f microseconds (%.4f ms)\n", this.latency_p99_us, this.latency_p99_us / 1000.0);
            print("  Forwarding Latency Max:       %.2f microseconds (%.4f ms)\n", this.latency_max_us, this.latency_max_us / 1000.0);
            print("=================================================================\n");
        }
    }

    public class BenchRunner : Object {
        public int num_publishers { get; set; }
        public int num_subscribers { get; set; }
        public int total_frames { get; set; }
        public NetworkImpairment impairment { get; private set; }

        public BenchRunner(int publishers = 4, int subscribers = 16, int frames = 100) {
            this.num_publishers = publishers;
            this.num_subscribers = subscribers;
            this.total_frames = frames;
            this.impairment = new NetworkImpairment(0.0, 0.0, 0.0);
        }

        public BenchmarkResult execute() {
            var room = new Room("bench-room");
            var publishers = new Gee.ArrayList<SyntheticPublisher>();
            var latencies = new Gee.ArrayList<double?>();

            /* Register publisher peers and published tracks */
            for (int p = 0; p < this.num_publishers; p++) {
                string peer_id = "pub-%d".printf(p);
                var peer = new Peer(peer_id, "bench-room");
                room.add_peer(peer);

                uint32 v_ssrc = (uint32) (100000 + p);
                var vp8_codec = new CodecCapability(96, "VP8", 90000);
                var v_track = new MediaTrack("v-track-%d".printf(p), MediaType.VIDEO, v_ssrc, vp8_codec);
                room.publish_track(peer, v_track);

                var synth = new SyntheticPublisher(peer_id, (uint32) (200000 + p), v_ssrc, 2500);
                publishers.add(synth);
            }

            /* Register subscriber peers (they automatically subscribe to published tracks) */
            for (int s = 0; s < this.num_subscribers; s++) {
                string sub_id = "sub-%d".printf(s);
                var sub_peer = new Peer(sub_id, "bench-room");
                room.add_peer(sub_peer);
            }

            uint64 total_packets = 0;
            uint64 total_bytes = 0;

            int64 bench_start_us = Clock.get_monotonic_time_us();

            /* Run synthetic frame loop */
            for (int f = 0; f < this.total_frames; f++) {
                bool is_keyframe = (f % 60 == 0);

                foreach (var pub in publishers) {
                    var packets = pub.generate_video_frame(is_keyframe);

                    foreach (var pkt in packets) {
                        var transit_packets = this.impairment.process_packet(pkt);

                        foreach (var in_pkt in transit_packets) {
                            int64 t_before = Clock.get_monotonic_time_us();

                            /* Route through SFU room coordinator */
                            room.route_rtp_packet(pub.peer_id, in_pkt);

                            int64 t_after = Clock.get_monotonic_time_us();
                            double lat_us = (double) (t_after - t_before);
                            latencies.add(lat_us);

                            /* Multiplied by subscriber count for total distribution */
                            total_packets += (uint64) this.num_subscribers;
                            total_bytes += (uint64) ((in_pkt.payload.length + 12) * this.num_subscribers);
                        }
                    }
                }
            }

            int64 bench_end_us = Clock.get_monotonic_time_us();
            double duration_s = (double) (bench_end_us - bench_start_us) / 1000000.0;
            if (duration_s <= 0.0) duration_s = 0.0001;

            /* Calculate latency percentiles */
            latencies.sort((a, b) => {
                if (a < b) return -1;
                if (a > b) return 1;
                return 0;
            });

            size_t n = latencies.size;
            double p50 = (n > 0) ? latencies.get((int) (n * 0.50)) : 0.0;
            double p95 = (n > 0) ? latencies.get((int) (n * 0.95)) : 0.0;
            double p99 = (n > 0) ? latencies.get((int) (n * 0.99)) : 0.0;
            double max_lat = (n > 0) ? latencies.get((int) (n - 1)) : 0.0;

            var result = new BenchmarkResult();
            result.num_publishers = this.num_publishers;
            result.num_subscribers = this.num_subscribers;
            result.total_packets_routed = total_packets;
            result.total_bytes_routed = total_bytes;
            result.duration_seconds = duration_s;
            result.packets_per_second = (double) total_packets / duration_s;
            result.throughput_mbps = ((double) total_bytes * 8.0) / (duration_s * 1000000.0);
            result.latency_p50_us = p50;
            result.latency_p95_us = p95;
            result.latency_p99_us = p99;
            result.latency_max_us = max_lat;

            return result;
        }
    }
}
