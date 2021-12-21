/*
 * Solas: Real-Time WebRTC Media Engine
 * WHEP Egress Endpoint Test Suite
 */

using Solas.Core;
using Solas.Protocol.Sdp;
using Solas.Network;

public class TestWhep : Object {

    private static string get_sample_recvonly_offer() {
        var sb = new StringBuilder();
        sb.append("v=0\r\n");
        sb.append("o=- 998877 2 IN IP4 127.0.0.1\r\n");
        sb.append("s=Solas WHEP Egress Player\r\n");
        sb.append("t=0 0\r\n");
        sb.append("m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n");
        sb.append("c=IN IP4 0.0.0.0\r\n");
        sb.append("a=rtpmap:111 opus/48000/2\r\n");
        sb.append("a=recvonly\r\n");
        sb.append("m=video 9 UDP/TLS/RTP/SAVPF 96\r\n");
        sb.append("c=IN IP4 0.0.0.0\r\n");
        sb.append("a=rtpmap:96 VP8/90000\r\n");
        sb.append("a=recvonly\r\n");
        return sb.str;
    }

    public static void test_whep_post_lifecycle() {
        var whep = new WhepEndpoint();
        string offer = get_sample_recvonly_offer();

        bool joined = false;
        string res_id_signal = "";
        whep.subscriber_joined.connect((res_id, channel, peer) => {
            joined = true;
            res_id_signal = res_id;
        });

        var resp = whep.handle_post("ch-main", offer);
        assert(resp.status_code == 201);
        assert(resp.content_type == "application/sdp");
        assert(resp.location != null && resp.location.has_prefix("/api/v1/whep/resource/"));
        assert(resp.body.contains("a=sendonly"));
        assert(joined);
        assert(res_id_signal == "whep-sub-00000001");

        var session = whep.get_session(res_id_signal);
        assert(session != null);
        assert(session.is_active);
    }

    public static void test_whep_auth() {
        var whep = new WhepEndpoint("premium-subscriber-key");
        string offer = get_sample_recvonly_offer();

        /* Unauthenticated request rejected */
        var resp_no_auth = whep.handle_post("ch-vip", offer, null);
        assert(resp_no_auth.status_code == 401);

        var resp_bad_auth = whep.handle_post("ch-vip", offer, "Bearer bad-key");
        assert(resp_bad_auth.status_code == 401);

        /* Authenticated request succeeds */
        var resp_good = whep.handle_post("ch-vip", offer, "Bearer premium-subscriber-key");
        assert(resp_good.status_code == 201);
    }

    public static void test_whep_patch_and_delete() {
        var whep = new WhepEndpoint();
        string offer = get_sample_recvonly_offer();

        var resp = whep.handle_post("ch-events", offer);
        assert(resp.status_code == 201);
        string res_id = "whep-sub-00000001";

        /* Trickle ICE PATCH */
        var patch_resp = whep.handle_patch(res_id, "candidate:2 1 UDP 2130706431 10.0.0.1 5000 typ host");
        assert(patch_resp.status_code == 204);

        /* Nonexistent resource PATCH fails */
        var patch_404 = whep.handle_patch("whep-sub-missing", "candidate:...");
        assert(patch_404.status_code == 404);

        /* DELETE session */
        bool left = false;
        whep.subscriber_left.connect((id) => {
            left = true;
        });

        var del_resp = whep.handle_delete(res_id);
        assert(del_resp.status_code == 200);
        assert(left);
        assert(whep.get_session(res_id) == null);

        /* Second DELETE returns 404 */
        var del_again = whep.handle_delete(res_id);
        assert(del_again.status_code == 404);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/whep/post_lifecycle", test_whep_post_lifecycle);
        Test.add_func("/whep/authentication", test_whep_auth);
        Test.add_func("/whep/patch_and_delete", test_whep_patch_and_delete);

        return Test.run();
    }
}
