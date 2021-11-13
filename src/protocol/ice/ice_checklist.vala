/*
 * Solas: Real-Time WebRTC Media Engine
 * ICE Checklist and Connectivity Check Engine (RFC 8445 Section 6.1)
 */

using Solas.Core;

namespace Solas.Protocol.Ice {

    public class IceChecklist : Object {
        public Gee.ArrayList<CandidatePair> pairs { get; private set; }
        public Gee.ArrayList<CandidatePair> valid_list { get; private set; }
        public CandidatePair? nominated_pair { get; private set; }
        public CheckListState state { get; private set; }
        public bool is_controlling { get; set; }

        public signal void on_state_changed(CheckListState new_state);
        public signal void on_nominated(CandidatePair pair);

        public IceChecklist(bool is_controlling = false) {
            this.is_controlling = is_controlling;
            this.pairs = new Gee.ArrayList<CandidatePair>();
            this.valid_list = new Gee.ArrayList<CandidatePair>();
            this.nominated_pair = null;
            this.state = CheckListState.RUNNING;
        }

        /**
         * Pairs all local candidates with matching remote candidates of same component and protocol.
         */
        public void form_pairs(Gee.List<FullCandidate> locals, Gee.List<FullCandidate> remotes) {
            this.pairs.clear();

            foreach (var l in locals) {
                foreach (var r in remotes) {
                    if (l.component == r.component && l.protocol.down() == r.protocol.down()) {
                        var pair = new CandidatePair(l, r, this.is_controlling);
                        this.pairs.add(pair);
                    }
                }
            }

            /* Sort candidate pairs in descending order of pair priority */
            this.pairs.sort((a, b) => {
                if (a.priority > b.priority) return -1;
                if (a.priority < b.priority) return 1;
                return 0;
            });

            /* Unfreeze highest priority pair to WAITING */
            if (this.pairs.size > 0) {
                this.pairs.get(0).state = CandidatePairState.WAITING;
            }
        }

        /**
         * Records check success for a pair.
         */
        public void mark_pair_succeeded(CandidatePair pair, bool use_candidate = false, int64 rtt_us = 0) {
            pair.state = CandidatePairState.SUCCEEDED;
            pair.rtt_us = rtt_us;

            if (!this.valid_list.contains(pair)) {
                this.valid_list.add(pair);
            }

            if (use_candidate) {
                pair.nominated = true;
                this.nominated_pair = pair;
                this.state = CheckListState.COMPLETED;
                this.on_nominated(pair);
                this.on_state_changed(CheckListState.COMPLETED);
            }

            /* Unfreeze next waiting pair if any */
            foreach (var p in this.pairs) {
                if (p.state == CandidatePairState.FROZEN) {
                    p.state = CandidatePairState.WAITING;
                    break;
                }
            }
        }

        /**
         * Records check failure for a pair.
         */
        public void mark_pair_failed(CandidatePair pair) {
            pair.state = CandidatePairState.FAILED;

            /* Check if all pairs failed */
            bool any_alive = false;
            foreach (var p in this.pairs) {
                if (p.state != CandidatePairState.FAILED) {
                    any_alive = true;
                    break;
                }
            }

            if (!any_alive && this.valid_list.size == 0) {
                this.state = CheckListState.FAILED;
                this.on_state_changed(CheckListState.FAILED);
            }
        }

        public CandidatePair? get_next_waiting_pair() {
            foreach (var p in this.pairs) {
                if (p.state == CandidatePairState.WAITING) {
                    p.state = CandidatePairState.IN_PROGRESS;
                    return p;
                }
            }
            return null;
        }
    }
}
