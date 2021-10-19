/*
 * Solas: Real-Time WebRTC Media Engine
 * Standalone Server Executable Entrypoint
 */

using Solas.Core;
using Solas.Server;

public class SolasDaemon : Object {
    private static string config_path = "";
    private static int http_port = 0;
    private static int udp_port = 0;
    private static bool version_flag = false;

    private const OptionEntry[] options = {
        { "config", 'c', 0, OptionArg.FILENAME, ref config_path, "Path to configuration file", "PATH" },
        { "port", 'p', 0, OptionArg.INT, ref http_port, "HTTP / WebSocket signaling port (default: 8080)", "PORT" },
        { "udp-port", 'u', 0, OptionArg.INT, ref udp_port, "UDP RTP/RTCP media multiplexing port (default: 5004)", "PORT" },
        { "version", 'v', 0, OptionArg.NONE, ref version_flag, "Print version information and exit", null },
        { null }
    };

    public static int main(string[] args) {
        var opt_context = new OptionContext("- High-Performance WebRTC Selective Forwarding Unit");
        opt_context.set_help_enabled(true);
        opt_context.add_main_entries(options, null);

        try {
            opt_context.parse(ref args);
        } catch (OptionError e) {
            printerr("solas-server: %s\n", e.message);
            printerr("Run 'solas-server --help' to see a full list of available options.\n");
            return 1;
        }

        if (version_flag) {
            print("Solas WebRTC Media Server v1.0.0\n");
            print("RFC Standards: RFC 3550, RFC 3711, RFC 5389, RFC 8489, RFC 8866, RFC 8888\n");
            print("Architecture: Zero-copy selective forwarding, GCC Congestion Control, fMP4/HLS\n");
            return 0;
        }

        ServerConfig config;
        if (config_path != "") {
            try {
                config = ServerConfig.load_from_file(config_path);
            } catch (GLib.Error e) {
                printerr("Error loading config from %s: %s\n", config_path, e.message);
                return 1;
            }
        } else {
            config = new ServerConfig();
        }

        if (http_port > 0) {
            config.http_port = (uint16) http_port;
        }
        if (udp_port > 0) {
            config.udp_port = (uint16) udp_port;
        }

        print("=================================================================\n");
        print("   ____       _               __  __          _ _               \n");
        print("  / ___|  ___| | __ _ ___    |  \\/  | ___  __| (_) __ _         \n");
        print("  \\___ \\ / _ \\ |/ _` / __|   | |\\/| |/ _ \\/ _` | |/ _` |        \n");
        print("   ___) | (_) | | (_| \\__ \\   | |  | |  __/ (_| | | (_| |        \n");
        print("  |____/ \\___/|_|\\__,_|___/   |_|  |_|\\___|\\__,_|_|\\__,_|        \n");
        print("  Ultra-Low-Latency WebRTC Selective Forwarding Engine           \n");
        print("=================================================================\n");

        var server = new SolasServer(config);

        /* Handle Unix signals for graceful shutdown */
        Unix.signal_add(Posix.Signal.INT, () => {
            Logger.info("DAEMON", "Received SIGINT, initiating graceful shutdown...");
            server.stop();
            return Source.REMOVE;
        });

        Unix.signal_add(Posix.Signal.TERM, () => {
            Logger.info("DAEMON", "Received SIGTERM, initiating graceful shutdown...");
            server.stop();
            return Source.REMOVE;
        });

        try {
            server.start();
        } catch (GLib.Error e) {
            printerr("Fatal server startup error: %s\n", e.message);
            return 1;
        }

        return 0;
    }
}
