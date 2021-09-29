/*
 * Solas: Real-Time WebRTC Media Engine
 * Unified GCC Bandwidth Estimator
 */

namespace Solas.Engine.Congestion {

    public class BandwidthEstimator : Object {
        private TrendlineEstimator delay_estimator;
        private AimdRateController aimd_controller;
        private LossBasedController loss_controller;
        private double target_bitrate_bps;

        public BandwidthEstimator(double initial_bps = 1500000.0) {
            this.delay_estimator = new TrendlineEstimator();
            this.aimd_controller = new AimdRateController(initial_bps);
            this.loss_controller = new LossBasedController(initial_bps);
            this.target_bitrate_bps = initial_bps;
        }

        public void on_packet_feedback(double send_time_ms, double arrival_time_ms) {
            this.delay_estimator.update(send_time_ms, arrival_time_ms);
            double delay_target = this.aimd_controller.update(this.delay_estimator.state);
            reconcile();
        }

        public void on_receiver_report(uint8 fraction_lost) {
            this.loss_controller.on_receiver_report(fraction_lost);
            reconcile();
        }

        private void reconcile() {
            /* Target bitrate is the minimum of delay-based and loss-based estimates */
            double delay_bwe = this.aimd_controller.bitrate_bps;
            double loss_bwe = this.loss_controller.bitrate_bps;
            this.target_bitrate_bps = (delay_bwe < loss_bwe) ? delay_bwe : loss_bwe;
        }

        public double current_target_bitrate_bps {
            get { return this.target_bitrate_bps; }
        }

        public double current_target_bitrate_kbps {
            get { return this.target_bitrate_bps / 1000.0; }
        }

        public BandwidthUsageState current_usage_state {
            get { return this.delay_estimator.state; }
        }
    }
}
