/*
 * Solas: Real-Time WebRTC Media Engine
 * Network and Protocol Demuxer Verification Suite
 */

using Solas.Core;
using Solas.Engine.Sfu;
using Solas.Network;

public class TestNetwork : Object {

    public static void test_protocol_demuxer() {
        /* 1. STUN packets (b0 <= 1) */
        uint8[] stun_packet = new uint8[] { 0x00, 0x01, 0x00, 0x00, 0x21, 0x12, 0xA4, 0x42 };
        assert(ProtocolDemuxer.classify(stun_packet) == DemuxProtocol.STUN);

        /* 2. DTLS packets (20 <= b0 <= 63) */
        uint8[] dtls_handshake = new uint8[] { 22, 0xFE, 0xFD, 0x00, 0x00 };
        assert(ProtocolDemuxer.classify(dtls_handshake) == DemuxProtocol.DTLS);

        uint8[] dtls_alert = new uint8[] { 21, 0xFE, 0xFD, 0x00, 0x02 };
        assert(ProtocolDemuxer.classify(dtls_alert) == DemuxProtocol.DTLS);

        /* 3. RTP packet: V=2 (128), PT=96 (VP8) */
        uint8[] rtp_packet = new uint8[] { 0x80, 96, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00 };
        assert(ProtocolDemuxer.classify(rtp_packet) == DemuxProtocol.RTP);

        /* 4. RTCP packet: V=2 (128), PT=200 (Sender Report) */
        uint8[] rtcp_sr = new uint8[] { 0x80, 200, 0x00, 0x06, 0x01, 0x02, 0x03, 0x04 };
        assert(ProtocolDemuxer.classify(rtcp_sr) == DemuxProtocol.RTCP);

        /* RTCP feedback: V=2 (128), PT=205 (Transport Layer Feedback) */
        uint8[] rtcp_twcc = new uint8[] { 0x8F, 205, 0x00, 0x03, 0x01, 0x02, 0x03, 0x04 };
        assert(ProtocolDemuxer.classify(rtcp_twcc) == DemuxProtocol.RTCP);

        /* 5. Unknown packet */
        uint8[] unknown_packet = new uint8[] { 10, 0x00, 0x00 };
        assert(ProtocolDemuxer.classify(unknown_packet) == DemuxProtocol.UNKNOWN);

        uint8[] empty_packet = new uint8[0];
        assert(ProtocolDemuxer.classify(empty_packet) == DemuxProtocol.UNKNOWN);
    }

    public static void test_websocket_accept_key() {
        /* RFC 6455 Section 1.3 Test Vector */
        string client_key = "dGhlIHNhbXBsZSBub25jZQ==";
        string expected_accept = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=";

        try {
            string accept_key = WebSocketFraming.compute_accept_key(client_key);
            assert(accept_key == expected_accept);
        } catch (GLib.Error e) {
            assert_not_reached();
        }
    }

    public static void test_websocket_encode_decode() {
        /* Frame encoding server to client */
        var original_frame = WebSocketFrame.text("ping-pong-solas");
        uint8[] encoded = WebSocketFraming.encode_frame(original_frame);

        assert(encoded.length > 0);
        /* FIN set + Opcode TEXT (1) => 0x81 */
        assert(encoded[0] == 0x81);
        /* Mask bit 0, length = 15 */
        assert(encoded[1] == 15);

        /* Masked client-to-server frame decoding */
        uint8[] masked_data = new uint8[] {
            0x81, 0x85,                 /* FIN + TEXT, Masked + Len 5 */
            0x37, 0xfa, 0x21, 0x3d,     /* Mask Key: 37 fa 21 3d */
            0x7f, 0x9f, 0x4d, 0x51, 0x58 /* Masked payload: "Hello" */
        };

        var decoded = WebSocketFraming.decode_frame(masked_data);
        assert(decoded != null);
        assert(decoded.opcode == WebSocketOpcode.TEXT);
        assert(decoded.fin == true);
        assert(decoded.get_text() == "Hello");
    }

    public static void test_http_parsing_and_routing() {
        string raw_request = "GET /health HTTP/1.1\r\n" +
                             "Host: localhost:8080\r\n" +
                             "User-Agent: SolasTest/1.0\r\n" +
                             "\r\n";

        var req = HttpRequest.parse(raw_request);
        assert(req != null);
        assert(req.method == "GET");
        assert(req.path == "/health");
        assert(req.headers.has_key("host"));
        assert(req.headers.get("host") == "localhost:8080");

        var rooms = new Gee.HashMap<string, Room>();
        var room1 = new Room("room-alpha");
        var peer1 = new Peer("peer-101", "room-alpha");
        room1.add_peer(peer1);
        rooms.set("room-alpha", room1);

        var router = new HttpRouter(rooms);

        /* Test /health */
        var resp_health = router.handle_request(req);
        assert(resp_health.status_code == 200);
        assert(resp_health.body.contains("healthy"));

        /* Test /metrics */
        var req_metrics = new HttpRequest();
        req_metrics.method = "GET";
        req_metrics.path = "/metrics";
        var resp_metrics = router.handle_request(req_metrics);
        assert(resp_metrics.status_code == 200);
        assert(resp_metrics.body.contains("solas_active_rooms 1"));
        assert(resp_metrics.body.contains("solas_active_peers 1"));

        /* Test /api/v1/rooms */
        var req_rooms = new HttpRequest();
        req_rooms.method = "GET";
        req_rooms.path = "/api/v1/rooms";
        var resp_rooms = router.handle_request(req_rooms);
        assert(resp_rooms.status_code == 200);
        assert(resp_rooms.body.contains("room-alpha"));

        /* Test 404 */
        var req_unknown = new HttpRequest();
        req_unknown.method = "GET";
        req_unknown.path = "/nonexistent";
        var resp_unknown = router.handle_request(req_unknown);
        assert(resp_unknown.status_code == 404);

        /* Test static console web assets */
        var req_index = new HttpRequest();
        req_index.method = "GET";
        req_index.path = "/";
        var resp_index = router.handle_request(req_index);
        assert(resp_index.status_code == 200);
        assert(resp_index.content_type.contains("text/html"));
        assert(resp_index.body.contains("Solas"));

        var req_css = new HttpRequest();
        req_css.method = "GET";
        req_css.path = "/style.css";
        var resp_css = router.handle_request(req_css);
        assert(resp_css.status_code == 200);
        assert(resp_css.content_type.contains("text/css"));

        var req_js = new HttpRequest();
        req_js.method = "GET";
        req_js.path = "/app.js";
        var resp_js = router.handle_request(req_js);
        assert(resp_js.status_code == 200);
        assert(resp_js.content_type.contains("javascript"));

        /* Serialize HTTP response */
        string serialized = resp_health.serialize();
        assert(serialized.has_prefix("HTTP/1.1 200 OK\r\n"));
        assert(serialized.contains("Content-Length:"));
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/network/demuxer", test_protocol_demuxer);
        Test.add_func("/network/websocket_accept", test_websocket_accept_key);
        Test.add_func("/network/websocket_encode_decode", test_websocket_encode_decode);
        Test.add_func("/network/http_routing", test_http_parsing_and_routing);

        return Test.run();
    }
}
