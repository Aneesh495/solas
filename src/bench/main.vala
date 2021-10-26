/*
 * Solas: Real-Time WebRTC Media Engine
 * Standalone High-Throughput Load Tester and Benchmark Entrypoint
 */

using Solas.Core;
using Solas.Bench;

public class SolasBenchTool : Object {
    private static int publishers = 4;
    private static int subscribers = 16;
    private static int frames = 150;
    private static double loss = 0.0;
    private static double delay = 0.0;
    private static double jitter = 0.0;
    private static bool json_output = false;

    private const OptionEntry[] options = {
        { "publishers", 'p', 0, OptionArg.INT, ref publishers, "Number of concurrent simulated publishers (default: 4)", "NUM" },
        { "subscribers", 's', 0, OptionArg.INT, ref subscribers, "Number of concurrent simulated subscribers (default: 16)", "NUM" },
        { "frames", 'f', 0, OptionArg.INT, ref frames, "Number of synthetic video frames per publisher (default: 150)", "NUM" },
        { "loss", 'l', 0, OptionArg.DOUBLE, ref loss, "Simulated packet loss percentage (default: 0.0%)", "PCT" },
        { "delay", 'd', 0, OptionArg.DOUBLE, ref delay, "Simulated channel baseline delay in milliseconds (default: 0.0)", "MS" },
        { "jitter", 'j', 0, OptionArg.DOUBLE, ref jitter, "Simulated delay jitter in milliseconds (default: 0.0)", "MS" },
        { "json", 0, 0, OptionArg.NONE, ref json_output, "Output results in JSON format", null },
        { null }
    };

    public static int main(string[] args) {
        var opt_context = new OptionContext("- High-Throughput WebRTC SFU Load Tester");
        opt_context.set_help_enabled(true);
        opt_context.add_main_entries(options, null);

        try {
            opt_context.parse(ref args);
        } catch (OptionError e) {
            printerr("solas-bench: %s\n", e.message);
            return 1;
        }

        if (!json_output) {
            print("=================================================================\n");
            print("  Starting Solas WebRTC SFU Multi-Client Load Test...            \n");
            print("=================================================================\n");
            print("  Configuration:\n");
            print("    Simulated Publishers:  %d\n", publishers);
            print("    Simulated Subscribers: %d\n", subscribers);
            print("    Total Frames:          %d per publisher\n", frames);
            if (loss > 0.0) print("    Simulated Loss Rate:   %.2f%%\n", loss);
            print("-----------------------------------------------------------------\n");
            print("  Executing packet routing pipeline...\n");
        }

        var runner = new BenchRunner(publishers, subscribers, frames);
        runner.impairment.loss_rate_percent = loss;
        runner.impairment.base_delay_ms = delay;
        runner.impairment.jitter_ms = jitter;

        var result = runner.execute();

        if (json_output) {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("publishers");
            builder.add_int_value(result.num_publishers);
            builder.set_member_name("subscribers");
            builder.add_int_value(result.num_subscribers);
            builder.set_member_name("total_packets_routed");
            builder.add_int_value((int64) result.total_packets_routed);
            builder.set_member_name("total_bytes_routed");
            builder.add_int_value((int64) result.total_bytes_routed);
            builder.set_member_name("duration_seconds");
            builder.add_double_value(result.duration_seconds);
            builder.set_member_name("packets_per_second");
            builder.add_double_value(result.packets_per_second);
            builder.set_member_name("throughput_mbps");
            builder.add_double_value(result.throughput_mbps);
            builder.set_member_name("latency_p50_us");
            builder.add_double_value(result.latency_p50_us);
            builder.set_member_name("latency_p95_us");
            builder.add_double_value(result.latency_p95_us);
            builder.set_member_name("latency_p99_us");
            builder.add_double_value(result.latency_p99_us);
            builder.set_member_name("latency_max_us");
            builder.add_double_value(result.latency_max_us);
            builder.end_object();

            var gen = new Json.Generator();
            gen.set_root(builder.get_root());
            print("%s\n", gen.to_data(null));
        } else {
            result.print_report();
        }

        return 0;
    }
}
