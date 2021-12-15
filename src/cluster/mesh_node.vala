/*
 * Solas: Real-Time WebRTC Media Engine
 * SFU Cascade Mesh Node and Inter-Data-Center Link Topology
 */

using Solas.Core;

namespace Solas.Cluster {

    public class CascadeNode : Object {
        public string node_id { get; construct; }
        public string region { get; construct; }
        public string host { get; construct; }
        public uint16 port { get; construct; }
        public bool is_alive { get; set; default = true; }
        public int64 rtt_ms { get; set; default = 10; }
        public int64 last_heartbeat_time_ms { get; set; default = 0; }

        public CascadeNode(string id, string region, string host = "127.0.0.1", uint16 port = 7000) {
            GLib.Object(node_id: id, region: region, host: host, port: port);
            this.last_heartbeat_time_ms = Clock.get_monotonic_time_ms();
        }

        public void record_heartbeat(int64 measured_rtt_ms) {
            this.is_alive = true;
            this.rtt_ms = measured_rtt_ms;
            this.last_heartbeat_time_ms = Clock.get_monotonic_time_ms();
        }

        public bool check_liveness(int64 timeout_ms = 5000) {
            int64 now = Clock.get_monotonic_time_ms();
            if (now - this.last_heartbeat_time_ms > timeout_ms) {
                this.is_alive = false;
            }
            return this.is_alive;
        }
    }
}
