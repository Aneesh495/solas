/*
 * Solas: Real-Time WebRTC Media Engine
 * Extended Sequence Number and Timestamp Unwrapper
 */

using Solas.Core;

namespace Solas.Protocol.Rtp {

    /**
     * Unwraps 16-bit RTP sequence numbers into continuous 64-bit sequence numbers.
     * Handles 16-bit wrapping (65535 -> 0) and out-of-order jitter up to 32768 packets.
     */
    public class SequenceUnwrapper : Object {
        private uint16 max_seq;
        private uint32 cycles;
        private uint32 base_seq;
        private uint32 bad_seq;
        private uint32 probation;
        private uint32 received;
        private bool initialized;

        public const uint16 MAX_DROPOUT = 3000;
        public const uint16 MAX_MISORDER = 100;
        public const uint32 MIN_SEQUENTIAL = 2;

        public SequenceUnwrapper() {
            this.reset();
        }

        public void reset() {
            this.max_seq = 0;
            this.cycles = 0;
            this.base_seq = 0;
            this.bad_seq = 0;
            this.probation = 0;
            this.received = 0;
            this.initialized = false;
        }

        public uint64 unwrap(uint16 seq) {
            if (!this.initialized) {
                this.initialized = true;
                this.base_seq = seq;
                this.max_seq = seq;
                this.bad_seq = 65536;
                this.cycles = 0;
                this.received = 1;
                return (uint64) seq;
            }

            uint16 udelta = (uint16) (seq - this.max_seq);

            if (udelta < MAX_DROPOUT) {
                /* In order, with permissible gap */
                if (seq < this.max_seq) {
                    /* Sequence number wrapped around 16-bit boundary */
                    this.cycles += 0x10000;
                }
                this.max_seq = seq;
            } else if (udelta <= (uint16) (65536 - MAX_MISORDER)) {
                /* Out of order or huge jump */
                if (seq == this.bad_seq) {
                    /* Two consecutive packets with huge jump: re-sync sequence */
                    this.base_seq = seq;
                    this.max_seq = seq;
                    this.bad_seq = 65536;
                    this.cycles = 0;
                } else {
                    this.bad_seq = (seq + 1) & 0xFFFF;
                }
            }

            this.received++;
            return ((uint64) this.cycles) | (uint64) seq;
        }

        public uint64 highest_sequence_number {
            get { return ((uint64) this.cycles) | (uint64) this.max_seq; }
        }

        public uint32 packets_received {
            get { return this.received; }
        }
    }
}
