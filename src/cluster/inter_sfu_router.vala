/*
 * Solas: Real-Time WebRTC Media Engine
 * Inter-SFU Cascade Mesh Router and Selective Broadcast Tree
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Cluster {

    public class CascadeRouter : Object {
        public string local_node_id { get; construct; }
        private Gee.HashMap<string, CascadeNode> nodes;
        private Gee.HashMap<string, Gee.HashSet<string>> room_subscriptions;

        public signal void packet_forwarded(string room_id, string target_node_id, uint16 seq_num);

        public CascadeRouter(string local_id) {
            GLib.Object(local_node_id: local_id);
            this.nodes = new Gee.HashMap<string, CascadeNode>();
            this.room_subscriptions = new Gee.HashMap<string, Gee.HashSet<string>>();
        }

        public void register_node(CascadeNode node) {
            this.nodes.set(node.node_id, node);
        }

        public void unregister_node(string node_id) {
            this.nodes.unset(node_id);
            foreach (var set in this.room_subscriptions.values) {
                set.remove(node_id);
            }
        }

        public void subscribe_node(string room_id, string node_id) {
            var set = this.room_subscriptions.get(room_id);
            if (set == null) {
                set = new Gee.HashSet<string>();
                this.room_subscriptions.set(room_id, set);
            }
            set.add(node_id);
        }

        public void unsubscribe_node(string room_id, string node_id) {
            var set = this.room_subscriptions.get(room_id);
            if (set != null) {
                set.remove(node_id);
                if (set.is_empty) {
                    this.room_subscriptions.unset(room_id);
                }
            }
        }

        public bool should_forward(string room_id, string node_id) {
            var set = this.room_subscriptions.get(room_id);
            return (set != null && set.contains(node_id));
        }

        public Gee.ArrayList<CascadeNode> get_targets(string room_id) {
            var result = new Gee.ArrayList<CascadeNode>();
            var set = this.room_subscriptions.get(room_id);
            if (set == null) return result;

            foreach (var target_id in set) {
                var node = this.nodes.get(target_id);
                if (node != null && node.is_alive) {
                    result.add(node);
                }
            }

            return result;
        }

        /**
         * Selectively routes an RTP packet across the cascade mesh.
         * Returns number of remote nodes forwarded to.
         */
        public int route_packet(string room_id, RtpPacket pkt) {
            var targets = this.get_targets(room_id);
            foreach (var node in targets) {
                this.packet_forwarded(room_id, node.node_id, pkt.sequence_number);
            }
            return targets.size;
        }
    }
}
