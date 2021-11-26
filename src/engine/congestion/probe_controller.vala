/*
 * Solas: Real-Time WebRTC Media Engine
 * Bandwidth Prober and Probe Cluster Controller (RFC 8888 / GCC)
 */

using Solas.Core;

namespace Solas.Engine.Congestion {

    public class ProbeClusterConfig : Object {
        public int cluster_id { get; set; }
        public uint32 target_bitrate_bps { get; set; }
        public uint32 target_duration_ms { get; set; default = 15; }
        public int min_probe_packets { get; set; default = 5; }

        public ProbeClusterConfig(int id, uint32 bitrate_bps, uint32 duration_ms = 15, int min_pkts = 5) {
            this.cluster_id = id;
            this.target_bitrate_bps = bitrate_bps;
            this.target_duration_ms = duration_ms;
            this.min_probe_packets = min_pkts;
        }
    }

    public class ProbePacketRecord : Object {
        public uint16 seq_num { get; set; }
        public int cluster_id { get; set; }
        public size_t size_bytes { get; set; }
        public int64 send_time_us { get; set; }
        public int64 recv_time_us { get; set; default = -1; }

        public ProbePacketRecord(uint16 seq, int cluster, size_t size, int64 send_time) {
            this.seq_num = seq;
            this.cluster_id = cluster;
            this.size_bytes = size;
            this.send_time_us = send_time;
        }
    }

    public class ProbeResult : Object {
        public int cluster_id { get; set; }
        public uint32 target_bitrate_bps { get; set; }
        public uint32 measured_bitrate_bps { get; set; }
        public bool is_valid { get; set; }

        public ProbeResult(int id, uint32 target, uint32 measured, bool valid) {
            this.cluster_id = id;
            this.target_bitrate_bps = target;
            this.measured_bitrate_bps = measured;
            this.is_valid = valid;
        }
    }

    public class ProbeController : Object {
        private int next_cluster_id;
        private Gee.HashMap<int, ProbeClusterConfig> active_clusters;
        private Gee.HashMap<int, Gee.ArrayList<ProbePacketRecord>> cluster_packets;

        public signal void probe_completed(ProbeResult result);

        public ProbeController() {
            this.next_cluster_id = 1;
            this.active_clusters = new Gee.HashMap<int, ProbeClusterConfig>();
            this.cluster_packets = new Gee.HashMap<int, Gee.ArrayList<ProbePacketRecord>>();
        }

        /**
         * Schedules a new probe cluster for a target bitrate.
         */
        public ProbeClusterConfig create_cluster(uint32 target_bps) {
            int id = this.next_cluster_id++;
            var config = new ProbeClusterConfig(id, target_bps);
            this.active_clusters.set(id, config);
            this.cluster_packets.set(id, new Gee.ArrayList<ProbePacketRecord>());
            return config;
        }

        /**
         * Records packet transmission within a probe cluster.
         */
        public void record_sent_packet(int cluster_id, uint16 seq_num, size_t size_bytes, int64 send_time_us) {
            var list = this.cluster_packets.get(cluster_id);
            if (list != null) {
                list.add(new ProbePacketRecord(seq_num, cluster_id, size_bytes, send_time_us));
            }
        }

        /**
         * Records packet arrival time from TWCC feedback.
         */
        public void record_recv_packet(int cluster_id, uint16 seq_num, int64 recv_time_us) {
            var list = this.cluster_packets.get(cluster_id);
            if (list == null) return;

            foreach (var rec in list) {
                if (rec.seq_num == seq_num) {
                    rec.recv_time_us = recv_time_us;
                    break;
                }
            }
        }

        /**
         * Evaluates a completed probe cluster.
         * Returns ProbeResult if sufficient packets received, or null if pending.
         */
        public ProbeResult? evaluate_cluster(int cluster_id) {
            var config = this.active_clusters.get(cluster_id);
            var list = this.cluster_packets.get(cluster_id);
            if (config == null || list == null) return null;

            int64 min_send_us = int64.MAX;
            int64 max_send_us = int64.MIN;
            int64 min_recv_us = int64.MAX;
            int64 max_recv_us = int64.MIN;
            size_t total_payload_bytes = 0;
            int recv_count = 0;

            foreach (var rec in list) {
                if (rec.recv_time_us <= 0) continue;

                recv_count++;
                total_payload_bytes += rec.size_bytes;

                if (rec.send_time_us < min_send_us) min_send_us = rec.send_time_us;
                if (rec.send_time_us > max_send_us) max_send_us = rec.send_time_us;
                if (rec.recv_time_us < min_recv_us) min_recv_us = rec.recv_time_us;
                if (rec.recv_time_us > max_recv_us) max_recv_us = rec.recv_time_us;
            }

            if (recv_count < config.min_probe_packets) {
                return null;
            }

            int64 send_delta_us = max_send_us - min_send_us;
            int64 recv_delta_us = max_recv_us - min_recv_us;

            if (send_delta_us <= 0 || recv_delta_us <= 0) {
                return null;
            }

            /* Calculate bitrates in bps: (bytes * 8 * 1,000,000) / delta_us */
            double send_bps = ((double) total_payload_bytes * 8.0 * 1000000.0) / (double) send_delta_us;
            double recv_bps = ((double) total_payload_bytes * 8.0 * 1000000.0) / (double) recv_delta_us;

            /* If receive bitrate is at least 80% of send bitrate, probe succeeded */
            double ratio = recv_bps / send_bps;
            bool valid = (ratio >= 0.80);

            uint32 measured = (uint32) recv_bps;
            var res = new ProbeResult(cluster_id, config.target_bitrate_bps, measured, valid);
            this.probe_completed(res);

            /* Clean up cluster */
            this.active_clusters.unset(cluster_id);
            this.cluster_packets.unset(cluster_id);

            return res;
        }
    }
}
