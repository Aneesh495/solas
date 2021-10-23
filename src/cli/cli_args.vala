/*
 * Solas: Real-Time WebRTC Media Engine
 * CLI Command Parser and Argument Dispatcher
 */

namespace Solas.Cli {

    public enum CliCommand {
        NONE = 0,
        ROOMS = 1,
        METRICS = 2,
        HEALTH = 3,
        INSPECT = 4,
        PING = 5,
        BENCH = 6
    }

    public class CliArgs : Object {
        public CliCommand command { get; set; }
        public string server_url { get; set; }
        public string target_room { get; set; }
        public string ping_host { get; set; }
        public uint16 ping_port { get; set; }
        public bool json_output { get; set; }

        public CliArgs() {
            this.command = CliCommand.NONE;
            this.server_url = "http://127.0.0.1:8080";
            this.target_room = "";
            this.ping_host = "127.0.0.1";
            this.ping_port = 5004;
            this.json_output = false;
        }

        public static CliArgs parse_args(string[] args) {
            var res = new CliArgs();

            for (int i = 1; i < args.length; i++) {
                string arg = args[i];

                if (arg == "--json") {
                    res.json_output = true;
                    continue;
                }

                if (arg.has_prefix("--url=")) {
                    res.server_url = arg.substring(6);
                    continue;
                }

                if (res.command == CliCommand.NONE) {
                    if (arg == "rooms") res.command = CliCommand.ROOMS;
                    else if (arg == "metrics") res.command = CliCommand.METRICS;
                    else if (arg == "health") res.command = CliCommand.HEALTH;
                    else if (arg == "inspect") {
                        res.command = CliCommand.INSPECT;
                        if (i + 1 < args.length) {
                            res.target_room = args[++i];
                        }
                    } else if (arg == "ping") {
                        res.command = CliCommand.PING;
                        if (i + 1 < args.length) res.ping_host = args[++i];
                        if (i + 1 < args.length) res.ping_port = (uint16) int.parse(args[++i]);
                    } else if (arg == "bench") {
                        res.command = CliCommand.BENCH;
                    }
                }
            }

            return res;
        }
    }
}
