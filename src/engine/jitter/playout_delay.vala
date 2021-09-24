/*
 * Solas: Real-Time WebRTC Media Engine
 * Adaptive Playout Delay Estimator
 */

using Solas.Core;

namespace Solas.Engine.Jitter {

    public class PlayoutDelayEstimator : Object {
        private JitterFilter jitter_filter;
        private RollingStats rtt_stats;
        private double min_playout_delay_ms;
        private double max_playout_delay_ms;
        private double current_target_delay_ms;

        public PlayoutDelayEstimator(uint32 clock_rate_hz = 90000,
                                     double min_delay_ms = 10.0,
                                     double max_delay_ms = 250.0) {
            this.jitter_filter = new JitterFilter(clock_rate_hz);
            this.rtt_stats = new RollingStats(0.2);
            this.min_playout_delay_ms = min_delay_ms;
            this.max_playout_delay_ms = max_delay_ms;
            this.current_target_delay_ms = min_delay_ms;
        }

        public void record_packet(uint32 rtp_timestamp, int64 arrival_time_us) {
            this.jitter_filter.update(rtp_timestamp, arrival_time_us);
            recalculate();
        }

        public void record_rtt(double rtt_ms) {
            this.rtt_stats.update(rtt_ms);
            recalculate();
        }

        private void recalculate() {
            double jitter_ms = this.jitter_filter.jitter_in_milliseconds;
            /* Adaptive safety margin: min_delay + 3 * jitter + 0.5 * RTT */
            double calculated = this.min_playout_delay_ms + (3.0 * jitter_ms) + (0.5 * this.rtt_stats.value);
            if (calculated < this.min_playout_delay_ms) calculated = this.min_playout_delay_ms;
            if (calculated > this.max_playout_delay_ms) calculated = this.max_playout_delay_ms;
            this.current_target_delay_ms = calculated;
        }

        public double target_delay_ms {
            get { return this.current_target_delay_ms; }
        }

        public double estimated_jitter_ms {
            get { return this.jitter_filter.jitter_in_milliseconds; }
        }
    }
}
