/*
 * Solas: Real-Time WebRTC Media Engine
 * Prometheus Metrics Exporter and Latency Histogram Test Suite
 */

using Solas.Core;

public class TestMetricsCollector : Object {

    public static void test_counter() {
        var counter = new PrometheusCounter("solas_packets_total", "Total forwarded packets");
        assert(counter.value == 0.0);

        counter.inc(10.0);
        counter.inc(5.0);
        assert(counter.value == 15.0);

        string rendered = counter.render();
        assert(rendered.contains("# TYPE solas_packets_total counter"));
        assert(rendered.contains("solas_packets_total 15"));
    }

    public static void test_gauge() {
        var gauge = new PrometheusGauge("solas_active_rooms", "Active conference rooms");
        assert(gauge.value == 0.0);

        gauge.update_value(4.0);
        gauge.inc();
        assert(gauge.value == 5.0);

        gauge.dec(2.0);
        assert(gauge.value == 3.0);

        string rendered = gauge.render();
        assert(rendered.contains("# TYPE solas_active_rooms gauge"));
        assert(rendered.contains("solas_active_rooms 3.00"));
    }

    public static void test_histogram() {
        double[] custom_bounds = new double[] { 0.010, 0.050, 0.100 };
        var hist = new PrometheusHistogram("solas_rtt_seconds", "RTT latency distribution", custom_bounds);

        hist.observe(0.005); /* falls into <= 0.010 */
        hist.observe(0.040); /* falls into <= 0.050 */
        hist.observe(0.080); /* falls into <= 0.100 */
        hist.observe(0.200); /* falls into +Inf */

        assert(hist.count == 4);
        assert(hist.sum >= 0.324 && hist.sum <= 0.326);

        string rendered = hist.render();
        assert(rendered.contains("# TYPE solas_rtt_seconds histogram"));
        assert(rendered.contains("solas_rtt_seconds_bucket{le=\"0.010\"} 1"));
        assert(rendered.contains("solas_rtt_seconds_bucket{le=\"0.050\"} 2"));
        assert(rendered.contains("solas_rtt_seconds_bucket{le=\"0.100\"} 3"));
        assert(rendered.contains("solas_rtt_seconds_bucket{le=\"+Inf\"} 4"));
        assert(rendered.contains("solas_rtt_seconds_count 4"));
    }

    public static void test_metrics_registry() {
        var registry = new MetricsRegistry();
        var c = registry.register_counter("solas_bytes_in", "Bytes received");
        var g = registry.register_gauge("solas_peers", "Connected peers");
        var h = registry.register_histogram("solas_jitter_sec", "Jitter in seconds");

        c.inc(1024.0);
        g.update_value(12.0);
        h.observe(0.003);

        string exp = registry.export_prometheus();
        assert(exp.contains("solas_bytes_in 1024"));
        assert(exp.contains("solas_peers 12.00"));
        assert(exp.contains("solas_jitter_sec_count 1"));
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/metrics/counter", test_counter);
        Test.add_func("/metrics/gauge", test_gauge);
        Test.add_func("/metrics/histogram", test_histogram);
        Test.add_func("/metrics/registry", test_metrics_registry);

        return Test.run();
    }
}
