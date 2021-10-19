/*
 * Solas: Real-Time WebRTC Media Engine
 * Server Daemon and Configuration Verification Suite
 */

using Solas.Core;
using Solas.Server;
using Solas.Protocol.Stun;

public class TestServer : Object {

    public static void test_config_loader() {
        var cfg = new ServerConfig();
        assert(cfg.http_port == 8080);
        assert(cfg.udp_port == 5004);
        assert(cfg.min_bitrate_kbps == 300);
        assert(cfg.max_bitrate_kbps == 6000);

        string json = cfg.to_json();
        assert(json.contains("\"http_port\":8080") || json.contains("\"http_port\": 8080"));
        assert(json.contains("\"udp_port\":5004") || json.contains("\"udp_port\": 5004"));

        string custom_json = "{\n" +
                             "  \"http_port\": 9090,\n" +
                             "  \"udp_port\": 7000,\n" +
                             "  \"public_ip\": \"198.51.100.1\",\n" +
                             "  \"min_bitrate_kbps\": 500,\n" +
                             "  \"max_bitrate_kbps\": 8000,\n" +
                             "  \"start_bitrate_kbps\": 2500,\n" +
                             "  \"enable_hls\": false,\n" +
                             "  \"hls_segment_duration_ms\": 1000,\n" +
                             "  \"log_level\": \"debug\"\n" +
                             "}";

        try {
            var loaded = ServerConfig.load_from_json(custom_json);
            assert(loaded.http_port == 9090);
            assert(loaded.udp_port == 7000);
            assert(loaded.public_ip == "198.51.100.1");
            assert(loaded.min_bitrate_kbps == 500);
            assert(loaded.max_bitrate_kbps == 8000);
            assert(loaded.enable_hls == false);
            assert(loaded.log_level == "debug");
        } catch (GLib.Error e) {
            assert_not_reached();
        }
    }

    public static void test_server_lifecycle() {
        var cfg = new ServerConfig();
        cfg.udp_port = 15004; /* Non-privileged test port */
        cfg.http_port = 18080;

        var server = new SolasServer(cfg);
        assert(!server.running);
        assert(server.rooms.size == 0);
        assert(server.sessions.size == 0);

        var room = server.get_or_create_room("engineering-standup");
        assert(room != null);
        assert(server.rooms.size == 1);
        assert(server.rooms.has_key("engineering-standup"));

        /* Create signaling session */
        var session = server.create_signaling_session("sess-001");
        assert(session != null);
        assert(server.sessions.size == 1);
        assert(session.ice_agent.local_candidates.size >= 1);

        server.remove_signaling_session("sess-001");
        assert(server.sessions.size == 0);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/server/config_loader", test_config_loader);
        Test.add_func("/server/lifecycle", test_server_lifecycle);

        return Test.run();
    }
}
