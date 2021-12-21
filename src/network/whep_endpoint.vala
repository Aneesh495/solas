/*
 * Solas: Real-Time WebRTC Media Engine
 * WebRTC HTTP Egress Protocol (WHEP) Endpoint
 */

using Solas.Core;
using Solas.Protocol.Sdp;

namespace Solas.Network {

    public class WhepSession : Object {
        public string resource_id { get; construct; }
        public string channel_id { get; construct; }
        public string peer_id { get; construct; }
        public string? auth_token { get; construct; }
        public string sdp_offer { get; set; }
        public string sdp_answer { get; set; }
        public bool is_active { get; set; default = true; }
        public int64 created_at_ms { get; construct; }

        public WhepSession(string res_id, string channel, string peer_id, string? token = null) {
            GLib.Object(resource_id: res_id, channel_id: channel, peer_id: peer_id, auth_token: token,
                        created_at_ms: Clock.get_monotonic_time_ms());
        }
    }

    public class WhepResponse : Object {
        public int status_code { get; set; }
        public string content_type { get; set; }
        public string? location { get; set; }
        public string? etag { get; set; }
        public string body { get; set; }

        public WhepResponse(int code, string ctype, string body, string? loc = null, string? etag = null) {
            this.status_code = code;
            this.content_type = ctype;
            this.body = body;
            this.location = loc;
            this.etag = etag;
        }
    }

    public class WhepEndpoint : Object {
        private Gee.HashMap<string, WhepSession> sessions;
        private string? required_token;
        private uint32 next_session_id;

        public signal void subscriber_joined(string resource_id, string channel_id, string peer_id);
        public signal void subscriber_left(string resource_id);

        public WhepEndpoint(string? auth_token = null) {
            this.sessions = new Gee.HashMap<string, WhepSession>();
            this.required_token = auth_token;
            this.next_session_id = 1;
        }

        /**
         * Handles HTTP POST egress request with client SDP offer (recvonly).
         */
        public WhepResponse handle_post(string channel_id, string sdp_offer, string? auth_header = null) {
            /* Check authentication if configured */
            if (this.required_token != null) {
                if (auth_header == null || !auth_header.has_prefix("Bearer ") ||
                    auth_header.substring(7) != this.required_token) {
                    return new WhepResponse(401, "text/plain", "Unauthorized: invalid WHEP bearer token\n");
                }
            }

            if (sdp_offer.length == 0) {
                return new WhepResponse(400, "text/plain", "Bad Request: empty SDP offer\n");
            }

            string res_id = "whep-sub-%08x".printf(this.next_session_id++);
            string peer_id = "whep-peer-%s".printf(res_id);

            var session = new WhepSession(res_id, channel_id, peer_id, this.required_token);
            session.sdp_offer = sdp_offer;

            try {
                var offer_desc = SdpParser.parse(sdp_offer);
                var negotiator = new SdpNegotiator();
                var answer_desc = negotiator.negotiate_answer(offer_desc, "solas-whep-ufrag", "solas-whep-pwd",
                                                             "22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55");
                session.sdp_answer = SdpSerializer.serialize(answer_desc);
            } catch (SdpError e) {
                return new WhepResponse(400, "text/plain", "Bad Request: malformed SDP: %s\n".printf(e.message));
            }

            this.sessions.set(res_id, session);
            this.subscriber_joined(res_id, channel_id, peer_id);

            string location = "/api/v1/whep/resource/%s".printf(res_id);
            string etag = "\"%s\"".printf(res_id);

            return new WhepResponse(201, "application/sdp", session.sdp_answer, location, etag);
        }

        /**
         * Handles HTTP PATCH with trickle ICE candidates.
         */
        public WhepResponse handle_patch(string resource_id, string sdp_frag) {
            var session = this.sessions.get(resource_id);
            if (session == null || !session.is_active) {
                return new WhepResponse(404, "text/plain", "Not Found: WHEP resource does not exist\n");
            }

            return new WhepResponse(204, "text/plain", "");
        }

        /**
         * Handles HTTP DELETE to disconnect subscriber.
         */
        public WhepResponse handle_delete(string resource_id) {
            var session = this.sessions.get(resource_id);
            if (session == null) {
                return new WhepResponse(404, "text/plain", "Not Found: WHEP resource does not exist\n");
            }

            session.is_active = false;
            this.sessions.unset(resource_id);
            this.subscriber_left(resource_id);

            return new WhepResponse(200, "text/plain", "Subscriber disconnected\n");
        }

        public WhepSession? get_session(string resource_id) {
            return this.sessions.get(resource_id);
        }
    }
}
