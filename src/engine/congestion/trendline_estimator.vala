/*
 * Solas: Real-Time WebRTC Media Engine
 * Google Congestion Control (GCC) Delay-Based Trendline Estimator
 */

using Solas.Core;

namespace Solas.Engine.Congestion {

    public enum BandwidthUsageState {
        NORMAL = 0,
        OVERUSING = 1,
        UNDERUSING = 2
    }

    public class PacketGroupSample : Object {
        public double departure_time_ms { get; set; }
        public double arrival_time_ms { get; set; }
        public double accumulated_delay_ms { get; set; }

        public PacketGroupSample(double dep_ms, double arr_ms, double acc_ms) {
            this.departure_time_ms = dep_ms;
            this.arrival_time_ms = arr_ms;
            this.accumulated_delay_ms = acc_ms;
        }
    }

    public class TrendlineEstimator : Object {
        private Gee.ArrayList<PacketGroupSample> samples;
        private size_t window_size;
        private double threshold;
        private double trendline_slope;
        private BandwidthUsageState current_state;
        private int overuse_counter;
        private double last_arrival_ms;
        private double last_departure_ms;
        private double accumulated_delay_ms;

        public const double INITIAL_THRESHOLD = 5.0;
        public const double THRESHOLD_GAIN = 0.001;

        public TrendlineEstimator(size_t window_size = 20) {
            this.samples = new Gee.ArrayList<PacketGroupSample>();
            this.window_size = window_size;
            this.threshold = INITIAL_THRESHOLD;
            this.trendline_slope = 0.0;
            this.current_state = BandwidthUsageState.NORMAL;
            this.overuse_counter = 0;
            this.last_arrival_ms = 0.0;
            this.last_departure_ms = 0.0;
            this.accumulated_delay_ms = 0.0;
        }

        public void update(double send_time_ms, double arrival_time_ms) {
            if (this.last_arrival_ms == 0.0) {
                this.last_arrival_ms = arrival_time_ms;
                this.last_departure_ms = send_time_ms;
                return;
            }

            double delta_departure = send_time_ms - this.last_departure_ms;
            double delta_arrival = arrival_time_ms - this.last_arrival_ms;
            double delta_delay = delta_arrival - delta_departure;

            this.accumulated_delay_ms += delta_delay;
            this.last_departure_ms = send_time_ms;
            this.last_arrival_ms = arrival_time_ms;

            this.samples.add(new PacketGroupSample(send_time_ms, arrival_time_ms, this.accumulated_delay_ms));
            while (this.samples.size > this.window_size) {
                this.samples.remove_at(0);
            }

            if (this.samples.size >= 10) {
                compute_trendline();
                detect_overuse();
            }
        }

        private void compute_trendline() {
            /* Linear regression: slope = Cov(x, y) / Var(x) */
            double sum_x = 0.0;
            double sum_y = 0.0;
            double first_arr = this.samples.get(0).arrival_time_ms;

            foreach (var s in this.samples) {
                sum_x += (s.arrival_time_ms - first_arr);
                sum_y += s.accumulated_delay_ms;
            }

            double mean_x = sum_x / (double) this.samples.size;
            double mean_y = sum_y / (double) this.samples.size;

            double numerator = 0.0;
            double denominator = 0.0;

            foreach (var s in this.samples) {
                double x = (s.arrival_time_ms - first_arr) - mean_x;
                double y = s.accumulated_delay_ms - mean_y;
                numerator += (x * y);
                denominator += (x * x);
            }

            if (denominator > 0.0001) {
                this.trendline_slope = numerator / denominator;
            }
        }

        private void detect_overuse() {
            double modified_slope = this.trendline_slope * (double) this.samples.size;

            if (modified_slope > this.threshold) {
                this.overuse_counter++;
                if (this.overuse_counter >= 3) {
                    this.current_state = BandwidthUsageState.OVERUSING;
                }
            } else if (modified_slope < -this.threshold) {
                this.overuse_counter = 0;
                this.current_state = BandwidthUsageState.UNDERUSING;
            } else {
                this.overuse_counter = 0;
                this.current_state = BandwidthUsageState.NORMAL;
            }

            /* Adaptive threshold drift */
            this.threshold += THRESHOLD_GAIN * (Math.fabs(modified_slope) - this.threshold);
            if (this.threshold < 2.0) this.threshold = 2.0;
            if (this.threshold > 60.0) this.threshold = 60.0;
        }

        public BandwidthUsageState state {
            get { return this.current_state; }
        }

        public double slope {
            get { return this.trendline_slope; }
        }
    }
}
