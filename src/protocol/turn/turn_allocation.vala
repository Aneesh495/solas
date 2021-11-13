/*
 * Solas: Real-Time WebRTC Media Engine
 * TURN Allocation Lifecycle and Channel Binding State (RFC 5766 Section 5)
 */

using Solas.Core;

namespace Solas.Protocol.Turn {

    public class PeerAddress : Object {
        public string ip { get; set; }
        public uint16 port { get; set; }

        public PeerAddress(string ip, uint16 port) {
            this.ip = ip;
            this.port = port;
        }

        public string to_key() {
            return "%s:%u".printf(this.ip, (uint) this.port);
        }
    }

    public class TurnAllocation : Object {
        public string allocation_id { get; private set; }
        public string client_address { get; set; }
        public string relayed_ip { get; set; }
        public uint16 relayed_port { get; set; }
        public uint32 lifetime_seconds { get; set; }
        public int64 expires_at_ms { get; private set; }

        /* Authorized peer IPs */
        public Gee.HashMap<string, int64?> permissions { get; private set; }

        /* Channel bindings: channel_number -> PeerAddress */
        public Gee.HashMap<uint16, PeerAddress> channel_bindings { get; private set; }

        public TurnAllocation(string id, string client_addr, string relay_ip, uint16 relay_port, uint32 lifetime = DEFAULT_LIFETIME_SECONDS) {
            this.allocation_id = id;
            this.client_address = client_addr;
            this.relayed_ip = relay_ip;
            this.relayed_port = relay_port;
            this.lifetime_seconds = (lifetime > MAX_LIFETIME_SECONDS) ? MAX_LIFETIME_SECONDS : lifetime;
            this.expires_at_ms = Clock.get_monotonic_time_ms() + (int64) this.lifetime_seconds * 1000;
            this.permissions = new Gee.HashMap<string, int64?>();
            this.channel_bindings = new Gee.HashMap<uint16, PeerAddress>();
        }

        public void refresh(uint32 requested_lifetime) {
            if (requested_lifetime == 0) {
                this.lifetime_seconds = 0;
                this.expires_at_ms = 0;
            } else {
                this.lifetime_seconds = (requested_lifetime > MAX_LIFETIME_SECONDS) ? MAX_LIFETIME_SECONDS : requested_lifetime;
                this.expires_at_ms = Clock.get_monotonic_time_ms() + (int64) this.lifetime_seconds * 1000;
            }
        }

        public void add_permission(string peer_ip) {
            /* Permissions expire after 5 minutes (300 seconds) */
            int64 perm_expires = Clock.get_monotonic_time_ms() + 300000;
            this.permissions.set(peer_ip, perm_expires);
        }

        public bool has_permission(string peer_ip) {
            if (!this.permissions.has_key(peer_ip)) return false;
            int64 exp = this.permissions.get(peer_ip);
            return Clock.get_monotonic_time_ms() < exp;
        }

        public bool bind_channel(uint16 channel, string peer_ip, uint16 peer_port) {
            if (channel < MIN_CHANNEL_NUMBER || channel > MAX_CHANNEL_NUMBER) {
                return false;
            }

            this.channel_bindings.set(channel, new PeerAddress(peer_ip, peer_port));
            /* Channel binding automatically grants permission for the peer IP */
            this.add_permission(peer_ip);
            return true;
        }

        public PeerAddress? get_peer_for_channel(uint16 channel) {
            if (this.channel_bindings.has_key(channel)) {
                return this.channel_bindings.get(channel);
            }
            return null;
        }

        public uint16 get_channel_for_peer(string peer_ip, uint16 peer_port) {
            foreach (var entry in this.channel_bindings.entries) {
                var p = entry.value;
                if (p.ip == peer_ip && p.port == peer_port) {
                    return entry.key;
                }
            }
            return 0;
        }

        public bool is_expired {
            get { return Clock.get_monotonic_time_ms() >= this.expires_at_ms; }
        }
    }
}
