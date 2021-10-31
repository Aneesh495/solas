/*
 * Solas: Real-Time WebRTC Media Engine
 * Lightweight Embedded HTTP/1.1 REST Server
 */

using Solas.Core;
using Solas.Engine.Sfu;
using Solas.Protocol.Sdp;

namespace Solas.Network {

    public class HttpRequest : Object {
        public string method { get; set; }
        public string path { get; set; }
        public Gee.HashMap<string, string> headers { get; private set; }
        public string body { get; set; }

        public HttpRequest() {
            this.method = "GET";
            this.path = "/";
            this.headers = new Gee.HashMap<string, string>();
            this.body = "";
        }

        public static HttpRequest? parse(string raw_http) {
            string[] lines = raw_http.split("\r\n");
            if (lines.length < 1) return null;

            string[] req_line = lines[0].split(" ");
            if (req_line.length < 2) return null;

            var req = new HttpRequest();
            req.method = req_line[0].up();
            req.path = req_line[1];

            int i = 1;
            for (; i < lines.length; i++) {
                string l = lines[i];
                if (l == "") {
                    i++;
                    break;
                }
                int colon = l.index_of_char(':');
                if (colon > 0) {
                    string key = l.substring(0, colon).strip().down();
                    string val = l.substring(colon + 1).strip();
                    req.headers.set(key, val);
                }
            }

            if (i < lines.length) {
                var sb = new StringBuilder();
                for (; i < lines.length; i++) {
                    if (sb.len > 0) sb.append("\r\n");
                    sb.append(lines[i]);
                }
                req.body = sb.str;
            }

            return req;
        }
    }

    public class HttpResponse : Object {
        public int status_code { get; set; }
        public string content_type { get; set; }
        public string body { get; set; }

        public HttpResponse(int code = 200, string content_type = "application/json", string body = "") {
            this.status_code = code;
            this.content_type = content_type;
            this.body = body;
        }

        public string serialize() {
            var sb = new StringBuilder();
            string status_text = (this.status_code == 200) ? "OK" :
                                 (this.status_code == 201) ? "Created" :
                                 (this.status_code == 404) ? "Not Found" : "Bad Request";

            sb.append_printf("HTTP/1.1 %d %s\r\n", this.status_code, status_text);
            sb.append_printf("Content-Type: %s\r\n", this.content_type);
            sb.append_printf("Content-Length: %u\r\n", (uint) this.body.length);
            sb.append("Access-Control-Allow-Origin: *\r\n");
            sb.append("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n");
            sb.append("Access-Control-Allow-Headers: Content-Type, Authorization\r\n");
            sb.append("Connection: close\r\n\r\n");
            sb.append(this.body);

            return sb.str;
        }
    }

    public class HttpRouter : Object {
        private Gee.HashMap<string, Room> rooms;
        private SdpNegotiator sdp_negotiator;

        public HttpRouter(Gee.HashMap<string, Room> rooms) {
            this.rooms = rooms;
            this.sdp_negotiator = new SdpNegotiator();
        }

        public HttpResponse handle_request(HttpRequest req) {
            if (req.method == "OPTIONS") {
                return new HttpResponse(200, "text/plain", "");
            }

            if (req.path == "/health") {
                return new HttpResponse(200, "application/json", "{\"status\":\"healthy\",\"engine\":\"solas\"}");
            }

            if (req.path == "/metrics") {
                string metrics = MetricsExporter.export_prometheus_metrics(this.rooms.values);
                return new HttpResponse(200, "text/plain; version=0.0.4", metrics);
            }

            if (req.path == "/api/v1/rooms" && req.method == "GET") {
                var sb = new StringBuilder();
                sb.append("{\"rooms\":[");
                int idx = 0;
                foreach (var r in this.rooms.values) {
                    if (idx > 0) sb.append(",");
                    sb.append_printf("{\"id\":\"%s\",\"peers\":%d,\"dominant_speaker\":\"%s\"}",
                        r.room_id, r.peer_count, r.speaker_detector.dominant_speaker);
                    idx++;
                }
                sb.append("]}");
                return new HttpResponse(200, "application/json", sb.str);
            }

            /* Static console web assets */
            var web_asset = StaticWebAssets.resolve_asset(req.path);
            if (web_asset != null) {
                return web_asset;
            }

            return new HttpResponse(404, "application/json", "{\"error\":\"Not Found\"}");
        }
    }
}
