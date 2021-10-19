/*
 * Solas: Real-Time WebRTC Media Engine
 * Server Configuration Loader and Schema Validator
 */

using Solas.Core;

namespace Solas.Server {

    public class ServerConfig : Object {
        public uint16 http_port { get; set; }
        public uint16 udp_port { get; set; }
        public string public_ip { get; set; }
        public string bind_address { get; set; }
        public uint32 min_bitrate_kbps { get; set; }
        public uint32 max_bitrate_kbps { get; set; }
        public uint32 start_bitrate_kbps { get; set; }
        public bool enable_hls { get; set; }
        public uint32 hls_segment_duration_ms { get; set; }
        public string log_level { get; set; }

        public ServerConfig() {
            this.http_port = 8080;
            this.udp_port = 5004;
            this.public_ip = "127.0.0.1";
            this.bind_address = "0.0.0.0";
            this.min_bitrate_kbps = 300;
            this.max_bitrate_kbps = 6000;
            this.start_bitrate_kbps = 1500;
            this.enable_hls = true;
            this.hls_segment_duration_ms = 2000;
            this.log_level = "info";
        }

        public static ServerConfig load_from_json(string json_content) throws GLib.Error {
            var cfg = new ServerConfig();
            var parser = new Json.Parser();
            parser.load_from_data(json_content);

            var root = parser.get_root().get_object();
            if (root.has_member("http_port")) {
                cfg.http_port = (uint16) root.get_int_member("http_port");
            }
            if (root.has_member("udp_port")) {
                cfg.udp_port = (uint16) root.get_int_member("udp_port");
            }
            if (root.has_member("public_ip")) {
                cfg.public_ip = root.get_string_member("public_ip");
            }
            if (root.has_member("bind_address")) {
                cfg.bind_address = root.get_string_member("bind_address");
            }
            if (root.has_member("min_bitrate_kbps")) {
                cfg.min_bitrate_kbps = (uint32) root.get_int_member("min_bitrate_kbps");
            }
            if (root.has_member("max_bitrate_kbps")) {
                cfg.max_bitrate_kbps = (uint32) root.get_int_member("max_bitrate_kbps");
            }
            if (root.has_member("start_bitrate_kbps")) {
                cfg.start_bitrate_kbps = (uint32) root.get_int_member("start_bitrate_kbps");
            }
            if (root.has_member("enable_hls")) {
                cfg.enable_hls = root.get_boolean_member("enable_hls");
            }
            if (root.has_member("hls_segment_duration_ms")) {
                cfg.hls_segment_duration_ms = (uint32) root.get_int_member("hls_segment_duration_ms");
            }
            if (root.has_member("log_level")) {
                cfg.log_level = root.get_string_member("log_level");
            }

            return cfg;
        }

        public static ServerConfig load_from_file(string path) throws GLib.Error {
            string contents;
            FileUtils.get_contents(path, out contents);
            return load_from_json(contents);
        }

        public string to_json() {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("http_port");
            builder.add_int_value((int64) this.http_port);
            builder.set_member_name("udp_port");
            builder.add_int_value((int64) this.udp_port);
            builder.set_member_name("public_ip");
            builder.add_string_value(this.public_ip);
            builder.set_member_name("bind_address");
            builder.add_string_value(this.bind_address);
            builder.set_member_name("min_bitrate_kbps");
            builder.add_int_value((int64) this.min_bitrate_kbps);
            builder.set_member_name("max_bitrate_kbps");
            builder.add_int_value((int64) this.max_bitrate_kbps);
            builder.set_member_name("start_bitrate_kbps");
            builder.add_int_value((int64) this.start_bitrate_kbps);
            builder.set_member_name("enable_hls");
            builder.add_boolean_value(this.enable_hls);
            builder.set_member_name("hls_segment_duration_ms");
            builder.add_int_value((int64) this.hls_segment_duration_ms);
            builder.set_member_name("log_level");
            builder.add_string_value(this.log_level);
            builder.end_object();

            var gen = new Json.Generator();
            gen.set_root(builder.get_root());
            return gen.to_data(null);
        }
    }
}
