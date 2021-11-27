/*
 * Solas: Real-Time WebRTC Media Engine
 * Adaptive Jitter Playout Delay Estimator using 1D Kalman Filter
 */

using Solas.Core;

namespace Solas.Engine.Jitter {

    public class KalmanPlayoutEstimator : Object {
        /* Process and measurement noise variances */
        public double process_noise_q { get; set; default = 0.001; }
        public double measurement_noise_r { get; set; default = 0.05; }
        public double safety_factor { get; set; default = 2.5; }

        public double min_playout_delay_ms { get; set; default = 20.0; }
        public double max_playout_delay_ms { get; set; default = 500.0; }

        /* State estimate: x is estimated jitter in ms, P is estimation error variance */
        public double state_x { get; private set; }
        public double error_cov_p { get; private set; }

        private int64 last_send_ms;
        private int64 last_recv_ms;
        private bool initialized;

        public KalmanPlayoutEstimator(double q = 0.001, double r = 0.05, double safety = 2.5) {
            this.process_noise_q = q;
            this.measurement_noise_r = r;
            this.safety_factor = safety;
            this.state_x = 30.0; /* Initial 30ms playout delay prior */
            this.error_cov_p = 1.0;
            this.last_send_ms = 0;
            this.last_recv_ms = 0;
            this.initialized = false;
        }

        /**
         * Updates the Kalman filter with a newly arrived packet's timestamps.
         * Returns recommended playout delay in milliseconds.
         */
        public double update(int64 send_ms, int64 recv_ms) {
            if (!this.initialized) {
                this.last_send_ms = send_ms;
                this.last_recv_ms = recv_ms;
                this.initialized = true;
                return this.calculate_target_delay();
            }

            int64 send_delta = send_ms - this.last_send_ms;
            int64 recv_delta = recv_ms - this.last_recv_ms;
            this.last_send_ms = send_ms;
            this.last_recv_ms = recv_ms;

            if (send_delta <= 0) {
                return this.calculate_target_delay();
            }

            /* Delay variation (jitter measurement z) */
            double delay_variation = (double) (recv_delta - send_delta);
            double z = Math.fabs(delay_variation);

            /* 1. Time Update (Prediction) */
            double x_pred = this.state_x;
            double p_pred = this.error_cov_p + this.process_noise_q;

            /* 2. Innovation and Measurement Noise Adaptation */
            double y = z - x_pred;
            double r = this.measurement_noise_r;

            /* Outlier rejection: if innovation is massive (> 4 * standard deviation), inflate R */
            double sigma = Math.sqrt(p_pred + r);
            if (Math.fabs(y) > 4.0 * sigma) {
                r *= 5.0;
            }

            double s = p_pred + r;
            double k = p_pred / s; /* Kalman gain */

            /* 3. Measurement Update (Correction) */
            this.state_x = x_pred + k * y;
            this.error_cov_p = (1.0 - k) * p_pred;

            return this.calculate_target_delay();
        }

        /**
         * Computes optimal playout delay:
         * delay = state_x + (safety_factor * sqrt(error_cov_p))
         */
        public double calculate_target_delay() {
            double uncertainty = Math.sqrt(Math.fmax(this.error_cov_p, 0.0001));
            double target = this.state_x + (this.safety_factor * uncertainty);

            if (target < this.min_playout_delay_ms) {
                target = this.min_playout_delay_ms;
            } else if (target > this.max_playout_delay_ms) {
                target = this.max_playout_delay_ms;
            }

            return target;
        }

        public void reset() {
            this.state_x = 30.0;
            this.error_cov_p = 1.0;
            this.last_send_ms = 0;
            this.last_recv_ms = 0;
            this.initialized = false;
        }
    }
}
