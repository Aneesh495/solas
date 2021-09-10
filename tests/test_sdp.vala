/*
 * Unit tests for Solas.Protocol.Sdp
 */
using Solas.Core;
using Solas.Protocol.Sdp;

void test_sdp_parser_and_serializer() {
    string sample_offer = """v=0
o=- 418291829 2 IN IP4 127.0.0.1
s=Test Session
t=0 0
a=group:BUNDLE 0 1
m=audio 9 UDP/TLS/RTP/SAVPF 111
c=IN IP4 0.0.0.0
a=mid:0
a=sendrecv
a=rtcp-mux
a=ice-ufrag:client_ufrag
a=ice-pwd:client_pwd_12345678
a=fingerprint:sha-256 AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99
a=setup:actpass
a=rtpmap:111 opus/48000/2
a=fmtp:111 minptime=10;useinbandfec=1
a=rtcp-fb:111 transport-cc
m=video 9 UDP/TLS/RTP/SAVPF 96 98
c=IN IP4 0.0.0.0
a=mid:1
a=sendrecv
a=rtcp-mux
a=ice-ufrag:client_ufrag
a=ice-pwd:client_pwd_12345678
a=fingerprint:sha-256 AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99
a=setup:actpass
a=rtpmap:96 VP8/90000
a=rtcp-fb:96 nack
a=rtcp-fb:96 nack pli
a=rtpmap:98 H264/90000
a=fmtp:98 packetization-mode=1;profile-level-id=42e01f
a=ssrc:10001 cname:publisher_cname
""";

    try {
        var offer = SdpParser.parse(sample_offer);
        assert(offer.version == 0);
        assert(offer.media_sections.size == 2);
        assert(offer.bundle_mids.size == 2);
        assert(offer.bundle_mids.get(0) == "0");
        assert(offer.bundle_mids.get(1) == "1");

        var audio = offer.media_sections.get(0);
        assert(audio.media_type == MediaType.AUDIO);
        assert(audio.mid == "0");
        assert(audio.codecs.size == 1);
        assert(audio.codecs.get(0).codec_name == "opus");
        assert(audio.codecs.get(0).clock_rate == 48000);
        assert(audio.codecs.get(0).channels == 2);

        var video = offer.media_sections.get(1);
        assert(video.media_type == MediaType.VIDEO);
        assert(video.mid == "1");
        assert(video.codecs.size == 2);
        assert(video.codecs.get(0).codec_name == "VP8");
        assert(video.codecs.get(1).codec_name == "H264");
        assert(video.ssrcs.size == 1);
        assert(video.ssrcs.get(0).ssrc == 10001);

        /* Test Negotiation */
        var negotiator = new SdpNegotiator();
        var answer = negotiator.negotiate_answer(offer, "server_ufrag", "server_pwd", "FF:EE:DD:CC:BB:AA");
        assert(answer.media_sections.size == 2);

        var ans_audio = answer.media_sections.get(0);
        assert(ans_audio.ice_ufrag == "server_ufrag");
        assert(ans_audio.setup_role == SetupRole.PASSIVE);
        assert(ans_audio.direction == MediaDirection.SEND_RECV);
        assert(ans_audio.codecs.size == 1);
        assert(ans_audio.codecs.get(0).payload_type == 111);

        var ans_video = answer.media_sections.get(1);
        assert(ans_video.codecs.size == 2);

        string serialized_answer = SdpSerializer.serialize(answer);
        assert(serialized_answer.contains("m=audio 9 UDP/TLS/RTP/SAVPF 111"));
        assert(serialized_answer.contains("m=video 9 UDP/TLS/RTP/SAVPF 96 98"));
        assert(serialized_answer.contains("a=setup:passive"));
        assert(serialized_answer.contains("a=ice-ufrag:server_ufrag"));
    } catch (GLib.Error e) {
        assert_not_reached();
    }
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/sdp/parser_and_serializer", test_sdp_parser_and_serializer);
    Test.run();
}
