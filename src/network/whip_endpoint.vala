/*
 * Solas: Real-Time WebRTC Media Engine
 * WebRTC HTTP Ingestion Protocol (WHIP) Endpoint (RFC 9724)
 */

using Solas.Core;
using Solas.Protocol.Sdp;

namespace Solas.Network {

    public class WhipSession : Object {
        public string resource_id { get; construct; }
        public string room_id { get; construct; }
        public string peer_id { get; construct; }
        public string? bearer_token { get; construct; }
        public string sdp_offer { get; set; }
        public string sdp_answer { get; set; }
        public bool is_active { get; set; default = true; }
        public int64 created_at_ms { get; construct; }

        public WhipSession(string res_id, string room_id, string peer_id, string? token = null) {
            GLib.Object(resource_id: res_id, room_id: room_id, peer_id: peer_id, bearer_token: token,
                        created_at_ms: Clock.get_monotonic_time_ms());
        }
    }

    public class WhipResponse : Object {
        public int status_code { get; set; }
        public string content_type { get; set; }
        public string? location { get; set; }
        public string? etag { get; set; }
        public string body { get; set; }

        public WhipResponse(int code, string ctype, string body, string? loc = null, string? etag = null) {
            this.status_code = code;
            this.content_type = ctype;
            this.body = body;
            this.location = loc;
            this.etag = etag;
        }
    }

    public class WhipEndpoint : Object {
        private Gee.HashMap<string, WhipSession> sessions;
        private string? required_token;
        private uint32 next_session_id;

        public signal void session_created(string resource_id, string room_id, string peer_id);
        public signal void session_terminated(string resource_id);

        public WhipEndpoint(string? auth_token = null) {
            this.sessions = new Gee.HashMap<string, WhipSession>();
            this.required_token = auth_token;
            this.next_session_id = 1;
        }

        /**
         * Handles HTTP POST ingest request with client SDP offer.
         */
        public WhipResponse handle_post(string room_id, string sdp_offer, string? auth_header = null) {
            /* Verify bearer token authentication */
            if (this.required_token != null) {
                if (auth_header == null || !auth_header.has_prefix("Bearer ") ||
                    auth_header.substring(7) != this.required_token) {
                    return new WhipResponse(401, "text/plain", "Unauthorized: invalid WHIP bearer token\n");
                }
            }

            if (sdp_offer.length == 0) {
                return new WhipResponse(400, "text/plain", "Bad Request: empty SDP offer\n");
            }

            string res_id = "whip-res-%08x".printf(this.next_session_id++);
            string peer_id = "whip-peer-%s".printf(res_id);

            var session = new WhipSession(res_id, room_id, peer_id, this.required_token);
            session.sdp_offer = sdp_offer;

            /* Parse client offer and construct synthetic answer */
            try {
                var offer_desc = SdpParser.parse(sdp_offer);
                var negotiator = new SdpNegotiator();
                var answer_desc = negotiator.negotiate_answer(offer_desc, "solas-whip-ufrag", "solas-whip-pwd",
                                                             "11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44");
                session.sdp_answer = SdpSerializer.serialize(answer_desc);
            } catch (SdpError e) {
                return new WhipResponse(400, "text/plain", "Bad Request: malformed SDP: %s\n".printf(e.message));
            }

            this.sessions.set(res_id, session);
            this.session_created(res_id, room_id, peer_id);

            string location = "/api/v1/whip/resource/%s".printf(res_id);
            string etag = "\"%s\"".printf(res_id);

            return new WhipResponse(201, "application/sdp", session.sdp_answer, location, etag);
        }

        /**
         * Handles HTTP PATCH with trickle ICE candidates.
         */
        public WhipResponse handle_patch(string resource_id, string sdp_frag) {
            var session = this.sessions.get(resource_id);
            if (session == null || !session.is_active) {
                return new WhipResponse(404, "text/plain", "Not Found: WHIP resource does not exist\n");
            }

            /* Trickle ICE candidate received */
            return new WhipResponse(204, "text/plain", "");
        }

        /**
         * Handles HTTP DELETE to tear down session.
         */
        public WhipResponse handle_delete(string resource_id) {
            var session = this.sessions.get(resource_id);
            if (session == null) {
                return new WhipResponse(404, "text/plain", "Not Found: WHIP resource does not exist\n");
            }

            session.is_active = false;
            this.sessions.unset(resource_id);
            this.session_terminated(resource_id);

            return new WhipResponse(200, "text/plain", "Session terminated\n");
        }

        public WhipSession? get_session(string resource_id) {
            return this.sessions.get(resource_id);
        }
    }
}
