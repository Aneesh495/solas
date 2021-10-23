/*
 * Solas: Real-Time WebRTC Media Engine
 * CLI Administration Client and Diagnostic Probe
 */

using Solas.Core;
using Solas.Protocol.Stun;

namespace Solas.Cli {

    public class CliClient : Object {
        private string base_url;

        public CliClient(string base_url = "http://127.0.0.1:8080") {
            this.base_url = base_url;
        }

        /**
         * Sends a raw HTTP GET request using non-blocking GIO socket streams.
         */
        public string fetch_endpoint(string path) throws GLib.Error {
            string host = "127.0.0.1";
            uint16 port = 8080;

            if (this.base_url.has_prefix("http://")) {
                string trimmed = this.base_url.substring(7);
                string[] parts = trimmed.split(":");
                host = parts[0];
                if (parts.length > 1) {
                    port = (uint16) int.parse(parts[1]);
                }
            }

            var client = new SocketClient();
            var conn = client.connect_to_host(host, port, null);

            var out_stream = conn.get_output_stream();
            var in_stream = new DataInputStream(conn.get_input_stream());

            string req = "GET %s HTTP/1.1\r\nHost: %s:%u\r\nUser-Agent: SolasCli/1.0\r\nConnection: close\r\n\r\n".printf(path, host, (uint) port);
            out_stream.write_all(req.data, null);

            var sb = new StringBuilder();
            bool in_body = false;
            string? line = null;
            size_t length;

            while ((line = in_stream.read_line(out length, null)) != null) {
                if (in_body) {
                    sb.append(line);
                    sb.append("\n");
                } else if (line.strip() == "") {
                    in_body = true;
                }
            }

            conn.close();
            return sb.str;
        }

        /**
         * Sends a low-level STUN binding ping over UDP and measures roundtrip time.
         */
        public int64 ping_stun(string host, uint16 port) throws GLib.Error {
            var socket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
            socket.set_timeout(2); /* 2 second timeout */

            var dest = new InetSocketAddress(new InetAddress.from_string(host), port);
            var req = StunMessage.create_binding_request();
            uint8[] bytes = req.serialize(null, true);

            int64 start_time = Clock.get_monotonic_time_us();
            socket.send_to(dest, bytes, null);

            uint8[] buf = new uint8[512];
            SocketAddress reply_addr;
            socket.receive_from(out reply_addr, buf, null);
            int64 elapsed_us = Clock.get_monotonic_time_us() - start_time;

            socket.close();
            return elapsed_us;
        }
    }
}
