/*
 * Solas: Real-Time WebRTC Media Engine
 * CLI Command Parsing Verification Suite
 */

using Solas.Core;
using Solas.Cli;

public class TestCli : Object {

    public static void test_cli_arg_parsing() {
        /* Test health command */
        string[] args_health = { "solas-cli", "health", "--url=http://127.0.0.1:9090", "--json" };
        var parsed_health = CliArgs.parse_args(args_health);
        assert(parsed_health.command == CliCommand.HEALTH);
        assert(parsed_health.server_url == "http://127.0.0.1:9090");
        assert(parsed_health.json_output == true);

        /* Test metrics command */
        string[] args_metrics = { "solas-cli", "metrics" };
        var parsed_metrics = CliArgs.parse_args(args_metrics);
        assert(parsed_metrics.command == CliCommand.METRICS);
        assert(parsed_metrics.server_url == "http://127.0.0.1:8080");
        assert(parsed_metrics.json_output == false);

        /* Test rooms command */
        string[] args_rooms = { "solas-cli", "rooms" };
        var parsed_rooms = CliArgs.parse_args(args_rooms);
        assert(parsed_rooms.command == CliCommand.ROOMS);

        /* Test inspect command */
        string[] args_inspect = { "solas-cli", "inspect", "standup-room" };
        var parsed_inspect = CliArgs.parse_args(args_inspect);
        assert(parsed_inspect.command == CliCommand.INSPECT);
        assert(parsed_inspect.target_room == "standup-room");

        /* Test ping command */
        string[] args_ping = { "solas-cli", "ping", "192.168.1.1", "5004" };
        var parsed_ping = CliArgs.parse_args(args_ping);
        assert(parsed_ping.command == CliCommand.PING);
        assert(parsed_ping.ping_host == "192.168.1.1");
        assert(parsed_ping.ping_port == 5004);

        /* Test bench command */
        string[] args_bench = { "solas-cli", "bench" };
        var parsed_bench = CliArgs.parse_args(args_bench);
        assert(parsed_bench.command == CliCommand.BENCH);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/cli/arg_parsing", test_cli_arg_parsing);

        return Test.run();
    }
}
