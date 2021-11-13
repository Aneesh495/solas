/*
 * Solas: Real-Time WebRTC Media Engine
 * Full ICE Types and Pair State Machine (RFC 8445)
 */

namespace Solas.Protocol.Ice {

    public enum CheckListState {
        RUNNING = 0,
        COMPLETED = 1,
        FAILED = 2
    }

    public enum CandidatePairState {
        FROZEN = 0,
        WAITING = 1,
        IN_PROGRESS = 2,
        SUCCEEDED = 3,
        FAILED = 4
    }

    public enum IceComponent {
        NONE = 0,
        RTP = 1,
        RTCP = 2
    }

    public enum IceCandidateType {
        HOST = 0,
        SERVER_REFLEXIVE = 1,
        PEER_REFLEXIVE = 2,
        RELAYED = 3
    }

    public class FullCandidate : Object {
        public string foundation { get; set; }
        public IceComponent component { get; set; }
        public string protocol { get; set; }
        public uint32 priority { get; set; }
        public string ip_address { get; set; }
        public uint16 port { get; set; }
        public IceCandidateType candidate_type { get; set; }
        public string related_address { get; set; }
        public uint16 related_port { get; set; }

        public FullCandidate(string foundation, IceComponent component, string protocol,
                             uint32 priority, string ip, uint16 port, IceCandidateType type) {
            this.foundation = foundation;
            this.component = component;
            this.protocol = protocol;
            this.priority = priority;
            this.ip_address = ip;
            this.port = port;
            this.candidate_type = type;
            this.related_address = "";
            this.related_port = 0;
        }

        public static uint32 calculate_priority(IceCandidateType type, uint16 local_pref, IceComponent component) {
            uint32 type_pref = (type == IceCandidateType.HOST) ? 126 :
                               (type == IceCandidateType.PEER_REFLEXIVE) ? 110 :
                               (type == IceCandidateType.SERVER_REFLEXIVE) ? 100 : 0;

            /* RFC 8445 Section 5.1.2.1 formula:
             * priority = (2^24)*(type preference) + (2^8)*(local preference) + (2^0)*(256 - component) */
            return (type_pref << 24) | (((uint32) local_pref) << 8) | (256 - (uint32) component);
        }
    }
}
