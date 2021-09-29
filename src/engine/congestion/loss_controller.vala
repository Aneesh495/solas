/*
 * Solas: Real-Time WebRTC Media Engine
 * RTCP Receiver Report Loss-Based Bandwidth Controller
 */

namespace Solas.Engine.Congestion {

    public class LossBasedController : Object {
        private double current_bitrate_bps;
        private double min_bitrate_bps;
        private double max_bitrate_bps;

        public LossBasedController(double initial_bps = 1000000.0,
                                   double min_bps = 100000.0,
                                   double max_bps = 20000000.0) {
            this.current_bitrate_bps = initial_bps;
            this.min_bitrate_bps = min_bps;
            this.max_bitrate_bps = max_bps;
        }

        /**
         * Evaluates RTCP RR fraction lost (0..255 representing 0.0 to 1.0).
         * RFC / GCC loss rules:
         * Loss < 2%: rate increased by 5%
         * 2% <= Loss <= 10%: rate kept steady
         * Loss > 10%: rate backed off by (1 - 0.5 * loss)
         */
        public double on_receiver_report(uint8 fraction_lost) {
            double loss_fraction = (double) fraction_lost / 256.0;

            if (loss_fraction < 0.02) {
                this.current_bitrate_bps *= 1.05;
            } else if (loss_fraction > 0.10) {
                double backoff = 1.0 - (0.5 * loss_fraction);
                this.current_bitrate_bps *= backoff;
            }

            clamp();
            return this.current_bitrate_bps;
        }

        private void clamp() {
            if (this.current_bitrate_bps < this.min_bitrate_bps) this.current_bitrate_bps = this.min_bitrate_bps;
            if (this.current_bitrate_bps > this.max_bitrate_bps) this.current_bitrate_bps = this.max_bitrate_bps;
        }

        public double bitrate_bps {
            get { return this.current_bitrate_bps; }
        }
    }
}
