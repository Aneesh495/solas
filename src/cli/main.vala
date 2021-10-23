/*
 * Solas: Real-Time WebRTC Media Engine
 * CLI Administration Tool Main Entrypoint
 */

using Solas.Core;
using Solas.Cli;

public class SolasCliTool : Object {

    public static int main(string[] args) {
        if (args.length < 2) {
            print_usage();
            return 1;
        }

        var cli_args = CliArgs.parse_args(args);
        var client = new CliClient(cli_args.server_url);

        switch (cli_args.command) {
            case CliCommand.HEALTH:
                try {
                    string res = client.fetch_endpoint("/health");
                    print("%s\n", res.strip());
                } catch (GLib.Error e) {
                    printerr("Health check failed: %s\n", e.message);
                    return 1;
                }
                break;

            case CliCommand.METRICS:
                try {
                    string res = client.fetch_endpoint("/metrics");
                    print("%s\n", res.strip());
                } catch (GLib.Error e) {
                    printerr("Metrics retrieval failed: %s\n", e.message);
                    return 1;
                }
                break;

            case CliCommand.ROOMS:
                try {
                    string res = client.fetch_endpoint("/api/v1/rooms");
                    print("%s\n", res.strip());
                } catch (GLib.Error e) {
                    printerr("Rooms retrieval failed: %s\n", e.message);
                    return 1;
                }
                break;

            case CliCommand.PING:
                print("Sending STUN binding ping to %s:%u...\n", cli_args.ping_host, (uint) cli_args.ping_port);
                try {
                    int64 rtt_us = client.ping_stun(cli_args.ping_host, cli_args.ping_port);
                    print("STUN Pong received: round-trip time = %.2f ms\n", ((double) rtt_us) / 1000.0);
                } catch (GLib.Error e) {
                    printerr("STUN ping failed: %s\n", e.message);
                    return 1;
                }
                break;

            case CliCommand.BENCH:
                print("Running local SFU diagnostics benchmark...\n");
                print("  Target Server: %s\n", cli_args.server_url);
                try {
                    int64 t0 = Clock.get_monotonic_time_us();
                    string res = client.fetch_endpoint("/health");
                    int64 t1 = Clock.get_monotonic_time_us();
                    print("  HTTP /health latency: %.2f ms\n", ((double) (t1 - t0)) / 1000.0);
                    print("  Status: %s\n", res.strip());
                } catch (GLib.Error e) {
                    printerr("Benchmark failed: %s\n", e.message);
                    return 1;
                }
                break;

            default:
                print_usage();
                return 1;
        }

        return 0;
    }

    private static void print_usage() {
        print("Solas CLI Administration Tool v1.0.0\n");
        print("Usage: solas-cli [COMMAND] [OPTIONS]\n\n");
        print("Commands:\n");
        print("  health                  Query server health status\n");
        print("  metrics                 Fetch OpenMetrics / Prometheus telemetry\n");
        print("  rooms                   List all active conference rooms and peers\n");
        print("  ping <host> <port>      Send STUN binding packet to test UDP connectivity\n");
        print("  bench                   Run local ping and response latency benchmark\n\n");
        print("Options:\n");
        print("  --url=<url>             Target server URL (default: http://127.0.0.1:8080)\n");
        print("  --json                  Output raw JSON response\n");
    }
}
