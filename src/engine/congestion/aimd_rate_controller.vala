/*
 * Solas: Real-Time WebRTC Media Engine
 * GCC Additive Increase Multiplicative Decrease (AIMD) Rate Controller
 */

using Solas.Core;

namespace Solas.Engine.Congestion {

    public class AimdRateController : Object {
        private double current_bitrate_bps;
        private double min_bitrate_bps;
        private double max_bitrate_bps;
        private double beta; /* Multiplicative backoff factor */
        private int64 last_update_us;

        public AimdRateController(double initial_bps = 1000000.0,
                                  double min_bps = 100000.0,
                                  double max_bps = 20000000.0) {
            this.current_bitrate_bps = initial_bps;
            this.min_bitrate_bps = min_bps;
            this.max_bitrate_bps = max_bps;
            this.beta = 0.85; /* Standard GCC backoff factor */
            this.last_update_us = 0;
        }

        public double update(BandwidthUsageState usage_state, int64 now_us = 0) {
            if (now_us == 0) now_us = Clock.get_monotonic_time_us();

            switch (usage_state) {
                case BandwidthUsageState.OVERUSING:
                    /* Multiplicative decrease */
                    this.current_bitrate_bps *= this.beta;
                    break;

                case BandwidthUsageState.UNDERUSING:
                case BandwidthUsageState.NORMAL:
                    /* Additive increase (or multiplicative ramp during initial probe) */
                    if (this.current_bitrate_bps < 1500000.0) {
                        /* Multiplicative probe */
                        this.current_bitrate_bps *= 1.05;
                    } else {
                        /* Additive increase: +50 kbps per update */
                        this.current_bitrate_bps += 50000.0;
                    }
                    break;
            }

            clamp();
            this.last_update_us = now_us;
            return this.current_bitrate_bps;
        }

        private void clamp() {
            if (this.current_bitrate_bps < this.min_bitrate_bps) {
                this.current_bitrate_bps = this.min_bitrate_bps;
            }
            if (this.current_bitrate_bps > this.max_bitrate_bps) {
                this.current_bitrate_bps = this.max_bitrate_bps;
            }
        }

        public double bitrate_bps {
            get { return this.current_bitrate_bps; }
        }
    }
}
