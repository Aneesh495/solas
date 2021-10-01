/*
 * Solas: Real-Time WebRTC Media Engine
 * Active Speaker Detector and Audio Energy Envelope Follower
 */

using Solas.Core;

namespace Solas.Engine.Sfu {

    public class SpeakerScore : Object {
        public string peer_id { get; set; }
        public double score { get; set; }
        public uint8 level_dbov { get; set; }
        public bool is_speaking { get; set; }

        public SpeakerScore(string id, double score, uint8 level, bool speaking) {
            this.peer_id = id;
            this.score = score;
            this.level_dbov = level;
            this.is_speaking = speaking;
        }
    }

    public class ActiveSpeakerDetector : Object {
        private Gee.HashMap<string, double?> peer_envelopes;
        private Gee.HashMap<string, uint8?> peer_levels;
        private string current_dominant_speaker;
        private int64 last_switch_time_us;

        public const double ATTACK_COEFF = 0.5;   /* Fast attack */
        public const double DECAY_COEFF = 0.05;   /* Slow decay */
        public const int64 MIN_HOLD_TIME_US = 500000; /* Hold dominant speaker at least 500ms */
        public const uint8 SPEAKING_THRESHOLD_DBOV = 50; /* 0 to 127: 0 is loudest, 127 is silent */

        public ActiveSpeakerDetector() {
            this.peer_envelopes = new Gee.HashMap<string, double?>();
            this.peer_levels = new Gee.HashMap<string, uint8?>();
            this.current_dominant_speaker = "";
            this.last_switch_time_us = 0;
        }

        public void update_audio_level(string peer_id, uint8 level_dbov, bool vad_active, int64 now_us = 0) {
            if (now_us == 0) now_us = Clock.get_monotonic_time_us();

            /* Invert dBov: 0 dBov (loudest) -> 127 units; 127 dBov (silent) -> 0 units */
            double linear_energy = vad_active ? (double) (127 - level_dbov) : 0.0;
            double current_env = this.peer_envelopes.has_key(peer_id) ? this.peer_envelopes.get(peer_id) : 0.0;

            if (linear_energy > current_env) {
                /* Attack */
                current_env += ATTACK_COEFF * (linear_energy - current_env);
            } else {
                /* Decay */
                current_env += DECAY_COEFF * (linear_energy - current_env);
            }

            this.peer_envelopes.set(peer_id, current_env);
            this.peer_levels.set(peer_id, level_dbov);

            evaluate_dominant_speaker(now_us);
        }

        public void remove_peer(string peer_id) {
            this.peer_envelopes.unset(peer_id);
            this.peer_levels.unset(peer_id);
            if (this.current_dominant_speaker == peer_id) {
                this.current_dominant_speaker = "";
            }
        }

        private void evaluate_dominant_speaker(int64 now_us) {
            string best_peer = "";
            double max_score = 0.0;

            foreach (var entry in this.peer_envelopes.entries) {
                if (entry.value > max_score) {
                    max_score = entry.value;
                    best_peer = entry.key;
                }
            }

            if (best_peer != "" && best_peer != this.current_dominant_speaker) {
                if ((now_us - this.last_switch_time_us) >= MIN_HOLD_TIME_US || this.current_dominant_speaker == "") {
                    this.current_dominant_speaker = best_peer;
                    this.last_switch_time_us = now_us;
                }
            }
        }

        public string dominant_speaker {
            get { return this.current_dominant_speaker; }
        }

        public Gee.ArrayList<SpeakerScore> get_ranked_speakers() {
            var list = new Gee.ArrayList<SpeakerScore>();
            foreach (var entry in this.peer_envelopes.entries) {
                uint8 lvl = this.peer_levels.has_key(entry.key) ? this.peer_levels.get(entry.key) : 127;
                bool speaking = (lvl <= SPEAKING_THRESHOLD_DBOV);
                list.add(new SpeakerScore(entry.key, entry.value, lvl, speaking));
            }

            /* Sort descending by score */
            list.sort((a, b) => {
                if (b.score > a.score) return 1;
                if (b.score < a.score) return -1;
                return 0;
            });

            return list;
        }
    }
}
