/*
 * Solas: Real-Time WebRTC Media Engine
 * WHIP Ingestion Endpoint Test Suite (RFC 9724)
 */

using Solas.Core;
using Solas.Protocol.Sdp;
using Solas.Network;

public class TestWhip : Object {

    private static string get_sample_sdp_offer() {
        var sb = new StringBuilder();
        sb.append("v=0\r\n");
        sb.append("o=- 123456 2 IN IP4 127.0.0.1\r\n");
        sb.append("s=Solas WHIP Ingest\r\n");
        sb.append("t=0 0\r\n");
        sb.append("m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n");
        sb.append("c=IN IP4 0.0.0.0\r\n");
        sb.append("a=rtpmap:111 opus/48000/2\r\n");
        sb.append("a=sendonly\r\n");
        sb.append("m=video 9 UDP/TLS/RTP/SAVPF 96\r\n");
        sb.append("c=IN IP4 0.0.0.0\r\n");
        sb.append("a=rtpmap:96 VP8/90000\r\n");
        sb.append("a=sendonly\r\n");
        return sb.str;
    }

    public static void test_whip_post_lifecycle() {
        var whip = new WhipEndpoint();
        string offer = get_sample_sdp_offer();

        bool created = false;
        string res_id_signal = "";
        whip.session_created.connect((res_id, room, peer) => {
            created = true;
            res_id_signal = res_id;
        });

        var resp = whip.handle_post("room-stage-1", offer);
        assert(resp.status_code == 201);
        assert(resp.content_type == "application/sdp");
        assert(resp.location != null && resp.location.has_prefix("/api/v1/whip/resource/"));
        assert(resp.body.contains("m=audio"));
        assert(resp.body.contains("m=video"));
        assert(created);
        assert(res_id_signal == "whip-res-00000001");

        /* Resource is retrievable */
        var session = whip.get_session(res_id_signal);
        assert(session != null);
        assert(session.is_active);
    }

    public static void test_whip_auth() {
        var whip = new WhipEndpoint("solas-broadcast-secret");
        string offer = get_sample_sdp_offer();

        /* Unauthenticated request rejected */
        var resp_no_auth = whip.handle_post("room-2", offer, null);
        assert(resp_no_auth.status_code == 401);

        var resp_bad_auth = whip.handle_post("room-2", offer, "Bearer wrong-token");
        assert(resp_bad_auth.status_code == 401);

        /* Authenticated request succeeds */
        var resp_good = whip.handle_post("room-2", offer, "Bearer solas-broadcast-secret");
        assert(resp_good.status_code == 201);
    }

    public static void test_whip_patch_and_delete() {
        var whip = new WhipEndpoint();
        string offer = get_sample_sdp_offer();

        var resp = whip.handle_post("room-3", offer);
        assert(resp.status_code == 201);
        string res_id = "whip-res-00000001";

        /* Trickle ICE PATCH */
        var patch_resp = whip.handle_patch(res_id, "candidate:1 1 UDP 2130706431 192.168.1.5 5000 typ host");
        assert(patch_resp.status_code == 204);

        /* Nonexistent resource PATCH fails */
        var patch_404 = whip.handle_patch("whip-res-missing", "candidate:...");
        assert(patch_404.status_code == 404);

        /* DELETE session */
        bool terminated = false;
        whip.session_terminated.connect((id) => {
            terminated = true;
        });

        var del_resp = whip.handle_delete(res_id);
        assert(del_resp.status_code == 200);
        assert(terminated);
        assert(whip.get_session(res_id) == null);

        /* Second DELETE returns 404 */
        var del_again = whip.handle_delete(res_id);
        assert(del_again.status_code == 404);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/whip/post_lifecycle", test_whip_post_lifecycle);
        Test.add_func("/whip/authentication", test_whip_auth);
        Test.add_func("/whip/patch_and_delete", test_whip_patch_and_delete);

        return Test.run();
    }
}
