/*
 * Solas: Real-Time WebRTC Media Engine
 * Priority Leaky-Bucket Packet Pacer and Prober
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Engine.Congestion {

    public enum PacketPriority {
        AUDIO = 0,
        RETRANSMISSION = 1,
        VIDEO_KEYFRAME = 2,
        VIDEO_DELTA = 3,
        PADDING = 4
    }

    public class PacedPacket : Object {
        public PacketPriority priority { get; set; }
        public RtpPacket packet { get; set; }
        public int64 enqueue_time_us { get; set; }

        public PacedPacket(PacketPriority prio, RtpPacket pkt, int64 enqueue_us) {
            this.priority = prio;
            this.packet = pkt;
            this.enqueue_time_us = enqueue_us;
        }
    }

    public class Pacer : Object {
        private Gee.ArrayList<PacedPacket> queue;
        private double pacing_bitrate_bps;
        private double padding_bitrate_bps;
        private double tokens_bytes;
        private int64 last_update_us;

        public Pacer(double initial_pacing_bps = 2000000.0) {
            this.queue = new Gee.ArrayList<PacedPacket>();
            this.pacing_bitrate_bps = initial_pacing_bps;
            this.padding_bitrate_bps = 0.0;
            this.tokens_bytes = 0.0;
            this.last_update_us = Clock.get_monotonic_time_us();
        }

        public void set_pacing_bitrate(double bps) {
            this.pacing_bitrate_bps = (bps > 100000.0) ? bps : 100000.0;
        }

        public void enqueue(PacketPriority priority, RtpPacket pkt, int64 now_us = 0) {
            if (now_us == 0) now_us = Clock.get_monotonic_time_us();

            /* Insert ordered by priority (Audio first) */
            int insert_idx = this.queue.size;
            for (int i = 0; i < this.queue.size; i++) {
                if (this.queue.get(i).priority > priority) {
                    insert_idx = i;
                    break;
                }
            }
            this.queue.insert(insert_idx, new PacedPacket(priority, pkt, now_us));
        }

        /**
         * Pulls the next packet allowed by the leaky bucket token budget.
         */
        public RtpPacket? poll_packet(int64 now_us = 0) {
            if (now_us == 0) now_us = Clock.get_monotonic_time_us();
            refill_tokens(now_us);

            if (this.queue.is_empty) return null;

            var head = this.queue.get(0);
            size_t pkt_len = head.packet.payload.length + 12;

            if (this.tokens_bytes >= (double) pkt_len || head.priority == PacketPriority.AUDIO) {
                /* Audio packets bypass budget to prevent audio latency */
                this.tokens_bytes -= (double) pkt_len;
                return this.queue.remove_at(0).packet;
            }

            return null;
        }

        private void refill_tokens(int64 now_us) {
            int64 delta_us = now_us - this.last_update_us;
            if (delta_us > 0) {
                double added_bytes = ((double) delta_us / 1000000.0) * (this.pacing_bitrate_bps / 8.0);
                this.tokens_bytes += added_bytes;
                double max_tokens = (this.pacing_bitrate_bps / 8.0) * 0.05; /* Max 50ms token burst */
                if (this.tokens_bytes > max_tokens) {
                    this.tokens_bytes = max_tokens;
                }
                this.last_update_us = now_us;
            }
        }

        public int queued_packets {
            get { return this.queue.size; }
        }
    }
}
