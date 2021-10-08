/*
 * Solas: Real-Time WebRTC Media Engine
 * Prometheus / OpenMetrics Telemetry Exporter
 */

using Solas.Core;
using Solas.Engine.Sfu;

namespace Solas.Network {

    public class MetricsExporter : Object {

        public static string export_prometheus_metrics(Gee.Collection<Room> rooms) {
            var sb = new StringBuilder();

            int total_peers = 0;
            uint64 total_packets_rx = 0;
            uint64 total_bytes_rx = 0;
            uint64 total_packets_tx = 0;
            uint64 total_bytes_tx = 0;
            uint64 total_nacks = 0;
            double total_bitrate_kbps = 0.0;

            foreach (var room in rooms) {
                total_peers += room.peer_count;
                foreach (var peer in room.peers.values) {
                    foreach (var track in peer.published_tracks.values) {
                        total_packets_rx += track.stats.packets_received;
                        total_bytes_rx += track.stats.bytes_received;
                        total_packets_tx += track.stats.packets_sent;
                        total_bytes_tx += track.stats.bytes_sent;
                        total_nacks += track.stats.nack_requests_received;
                        total_bitrate_kbps += track.stats.current_bitrate_kbps;
                    }
                }
            }

            int64 uptime_s = Clock.get_monotonic_time_ms() / 1000;

            sb.append("# HELP solas_uptime_seconds Total engine uptime in seconds\n");
            sb.append("# TYPE solas_uptime_seconds counter\n");
            sb.append_printf("solas_uptime_seconds %lld\n", uptime_s);

            sb.append("# HELP solas_active_rooms Number of active conference rooms\n");
            sb.append("# TYPE solas_active_rooms gauge\n");
            sb.append_printf("solas_active_rooms %d\n", rooms.size);

            sb.append("# HELP solas_active_peers Number of connected WebRTC peers\n");
            sb.append("# TYPE solas_active_peers gauge\n");
            sb.append_printf("solas_active_peers %d\n", total_peers);

            sb.append("# HELP solas_rtp_packets_received_total Cumulative RTP packets received\n");
            sb.append("# TYPE solas_rtp_packets_received_total counter\n");
            sb.append_printf("solas_rtp_packets_received_total %llu\n", total_packets_rx);

            sb.append("# HELP solas_rtp_bytes_received_total Cumulative RTP bytes received\n");
            sb.append("# TYPE solas_rtp_bytes_received_total counter\n");
            sb.append_printf("solas_rtp_bytes_received_total %llu\n", total_bytes_rx);

            sb.append("# HELP solas_rtp_packets_sent_total Cumulative RTP packets routed\n");
            sb.append("# TYPE solas_rtp_packets_sent_total counter\n");
            sb.append_printf("solas_rtp_packets_sent_total %llu\n", total_packets_tx);

            sb.append("# HELP solas_nack_requests_total Total RTCP NACK requests received\n");
            sb.append("# TYPE solas_nack_requests_total counter\n");
            sb.append_printf("solas_nack_requests_total %llu\n", total_nacks);

            sb.append("# HELP solas_current_bitrate_kbps Aggregated ingress throughput in kbps\n");
            sb.append("# TYPE solas_current_bitrate_kbps gauge\n");
            sb.append_printf("solas_current_bitrate_kbps %.2f\n", total_bitrate_kbps);

            return sb.str;
        }
    }
}
