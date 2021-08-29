/*
 * Solas: Real-Time WebRTC Media Engine
 * Statistical Filters, Moving Averages, and Jitter Estimation
 */

namespace Solas.Core {

    /**
     * Exponential Moving Average (EMA) and Percentile Accumulator.
     */
    public class RollingStats : Object {
        private double alpha;
        private double current_ema;
        private bool initialized;
        private double min_val;
        private double max_val;
        private int64 count;

        public RollingStats(double smoothing_factor = 0.125) {
            this.alpha = smoothing_factor;
            this.current_ema = 0.0;
            this.initialized = false;
            this.min_val = double.MAX;
            this.max_val = -double.MAX;
            this.count = 0;
        }

        public void update(double val) {
            if (!this.initialized) {
                this.current_ema = val;
                this.min_val = val;
                this.max_val = val;
                this.initialized = true;
            } else {
                this.current_ema = (this.alpha * val) + ((1.0 - this.alpha) * this.current_ema);
                if (val < this.min_val) this.min_val = val;
                if (val > this.max_val) this.max_val = val;
            }
            this.count++;
        }

        public double value {
            get { return this.current_ema; }
        }

        public double minimum {
            get { return this.min_val; }
        }

        public double maximum {
            get { return this.max_val; }
        }

        public int64 samples {
            get { return this.count; }
        }

        public void reset() {
            this.current_ema = 0.0;
            this.initialized = false;
            this.min_val = double.MAX;
            this.max_val = -double.MAX;
            this.count = 0;
        }
    }

    /**
     * RFC 3550 Inter-Arrival Jitter Estimator:
     * D(i-1, i) = (R_i - S_i) - (R_{i-1} - S_{i-1})
     * J_i = J_{i-1} + (|D(i-1, i)| - J_{i-1}) / 16
     */
    public class JitterFilter : Object {
        private uint32 last_rtp_timestamp;
        private uint32 last_arrival_timestamp;
        private double jitter_units;
        private bool has_first;
        private uint32 clock_rate_hz;

        public JitterFilter(uint32 clock_rate_hz = 90000) {
            this.clock_rate_hz = clock_rate_hz;
            this.reset();
        }

        public void reset() {
            this.last_rtp_timestamp = 0;
            this.last_arrival_timestamp = 0;
            this.jitter_units = 0.0;
            this.has_first = false;
        }

        public void update(uint32 rtp_timestamp, int64 arrival_time_us) {
            /* Convert arrival time to clock rate units */
            uint32 arrival_units = (uint32) ((arrival_time_us * this.clock_rate_hz) / 1000000L);

            if (!this.has_first) {
                this.last_rtp_timestamp = rtp_timestamp;
                this.last_arrival_timestamp = arrival_units;
                this.has_first = true;
                return;
            }

            int32 d = (int32) (arrival_units - this.last_arrival_timestamp) - (int32) (rtp_timestamp - this.last_rtp_timestamp);
            if (d < 0) {
                d = -d;
            }

            this.jitter_units += ((double) d - this.jitter_units) / 16.0;
            this.last_rtp_timestamp = rtp_timestamp;
            this.last_arrival_timestamp = arrival_units;
        }

        public uint32 jitter_in_clock_units {
            get { return (uint32) this.jitter_units; }
        }

        public double jitter_in_milliseconds {
            get { return (this.jitter_units * 1000.0) / (double) this.clock_rate_hz; }
        }
    }

    /**
     * Sliding-window Bitrate Calculator.
     */
    public class BitrateMeter : Object {
        private int64 window_duration_us;
        private Gee.ArrayList<Sample> samples;
        private int64 total_bytes;

        private class Sample {
            public int64 timestamp_us;
            public size_t bytes;
            public Sample(int64 ts, size_t b) {
                this.timestamp_us = ts;
                this.bytes = b;
            }
        }

        public BitrateMeter(int64 window_duration_ms = 1000) {
            this.window_duration_us = window_duration_ms * 1000;
            this.samples = new Gee.ArrayList<Sample>();
            this.total_bytes = 0;
        }

        public void record(size_t bytes, int64 now_us = 0) {
            if (now_us == 0) {
                now_us = Clock.get_monotonic_time_us();
            }
            this.samples.add(new Sample(now_us, bytes));
            this.total_bytes += (int64) bytes;
            prune(now_us);
        }

        public double get_bitrate_bps(int64 now_us = 0) {
            if (now_us == 0) {
                now_us = Clock.get_monotonic_time_us();
            }
            prune(now_us);
            if (this.samples.is_empty) {
                return 0.0;
            }

            double window_secs = (double) this.window_duration_us / 1000000.0;
            return ((double) this.total_bytes * 8.0) / window_secs;
        }

        public double get_bitrate_kbps(int64 now_us = 0) {
            return get_bitrate_bps(now_us) / 1000.0;
        }

        private void prune(int64 now_us) {
            int64 cutoff = now_us - this.window_duration_us;
            while (!this.samples.is_empty && this.samples.get(0).timestamp_us < cutoff) {
                this.total_bytes -= (int64) this.samples.get(0).bytes;
                this.samples.remove_at(0);
            }
        }
    }
}
