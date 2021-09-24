/*
 * Solas: Real-Time WebRTC Media Engine
 * RTT-Aware NACK Scheduler and Loss Recovery Queue
 */

using Solas.Core;
using Solas.Protocol.Rtcp;

namespace Solas.Engine.Jitter {

    public class NackItem : Object {
        public uint16 sequence_number { get; set; }
        public int retries { get; set; }
        public int64 last_sent_us { get; set; }
        public int64 first_scheduled_us { get; set; }

        public NackItem(uint16 seq, int64 now_us) {
            this.sequence_number = seq;
            this.retries = 0;
            this.last_sent_us = 0;
            this.first_scheduled_us = now_us;
        }
    }

    public class NackController : Object {
        private uint32 sender_ssrc;
        private uint32 media_ssrc;
        private Gee.ArrayList<NackItem> pending_nacks;
        private uint16 highest_seq_seen;
        private bool initialized;
        private double rtt_ms;

        public const int MAX_RETRIES = 5;
        public const int64 MAX_NACK_LIFETIME_US = 500000; /* 500ms */

        public NackController(uint32 sender_ssrc, uint32 media_ssrc, double rtt_ms = 40.0) {
            this.sender_ssrc = sender_ssrc;
            this.media_ssrc = media_ssrc;
            this.pending_nacks = new Gee.ArrayList<NackItem>();
            this.highest_seq_seen = 0;
            this.initialized = false;
            this.rtt_ms = rtt_ms;
        }

        public void update_rtt(double rtt_ms) {
            this.rtt_ms = (rtt_ms > 10.0) ? rtt_ms : 10.0;
        }

        public void on_packet_received(uint16 seq, int64 now_us = 0) {
            if (now_us == 0) now_us = Clock.get_monotonic_time_us();

            if (!this.initialized) {
                this.initialized = true;
                this.highest_seq_seen = seq;
                return;
            }

            if (Clock.sequence_number_newer(seq, this.highest_seq_seen)) {
                /* Detect missing gap */
                uint16 gap = (uint16) (seq - this.highest_seq_seen - 1);
                if (gap > 0 && gap < 500) {
                    for (uint16 i = 1; i <= gap; i++) {
                        uint16 missing_seq = (uint16) (this.highest_seq_seen + i);
                        this.pending_nacks.add(new NackItem(missing_seq, now_us));
                    }
                }
                this.highest_seq_seen = seq;
            } else {
                /* Late packet arrived: remove from pending nack queue */
                remove_nack(seq);
            }
        }

        public GenericNack? get_nack_feedback(int64 now_us = 0) {
            if (now_us == 0) now_us = Clock.get_monotonic_time_us();
            prune_expired(now_us);

            int64 min_retry_interval_us = (int64) (this.rtt_ms * 1200); /* 1.2 * RTT */
            var nack_pkt = new GenericNack(this.sender_ssrc, this.media_ssrc);
            bool has_items = false;

            foreach (var item in this.pending_nacks) {
                if (item.last_sent_us == 0 || (now_us - item.last_sent_us) >= min_retry_interval_us) {
                    if (item.retries < MAX_RETRIES) {
                        nack_pkt.add_lost_sequence(item.sequence_number);
                        item.last_sent_us = now_us;
                        item.retries++;
                        has_items = true;
                    }
                }
            }

            return has_items ? nack_pkt : null;
        }

        private void remove_nack(uint16 seq) {
            for (int i = 0; i < this.pending_nacks.size; i++) {
                if (this.pending_nacks.get(i).sequence_number == seq) {
                    this.pending_nacks.remove_at(i);
                    return;
                }
            }
        }

        private void prune_expired(int64 now_us) {
            for (int i = this.pending_nacks.size - 1; i >= 0; i--) {
                var item = this.pending_nacks.get(i);
                if (item.retries >= MAX_RETRIES || (now_us - item.first_scheduled_us) > MAX_NACK_LIFETIME_US) {
                    this.pending_nacks.remove_at(i);
                }
            }
        }

        public int pending_count {
            get { return this.pending_nacks.size; }
        }
    }
}
