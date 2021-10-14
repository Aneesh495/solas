/*
 * Solas: Real-Time WebRTC Media Engine
 * JSON-RPC 2.0 WebRTC Signaling Session Engine
 */

using Solas.Core;
using Solas.Engine.Sfu;
using Solas.Protocol.Sdp;
using Solas.Network;

namespace Solas.Server {

    public delegate void WebSocketSendCallback(string text_msg);

    public class SignalingSession : Object {
        public string session_id { get; private set; }
        public string? room_id { get; private set; }
        public string? peer_id { get; private set; }

        public IceAgent ice_agent { get; private set; }
        public DtlsTransport dtls_transport { get; private set; }
        public SdpNegotiator negotiator { get; private set; }

        private Gee.HashMap<string, Room> rooms;
        public WebSocketSendCallback? send_callback;

        public SignalingSession(string session_id, Gee.HashMap<string, Room> rooms) {
            this.session_id = session_id;
            this.rooms = rooms;
            this.room_id = null;
            this.peer_id = null;
            this.ice_agent = new IceAgent(IceRole.CONTROLLED);
            this.dtls_transport = new DtlsTransport(DtlsRole.PASSIVE);
            this.negotiator = new SdpNegotiator();
        }

        /**
         * Dispatches an incoming JSON-RPC 2.0 signaling request.
         */
        public void process_message(string json_str) {
            var parser = new Json.Parser();
            try {
                parser.load_from_data(json_str);
                var root = parser.get_root().get_object();

                int64 id = 0;
                if (root.has_member("id")) {
                    id = root.get_int_member("id");
                }

                if (!root.has_member("method")) {
                    this.send_error(id, -32600, "Invalid Request: missing method");
                    return;
                }

                string method = root.get_string_member("method");
                Json.Object? params_obj = root.has_member("params") ? root.get_object_member("params") : null;

                switch (method) {
                    case "join":
                        this.handle_join(id, params_obj);
                        break;
                    case "offer":
                        this.handle_offer(id, params_obj);
                        break;
                    case "candidate":
                        this.handle_candidate(id, params_obj);
                        break;
                    case "leave":
                        this.handle_leave(id);
                        break;
                    default:
                        this.send_error(id, -32601, "Method not found: " + method);
                        break;
                }
            } catch (GLib.Error e) {
                this.send_error(0, -32700, "Parse error: " + e.message);
            }
        }

        private void handle_join(int64 id, Json.Object? params_obj) {
            if (params_obj == null || !params_obj.has_member("room") || !params_obj.has_member("peer")) {
                this.send_error(id, -32602, "Invalid params: requires 'room' and 'peer'");
                return;
            }

            this.room_id = params_obj.get_string_member("room");
            this.peer_id = params_obj.get_string_member("peer");

            Room room;
            if (!this.rooms.has_key(this.room_id)) {
                room = new Room(this.room_id);
                this.rooms.set(this.room_id, room);
            } else {
                room = this.rooms.get(this.room_id);
            }

            var peer = new Peer(this.peer_id, this.room_id);
            room.add_peer(peer);

            /* Send success response with local ICE ufrag */
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("jsonrpc");
            builder.add_string_value("2.0");
            builder.set_member_name("id");
            builder.add_int_value(id);
            builder.set_member_name("result");
            builder.begin_object();
            builder.set_member_name("status");
            builder.add_string_value("joined");
            builder.set_member_name("room");
            builder.add_string_value(this.room_id);
            builder.set_member_name("peer");
            builder.add_string_value(this.peer_id);
            builder.set_member_name("ice_ufrag");
            builder.add_string_value(this.ice_agent.local_ufrag);
            builder.end_object();
            builder.end_object();

            this.send_json(builder);
        }

        private void handle_offer(int64 id, Json.Object? params_obj) {
            if (params_obj == null || !params_obj.has_member("sdp")) {
                this.send_error(id, -32602, "Invalid params: requires 'sdp'");
                return;
            }

            string offer_sdp = params_obj.get_string_member("sdp");
            try {
                var offer = SdpParser.parse(offer_sdp);

                /* Extract remote ICE credentials */
                string r_ufrag = offer.ice_ufrag;
                string r_pwd = offer.ice_pwd;
                foreach (var m in offer.media_sections) {
                    if (m.ice_ufrag.length > 0) r_ufrag = m.ice_ufrag;
                    if (m.ice_pwd.length > 0) r_pwd = m.ice_pwd;
                }
                if (r_ufrag.length > 0) this.ice_agent.remote_ufrag = r_ufrag;
                if (r_pwd.length > 0) this.ice_agent.remote_pwd = r_pwd;

                /* Negotiate answer SDP */
                var answer = this.negotiator.negotiate_answer(
                    offer,
                    this.ice_agent.local_ufrag,
                    this.ice_agent.local_pwd,
                    this.dtls_transport.local_fingerprint
                );

                string answer_sdp = SdpSerializer.serialize(answer);

                var builder = new Json.Builder();
                builder.begin_object();
                builder.set_member_name("jsonrpc");
                builder.add_string_value("2.0");
                builder.set_member_name("id");
                builder.add_int_value(id);
                builder.set_member_name("result");
                builder.begin_object();
                builder.set_member_name("type");
                builder.add_string_value("answer");
                builder.set_member_name("sdp");
                builder.add_string_value(answer_sdp);
                builder.end_object();
                builder.end_object();

                this.send_json(builder);
            } catch (GLib.Error e) {
                this.send_error(id, -32000, "SDP negotiation failed: " + e.message);
            }
        }

        private void handle_candidate(int64 id, Json.Object? params_obj) {
            if (params_obj == null || !params_obj.has_member("candidate")) {
                this.send_error(id, -32602, "Invalid params: requires 'candidate'");
                return;
            }

            string cand_str = params_obj.get_string_member("candidate");
            /* Parse candidate: "candidate:1 1 UDP 2130706431 127.0.0.1 54321 typ host" */
            string[] tokens = cand_str.split(" ");
            if (tokens.length >= 8) {
                string foundation = tokens[0].replace("candidate:", "");
                uint32 component = (uint32) int.parse(tokens[1]);
                string transport = tokens[2];
                uint32 prio = (uint32) int64.parse(tokens[3]);
                string ip = tokens[4];
                uint16 port = (uint16) int.parse(tokens[5]);
                var cand = new IceCandidate(foundation, component, transport, prio, ip, port, CandidateType.HOST);
                this.ice_agent.add_remote_candidate(cand);
            }

            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("jsonrpc");
            builder.add_string_value("2.0");
            builder.set_member_name("id");
            builder.add_int_value(id);
            builder.set_member_name("result");
            builder.begin_object();
            builder.set_member_name("status");
            builder.add_string_value("candidate_added");
            builder.end_object();
            builder.end_object();

            this.send_json(builder);
        }

        private void handle_leave(int64 id) {
            if (this.room_id != null && this.peer_id != null && this.rooms.has_key(this.room_id)) {
                var room = this.rooms.get(this.room_id);
                room.remove_peer(this.peer_id);
            }

            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("jsonrpc");
            builder.add_string_value("2.0");
            builder.set_member_name("id");
            builder.add_int_value(id);
            builder.set_member_name("result");
            builder.begin_object();
            builder.set_member_name("status");
            builder.add_string_value("left");
            builder.end_object();
            builder.end_object();

            this.send_json(builder);
        }

        private void send_error(int64 id, int code, string message) {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("jsonrpc");
            builder.add_string_value("2.0");
            builder.set_member_name("id");
            builder.add_int_value(id);
            builder.set_member_name("error");
            builder.begin_object();
            builder.set_member_name("code");
            builder.add_int_value(code);
            builder.set_member_name("message");
            builder.add_string_value(message);
            builder.end_object();
            builder.end_object();

            this.send_json(builder);
        }

        private void send_json(Json.Builder builder) {
            var gen = new Json.Generator();
            gen.set_root(builder.get_root());
            string json_text = gen.to_data(null);
            if (this.send_callback != null) {
                this.send_callback(json_text);
            }
        }
    }
}
