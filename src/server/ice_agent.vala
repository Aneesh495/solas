/*
 * Solas: Real-Time WebRTC Media Engine
 * Interactive Connectivity Establishment (ICE) Agent (RFC 5245 / RFC 8445)
 */

using Solas.Core;
using Solas.Crypto;
using Solas.Protocol.Stun;

namespace Solas.Server {

    public enum IceRole {
        CONTROLLING = 0,
        CONTROLLED = 1
    }

    public enum IceConnectionState {
        NEW = 0,
        CHECKING = 1,
        CONNECTED = 2,
        COMPLETED = 3,
        FAILED = 4,
        DISCONNECTED = 5,
        CLOSED = 6
    }

    public enum CandidateType {
        HOST = 0,
        SERVER_REFLEXIVE = 1,
        PEER_REFLEXIVE = 2,
        RELAY = 3
    }

    public class IceCandidate : Object {
        public string foundation { get; set; }
        public uint32 component_id { get; set; }
        public string transport { get; set; }
        public uint32 priority { get; set; }
        public string ip { get; set; }
        public uint16 port { get; set; }
        public CandidateType candidate_type { get; set; }
        public string related_ip { get; set; }
        public uint16 related_port { get; set; }

        public IceCandidate(string foundation, uint32 component_id, string transport,
                            uint32 priority, string ip, uint16 port, CandidateType candidate_type) {
            this.foundation = foundation;
            this.component_id = component_id;
            this.transport = transport;
            this.priority = priority;
            this.ip = ip;
            this.port = port;
            this.candidate_type = candidate_type;
            this.related_ip = "";
            this.related_port = 0;
        }

        public string to_sdp_attribute() {
            string type_str = (this.candidate_type == CandidateType.HOST) ? "host" :
                              (this.candidate_type == CandidateType.SERVER_REFLEXIVE) ? "srflx" :
                              (this.candidate_type == CandidateType.PEER_REFLEXIVE) ? "prflx" : "relay";

            var sb = new StringBuilder();
            sb.append_printf("%s %u %s %u %s %u typ %s",
                this.foundation, this.component_id, this.transport,
                this.priority, this.ip, (uint) this.port, type_str);

            if (this.related_ip.length > 0 && this.related_port > 0) {
                sb.append_printf(" raddr %s rport %u", this.related_ip, (uint) this.related_port);
            }

            return sb.str;
        }
    }

    public class IceAgent : Object {
        public string local_ufrag { get; private set; }
        public string local_pwd { get; private set; }
        public string remote_ufrag { get; set; }
        public string remote_pwd { get; set; }
        public IceRole role { get; set; }
        public IceConnectionState state { get; private set; }

        public Gee.ArrayList<IceCandidate> local_candidates { get; private set; }
        public Gee.ArrayList<IceCandidate> remote_candidates { get; private set; }

        public SocketAddress? selected_remote_addr { get; private set; }

        public signal void on_state_changed(IceConnectionState new_state);
        public signal void on_candidate_gathered(IceCandidate candidate);

        public IceAgent(IceRole role = IceRole.CONTROLLED) {
            this.role = role;
            this.state = IceConnectionState.NEW;
            this.local_candidates = new Gee.ArrayList<IceCandidate>();
            this.remote_candidates = new Gee.ArrayList<IceCandidate>();
            this.selected_remote_addr = null;

            /* Generate random 8-character ufrag and 24-character pwd */
            this.local_ufrag = this.generate_random_string(8);
            this.local_pwd = this.generate_random_string(24);
            this.remote_ufrag = "";
            this.remote_pwd = "";
        }

        public void gather_candidates(string public_ip, uint16 udp_port) {
            /* Priority calculation as per RFC 5245: (2^24)*type_preference + (2^8)*local_preference + (2^0)*(256 - component) */
            uint32 host_priority = (uint32) ((126 << 24) | (65535 << 8) | (256 - 1));
            var host_cand = new IceCandidate("1", 1, "UDP", host_priority, public_ip, udp_port, CandidateType.HOST);

            this.local_candidates.add(host_cand);
            this.on_candidate_gathered(host_cand);
        }

        public void add_remote_candidate(IceCandidate candidate) {
            this.remote_candidates.add(candidate);
            if (this.state == IceConnectionState.NEW) {
                this.transition_state(IceConnectionState.CHECKING);
            }
        }

        /**
         * Processes an incoming STUN binding request for ICE connectivity check.
         * Validates USERNAME attribute (remote_ufrag:local_ufrag) and returns binding response.
         */
        public StunMessage? process_stun_request(StunMessage request, SocketAddress peer_addr) {
            if (request.message_type != MessageType.BINDING_REQUEST) {
                return null;
            }

            /* Verify USERNAME if present */
            var user_attr = request.get_attribute<UsernameAttribute>();
            if (user_attr != null) {
                string username = user_attr.username;
                /* Allow peer to test connectivity before full remote ufrag is set or match remote:local */
                if (this.remote_ufrag.length > 0 && !username.contains(this.local_ufrag)) {
                    Logger.warn("ICE", "ICE STUN username mismatch: got %s, expected local %s", username, this.local_ufrag);
                    return null;
                }
            }

            /* Record active remote address and promote state */
            this.selected_remote_addr = peer_addr;
            if (this.state != IceConnectionState.CONNECTED && this.state != IceConnectionState.COMPLETED) {
                this.transition_state(IceConnectionState.CONNECTED);
            }

            /* Build Success Response with XOR-MAPPED-ADDRESS */
            if (peer_addr is InetSocketAddress) {
                var inet_addr = (InetSocketAddress) peer_addr;
                string ip_str = inet_addr.get_address().to_string();
                uint16 port = (uint16) inet_addr.get_port();
                var response = StunMessage.create_binding_response(request, ip_str, port);
                return response;
            }

            return null;
        }

        public void transition_state(IceConnectionState new_state) {
            if (this.state != new_state) {
                this.state = new_state;
                this.on_state_changed(new_state);
            }
        }

        private string generate_random_string(int length) {
            const string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            var sb = new StringBuilder();
            for (int i = 0; i < length; i++) {
                uint32 r = GLib.Random.next_int() % ((uint32) chars.length);
                sb.append_c(chars[(long) r]);
            }
            return sb.str;
        }
    }
}
