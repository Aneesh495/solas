/*
 * Solas: Real-Time WebRTC Media Engine
 * Signaling, ICE Agent, and DTLS State Machine Verification Suite
 */

using Solas.Core;
using Solas.Crypto;
using Solas.Engine.Sfu;
using Solas.Protocol.Stun;
using Solas.Server;

public class TestSignaling : Object {

    public static void test_ice_agent() {
        var agent = new IceAgent(IceRole.CONTROLLED);
        assert(agent.state == IceConnectionState.NEW);
        assert(agent.local_ufrag.length == 8);
        assert(agent.local_pwd.length == 24);

        /* Gather host candidates */
        agent.gather_candidates("192.168.1.100", 5004);
        assert(agent.local_candidates.size == 1);

        var cand = agent.local_candidates.get(0);
        assert(cand.ip == "192.168.1.100");
        assert(cand.port == 5004);
        assert(cand.candidate_type == CandidateType.HOST);

        string sdp_attr = cand.to_sdp_attribute();
        assert(sdp_attr.contains("192.168.1.100 5004 typ host"));

        /* Add remote candidate */
        var r_cand = new IceCandidate("2", 1, "UDP", 2130706431, "10.0.0.5", 60000, CandidateType.HOST);
        agent.add_remote_candidate(r_cand);
        assert(agent.state == IceConnectionState.CHECKING);
        assert(agent.remote_candidates.size == 1);

        /* Process STUN binding request */
        var stun_req = StunMessage.create_binding_request();
        stun_req.add_attribute(new UsernameAttribute(agent.local_ufrag + ":remoteufrag"));

        var peer_addr = new InetSocketAddress(new InetAddress.from_string("127.0.0.1"), 54321);
        var stun_resp = agent.process_stun_request(stun_req, peer_addr);

        assert(stun_resp != null);
        assert(stun_resp.message_type == MessageType.BINDING_SUCCESS_RESPONSE);
        assert(agent.state == IceConnectionState.CONNECTED);
        assert(stun_resp.get_attribute<XorMappedAddressAttribute>() != null);
    }

    public static void test_dtls_transport() {
        var dtls = new DtlsTransport(DtlsRole.ACTPASS);
        assert(dtls.state == DtlsState.NEW);
        assert(dtls.local_fingerprint.length > 50);
        assert(dtls.local_fingerprint.contains(":"));

        /* Simulate handshake completion with 32-byte master secret */
        uint8[] secret = new uint8[32];
        for (int i = 0; i < 32; i++) secret[i] = (uint8) (i + 1);

        dtls.simulate_handshake_completion(secret);
        assert(dtls.state == DtlsState.CONNECTED);
        assert(dtls.client_write_key.length == 30);
        assert(dtls.server_write_key.length == 30);

        dtls.close();
        assert(dtls.state == DtlsState.CLOSED);
    }

    public static void test_signaling_session_jsonrpc() {
        var rooms = new Gee.HashMap<string, Room>();
        var session = new SignalingSession("sess-1", rooms);

        string? last_sent = null;
        session.send_callback = (msg) => {
            last_sent = msg;
        };

        /* 1. Test invalid JSON */
        session.process_message("{invalid_json");
        assert(last_sent != null && last_sent.contains("\"code\":-32700"));

        /* 2. Test unknown method */
        session.process_message("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"unknown_method\"}");
        assert(last_sent.contains("\"code\":-32601"));

        /* 3. Test join */
        session.process_message("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"join\",\"params\":{\"room\":\"conf-1\",\"peer\":\"alice\"}}");
        assert(last_sent.contains("\"status\":\"joined\""));
        assert(last_sent.contains("\"ice_ufrag\""));
        assert(rooms.has_key("conf-1"));
        assert(rooms.get("conf-1").peer_count == 1);

        /* 4. Test offer */
        string offer_sdp = "v=0\r\n" +
                           "o=- 12345 2 IN IP4 127.0.0.1\r\n" +
                           "s=SolasTest\r\n" +
                           "t=0 0\r\n" +
                           "a=ice-ufrag:clientufrag\r\n" +
                           "a=ice-pwd:clientpassword123456789012\r\n" +
                           "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
                           "a=rtpmap:111 opus/48000/2\r\n" +
                           "m=video 9 UDP/TLS/RTP/SAVPF 96\r\n" +
                           "a=rtpmap:96 VP8/90000\r\n";

        var builder = new Json.Builder();
        builder.begin_object();
        builder.set_member_name("jsonrpc");
        builder.add_string_value("2.0");
        builder.set_member_name("id");
        builder.add_int_value(3);
        builder.set_member_name("method");
        builder.add_string_value("offer");
        builder.set_member_name("params");
        builder.begin_object();
        builder.set_member_name("sdp");
        builder.add_string_value(offer_sdp);
        builder.end_object();
        builder.end_object();

        var gen = new Json.Generator();
        gen.set_root(builder.get_root());
        string offer_json = gen.to_data(null);

        session.process_message(offer_json);
        assert(last_sent.contains("\"type\":\"answer\""));
        assert(last_sent.contains("fingerprint"));
        assert(session.ice_agent.remote_ufrag == "clientufrag");

        /* 5. Test candidate */
        session.process_message("{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"candidate\",\"params\":{\"candidate\":\"candidate:1 1 UDP 2130706431 127.0.0.1 50000 typ host\"}}");
        assert(last_sent.contains("\"status\":\"candidate_added\""));
        assert(session.ice_agent.remote_candidates.size == 1);

        /* 6. Test leave */
        session.process_message("{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"leave\"}");
        assert(last_sent.contains("\"status\":\"left\""));
        assert(rooms.get("conf-1").peer_count == 0);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/signaling/ice_agent", test_ice_agent);
        Test.add_func("/signaling/dtls_transport", test_dtls_transport);
        Test.add_func("/signaling/session_jsonrpc", test_signaling_session_jsonrpc);

        return Test.run();
    }
}
