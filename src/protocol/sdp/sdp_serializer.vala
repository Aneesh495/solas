/*
 * Solas: Real-Time WebRTC Media Engine
 * SDP Text Serializer (RFC 4566 / RFC 8866)
 */

namespace Solas.Protocol.Sdp {

    public class SdpSerializer : Object {

        public static string serialize(SessionDescription session) {
            var sb = new StringBuilder();

            /* RFC 4566 Mandatory Header */
            sb.append_printf("v=%d\r\n", session.version);
            sb.append_printf("o=%s %s %s IN IP4 %s\r\n",
                session.origin_username, session.session_id, session.session_version, session.connection_address);
            sb.append_printf("s=%s\r\n", session.session_name);
            sb.append_printf("t=0 0\r\n");

            /* BUNDLE Group */
            if (!session.bundle_mids.is_empty) {
                sb.append("a=group:BUNDLE");
                foreach (string mid in session.bundle_mids) {
                    sb.append_printf(" %s", mid);
                }
                sb.append("\r\n");
            }

            sb.append("a=msid-semantic: WMS\r\n");

            /* Media Descriptions */
            foreach (var media in session.media_sections) {
                string m_type_str = (media.media_type == MediaType.AUDIO) ? "audio" : "video";
                sb.append_printf("m=%s %u %s", m_type_str, (uint) media.port, media.protocol);

                foreach (var codec in media.codecs) {
                    sb.append_printf(" %u", (uint) codec.payload_type);
                }
                sb.append("\r\n");

                sb.append_printf("c=IN IP4 %s\r\n", session.connection_address);

                if (media.mid != "") {
                    sb.append_printf("a=mid:%s\r\n", media.mid);
                }

                if (media.rtcp_mux) sb.append("a=rtcp-mux\r\n");
                if (media.rtcp_rsize) sb.append("a=rtcp-rsize\r\n");

                if (media.ice_ufrag != "") {
                    sb.append_printf("a=ice-ufrag:%s\r\n", media.ice_ufrag);
                    sb.append_printf("a=ice-pwd:%s\r\n", media.ice_pwd);
                }

                if (media.fingerprint_val != "") {
                    sb.append_printf("a=fingerprint:%s %s\r\n", media.fingerprint_hash, media.fingerprint_val);
                }

                string setup_str = "actpass";
                if (media.setup_role == SetupRole.ACTIVE) setup_str = "active";
                else if (media.setup_role == SetupRole.PASSIVE) setup_str = "passive";
                sb.append_printf("a=setup:%s\r\n", setup_str);

                string dir_str = "sendrecv";
                if (media.direction == MediaDirection.SEND_ONLY) dir_str = "sendonly";
                else if (media.direction == MediaDirection.RECV_ONLY) dir_str = "recvonly";
                else if (media.direction == MediaDirection.INACTIVE) dir_str = "inactive";
                sb.append_printf("a=%s\r\n", dir_str);

                /* Codec attributes */
                foreach (var codec in media.codecs) {
                    if (media.media_type == MediaType.AUDIO && codec.channels > 1) {
                        sb.append_printf("a=rtpmap:%u %s/%u/%d\r\n",
                            (uint) codec.payload_type, codec.codec_name, codec.clock_rate, codec.channels);
                    } else {
                        sb.append_printf("a=rtpmap:%u %s/%u\r\n",
                            (uint) codec.payload_type, codec.codec_name, codec.clock_rate);
                    }

                    if (codec.fmtp_parameters != "") {
                        sb.append_printf("a=fmtp:%u %s\r\n", (uint) codec.payload_type, codec.fmtp_parameters);
                    }

                    foreach (var fb in codec.rtcp_feedback) {
                        sb.append_printf("a=rtcp-fb:%u %s\r\n", (uint) codec.payload_type, fb);
                    }
                }

                /* SSRC attributes */
                foreach (var ssrc in media.ssrcs) {
                    if (ssrc.cname != "") {
                        sb.append_printf("a=ssrc:%u cname:%s\r\n", ssrc.ssrc, ssrc.cname);
                    }
                    if (ssrc.msid != "") {
                        sb.append_printf("a=ssrc:%u msid:%s\r\n", ssrc.ssrc, ssrc.msid);
                    }
                }
            }

            return sb.str;
        }
    }
}
