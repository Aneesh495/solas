/*
 * Solas: Real-Time WebRTC Media Engine
 * Multi-Packet Video Frame Assembler
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Engine.Jitter {

    public class CompleteFrame : Object {
        public uint32 timestamp { get; set; }
        public uint32 ssrc { get; set; }
        public Gee.ArrayList<RtpPacket> packets { get; private set; }

        public CompleteFrame(uint32 timestamp, uint32 ssrc) {
            this.timestamp = timestamp;
            this.ssrc = ssrc;
            this.packets = new Gee.ArrayList<RtpPacket>();
        }

        public size_t total_payload_bytes {
            get {
                size_t sum = 0;
                foreach (var p in this.packets) {
                    sum += p.payload.length;
                }
                return sum;
            }
        }
    }

    public class FrameAssembler : Object {
        private PacketBuffer buffer;
        private uint64 expected_next_seq;
        private bool initialized;

        public FrameAssembler() {
            this.buffer = new PacketBuffer(500);
            this.expected_next_seq = 0;
            this.initialized = false;
        }

        public void push_packet(uint64 unwrapped_seq, int64 arrival_us, RtpPacket pkt) {
            this.buffer.insert(unwrapped_seq, arrival_us, pkt);
            if (!this.initialized) {
                this.initialized = true;
                this.expected_next_seq = unwrapped_seq;
            }
        }

        /**
         * Assembles next complete frame if all sequence numbers up to marker=true are present.
         */
        public CompleteFrame? poll_complete_frame() {
            if (this.buffer.is_empty) return null;

            /* Check if expected_next_seq is head of buffer */
            var head = this.buffer.peek();
            if (head == null || head.unwrapped_seq != this.expected_next_seq) {
                return null;
            }

            /* Look forward in buffer to find marker bit with contiguous sequence numbers */
            uint64 cur_seq = this.expected_next_seq;
            int marker_idx = -1;

            for (size_t i = 0; i < this.buffer.size; i++) {
                var item = this.buffer.get_by_seq(cur_seq);
                if (item == null) {
                    /* Gap in sequence numbers: wait for retransmission */
                    return null;
                }

                if (item.packet.marker) {
                    marker_idx = (int) i;
                    break;
                }
                cur_seq++;
            }

            if (marker_idx == -1) {
                /* Frame end not yet received */
                return null;
            }

            /* Contiguous frame found: pop all packets belonging to this frame */
            var frame = new CompleteFrame(head.packet.timestamp, head.packet.ssrc);
            while (!this.buffer.is_empty) {
                var p = this.buffer.pop();
                frame.packets.add(p.packet);
                this.expected_next_seq = p.unwrapped_seq + 1;
                if (p.packet.marker) {
                    break;
                }
            }

            return frame;
        }
    }
}
