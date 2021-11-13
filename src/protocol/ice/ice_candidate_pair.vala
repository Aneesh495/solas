/*
 * Solas: Real-Time WebRTC Media Engine
 * Candidate Pair Model and Priority Calculation (RFC 8445 Section 6.1.2.3)
 */

using Solas.Core;

namespace Solas.Protocol.Ice {

    public class CandidatePair : Object {
        public FullCandidate local { get; private set; }
        public FullCandidate remote { get; private set; }
        public uint64 priority { get; private set; }
        public CandidatePairState state { get; set; }
        public bool nominated { get; set; }
        public int64 rtt_us { get; set; }

        public CandidatePair(FullCandidate local, FullCandidate remote, bool is_controlling) {
            this.local = local;
            this.remote = remote;
            this.state = CandidatePairState.FROZEN;
            this.nominated = false;
            this.rtt_us = 0;
            this.priority = compute_pair_priority(local.priority, remote.priority, is_controlling);
        }

        /**
         * RFC 8445 Section 6.1.2.3:
         * Let G be the candidate priority provided by the controlling agent.
         * Let D be the candidate priority provided by the controlled agent.
         * pair priority = 2^32 * MIN(G, D) + 2 * MAX(G, D) + (G > D ? 1 : 0)
         */
        public static uint64 compute_pair_priority(uint32 local_prio, uint32 remote_prio, bool is_controlling) {
            uint64 g = is_controlling ? (uint64) local_prio : (uint64) remote_prio;
            uint64 d = is_controlling ? (uint64) remote_prio : (uint64) local_prio;

            uint64 min_gd = (g < d) ? g : d;
            uint64 max_gd = (g > d) ? g : d;
            uint64 flag = (g > d) ? 1ULL : 0ULL;

            return (min_gd << 32) + (2ULL * max_gd) + flag;
        }

        public string to_string() {
            return "%s:%u -> %s:%u (prio=%llu, state=%d, nominated=%s)".printf(
                this.local.ip_address, (uint) this.local.port,
                this.remote.ip_address, (uint) this.remote.port,
                this.priority, (int) this.state, this.nominated ? "true" : "false"
            );
        }
    }
}
