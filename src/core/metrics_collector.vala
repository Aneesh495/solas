/*
 * Solas: Real-Time WebRTC Media Engine
 * Prometheus Metrics Exporter: Counters, Gauges, and Latency Histograms
 */

using Solas.Core;

namespace Solas.Core {

    public class PrometheusCounter : Object {
        public string name { get; construct; }
        public string help { get; construct; }
        public double value { get; private set; }

        public PrometheusCounter(string name, string help) {
            GLib.Object(name: name, help: help);
            this.value = 0.0;
        }

        public void inc(double delta = 1.0) {
            if (delta > 0.0) {
                this.value += delta;
            }
        }

        public string render() {
            var sb = new StringBuilder();
            sb.append_printf("# HELP %s %s\n", this.name, this.help);
            sb.append_printf("# TYPE %s counter\n", this.name);
            sb.append_printf("%s %.0f\n", this.name, this.value);
            return sb.str;
        }
    }

    public class PrometheusGauge : Object {
        public string name { get; construct; }
        public string help { get; construct; }
        public double value { get; private set; }

        public PrometheusGauge(string name, string help) {
            GLib.Object(name: name, help: help);
            this.value = 0.0;
        }

        public void update_value(double val) {
            this.value = val;
        }

        public void inc(double delta = 1.0) {
            this.value += delta;
        }

        public void dec(double delta = 1.0) {
            this.value -= delta;
        }

        public string render() {
            var sb = new StringBuilder();
            sb.append_printf("# HELP %s %s\n", this.name, this.help);
            sb.append_printf("# TYPE %s gauge\n", this.name);
            sb.append_printf("%s %.2f\n", this.name, this.value);
            return sb.str;
        }
    }

    public class PrometheusHistogram : Object {
        public string name { get; construct; }
        public string help { get; construct; }

        private double[] buckets;
        private uint64[] bucket_counts;
        public uint64 count { get; private set; }
        public double sum { get; private set; }

        public PrometheusHistogram(string name, string help, double[]? custom_bounds = null) {
            GLib.Object(name: name, help: help);

            if (custom_bounds != null && custom_bounds.length > 0) {
                this.buckets = custom_bounds;
            } else {
                /* Default sub-millisecond to multi-second latency bounds in seconds */
                this.buckets = new double[] {
                    0.001, 0.002, 0.005, 0.010, 0.025, 0.050, 0.100, 0.250, 0.500, 1.000, 2.500, 5.000
                };
            }

            this.bucket_counts = new uint64[this.buckets.length];
            this.count = 0;
            this.sum = 0.0;
        }

        public void observe(double val) {
            this.count++;
            this.sum += val;

            for (int i = 0; i < this.buckets.length; i++) {
                if (val <= this.buckets[i]) {
                    this.bucket_counts[i]++;
                }
            }
        }

        public string render() {
            var sb = new StringBuilder();
            sb.append_printf("# HELP %s %s\n", this.name, this.help);
            sb.append_printf("# TYPE %s histogram\n", this.name);

            for (int i = 0; i < this.buckets.length; i++) {
                sb.append_printf("%s_bucket{le=\"%.3f\"} %llu\n", this.name, this.buckets[i], this.bucket_counts[i]);
            }
            sb.append_printf("%s_bucket{le=\"+Inf\"} %llu\n", this.name, this.count);
            sb.append_printf("%s_sum %.6f\n", this.name, this.sum);
            sb.append_printf("%s_count %llu\n", this.name, this.count);

            return sb.str;
        }
    }

    public class MetricsRegistry : Object {
        private Gee.HashMap<string, PrometheusCounter> counters;
        private Gee.HashMap<string, PrometheusGauge> gauges;
        private Gee.HashMap<string, PrometheusHistogram> histograms;

        private static MetricsRegistry? instance;

        public static MetricsRegistry get_default() {
            if (instance == null) {
                instance = new MetricsRegistry();
            }
            return instance;
        }

        public MetricsRegistry() {
            this.counters = new Gee.HashMap<string, PrometheusCounter>();
            this.gauges = new Gee.HashMap<string, PrometheusGauge>();
            this.histograms = new Gee.HashMap<string, PrometheusHistogram>();
        }

        public PrometheusCounter register_counter(string name, string help) {
            var c = new PrometheusCounter(name, help);
            this.counters.set(name, c);
            return c;
        }

        public PrometheusGauge register_gauge(string name, string help) {
            var g = new PrometheusGauge(name, help);
            this.gauges.set(name, g);
            return g;
        }

        public PrometheusHistogram register_histogram(string name, string help, double[]? bounds = null) {
            var h = new PrometheusHistogram(name, help, bounds);
            this.histograms.set(name, h);
            return h;
        }

        public string export_prometheus() {
            var sb = new StringBuilder();

            foreach (var entry in this.counters.entries) {
                sb.append(entry.value.render());
            }
            foreach (var entry in this.gauges.entries) {
                sb.append(entry.value.render());
            }
            foreach (var entry in this.histograms.entries) {
                sb.append(entry.value.render());
            }

            return sb.str;
        }
    }
}
