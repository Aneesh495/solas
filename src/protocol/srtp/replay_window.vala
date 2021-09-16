/*
 * Solas: Real-Time WebRTC Media Engine
 * SRTP Sliding Replay Protection Window (RFC 3711 Section 3.3.2)
 */

namespace Solas.Protocol.Srtp {

    public class ReplayWindow : Object {
        private uint64 highest_index;
        private uint64 window_bitmap;
        private bool initialized;

        public const uint64 WINDOW_SIZE = 64;

        public ReplayWindow() {
            this.reset();
        }

        public void reset() {
            this.highest_index = 0;
            this.window_bitmap = 0;
            this.initialized = false;
        }

        /**
         * Checks if the packet index has been seen before or is too old.
         * Returns true if packet is acceptable (not a replay).
         */
        public bool check(uint64 index) {
            if (!this.initialized) {
                return true;
            }

            if (index > this.highest_index) {
                return true;
            }

            uint64 diff = this.highest_index - index;
            if (diff >= WINDOW_SIZE) {
                /* Packet is older than replay window */
                return false;
            }

            /* If bit at diff is set, packet was already received */
            return (this.window_bitmap & (1ULL << diff)) == 0;
        }

        /**
         * Updates the replay window with an authenticated packet index.
         */
        public void update(uint64 index) {
            if (!this.initialized) {
                this.initialized = true;
                this.highest_index = index;
                this.window_bitmap = 1ULL;
                return;
            }

            if (index > this.highest_index) {
                uint64 diff = index - this.highest_index;
                if (diff < WINDOW_SIZE) {
                    this.window_bitmap <<= (int) diff;
                } else {
                    this.window_bitmap = 0;
                }
                this.window_bitmap |= 1ULL;
                this.highest_index = index;
            } else {
                uint64 diff = this.highest_index - index;
                if (diff < WINDOW_SIZE) {
                    this.window_bitmap |= (1ULL << (int) diff);
                }
            }
        }
    }
}
