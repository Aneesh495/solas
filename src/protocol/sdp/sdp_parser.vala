/*
 * Solas: Real-Time WebRTC Media Engine
 * SDP Text Parser (RFC 4566 / RFC 8866)
 */

namespace Solas.Protocol.Sdp {

    public class SdpParser : Object {

        public static SessionDescription parse(string sdp_text) throws SdpError {
            var session = new SessionDescription();
            string[] lines = sdp_text.split("\n");
            MediaDescription? current_media = null;

            foreach (string raw_line in lines) {
                string line = raw_line.strip();
                if (line.length < 2 || line[1] != '=') {
                    continue;
                }

                char type = line[0];
                string val = line.substring(2);

                switch (type) {
                    case 'v':
                        session.version = int.parse(val);
                        break;

                    case 'o':
                        string[] o_parts = val.split(" ");
                        if (o_parts.length >= 6) {
                            session.origin_username = o_parts[0];
                            session.session_id = o_parts[1];
                            session.session_version = o_parts[2];
                        }
                        break;

                    case 's':
                        session.session_name = val;
                        break;

                    case 'c':
                        string[] c_parts = val.split(" ");
                        if (c_parts.length >= 3) {
                            session.connection_address = c_parts[2];
                        }
                        break;

                    case 'm':
                        string[] m_parts = val.split(" ");
                        if (m_parts.length >= 4) {
                            MediaType mtype = MediaType.UNKNOWN;
                            if (m_parts[0] == "audio") mtype = MediaType.AUDIO;
                            else if (m_parts[0] == "video") mtype = MediaType.VIDEO;
                            else if (m_parts[0] == "application") mtype = MediaType.APPLICATION;

                            uint16 port = (uint16) int.parse(m_parts[1]);
                            string proto = m_parts[2];

                            current_media = new MediaDescription(mtype, port);
                            current_media.protocol = proto;

                            for (int i = 3; i < m_parts.length; i++) {
                                uint8 pt = (uint8) int.parse(m_parts[i]);
                                current_media.add_codec(new CodecCapability(pt, "unknown_%u".printf(pt)));
                            }

                            session.add_media(current_media);
                        }
                        break;

                    case 'a':
                        parse_attribute(val, session, current_media);
                        break;

                    default:
                        break;
                }
            }

            return session;
        }

        private static void parse_attribute(string attr, SessionDescription session, MediaDescription? current_media) {
            if (attr.has_prefix("group:BUNDLE ")) {
                string[] mids = attr.substring(13).split(" ");
                foreach (string m in mids) {
                    if (m.strip() != "") {
                        session.bundle_mids.add(m.strip());
                    }
                }
                return;
            }

            if (attr.has_prefix("ice-ufrag:")) {
                string ufrag = attr.substring(10).strip();
                if (current_media != null) {
                    current_media.ice_ufrag = ufrag;
                } else {
                    session.ice_ufrag = ufrag;
                }
                return;
            } else if (attr.has_prefix("ice-pwd:")) {
                string pwd = attr.substring(8).strip();
                if (current_media != null) {
                    current_media.ice_pwd = pwd;
                } else {
                    session.ice_pwd = pwd;
                }
                return;
            } else if (attr.has_prefix("fingerprint:")) {
                string[] fp_parts = attr.substring(12).split(" ");
                if (fp_parts.length >= 2) {
                    if (current_media != null) {
                        current_media.fingerprint_hash = fp_parts[0];
                        current_media.fingerprint_val = fp_parts[1];
                    } else {
                        session.fingerprint_hash = fp_parts[0];
                        session.fingerprint_val = fp_parts[1];
                    }
                }
                return;
            }

            if (current_media == null) return;

            if (attr.has_prefix("mid:")) {
                current_media.mid = attr.substring(4).strip();
            } else if (attr == "sendrecv") {
                current_media.direction = MediaDirection.SEND_RECV;
            } else if (attr == "sendonly") {
                current_media.direction = MediaDirection.SEND_ONLY;
            } else if (attr == "recvonly") {
                current_media.direction = MediaDirection.RECV_ONLY;
            } else if (attr == "inactive") {
                current_media.direction = MediaDirection.INACTIVE;
            } else if (attr == "rtcp-mux") {
                current_media.rtcp_mux = true;
            } else if (attr == "rtcp-rsize") {
                current_media.rtcp_rsize = true;
            } else if (attr.has_prefix("ice-ufrag:")) {
                current_media.ice_ufrag = attr.substring(10).strip();
            } else if (attr.has_prefix("ice-pwd:")) {
                current_media.ice_pwd = attr.substring(8).strip();
            } else if (attr.has_prefix("fingerprint:")) {
                string[] fp_parts = attr.substring(12).split(" ");
                if (fp_parts.length >= 2) {
                    current_media.fingerprint_hash = fp_parts[0];
                    current_media.fingerprint_val = fp_parts[1];
                }
            } else if (attr.has_prefix("setup:")) {
                string role = attr.substring(6).strip();
                if (role == "actpass") current_media.setup_role = SetupRole.ACTPASS;
                else if (role == "active") current_media.setup_role = SetupRole.ACTIVE;
                else if (role == "passive") current_media.setup_role = SetupRole.PASSIVE;
            } else if (attr.has_prefix("rtpmap:")) {
                /* a=rtpmap:111 opus/48000/2 */
                string[] parts = attr.substring(7).split(" ");
                if (parts.length >= 2) {
                    uint8 pt = (uint8) int.parse(parts[0]);
                    string[] rtp_info = parts[1].split("/");
                    string name = rtp_info[0];
                    uint32 rate = (rtp_info.length >= 2) ? (uint32) int.parse(rtp_info[1]) : 90000;
                    int ch = (rtp_info.length >= 3) ? int.parse(rtp_info[2]) : 1;

                    var codec = current_media.find_codec_by_pt(pt);
                    if (codec != null) {
                        codec.codec_name = name;
                        codec.clock_rate = rate;
                        codec.channels = ch;
                    } else {
                        var new_codec = new CodecCapability(pt, name, rate, ch);
                        current_media.add_codec(new_codec);
                    }
                }
            } else if (attr.has_prefix("fmtp:")) {
                /* a=fmtp:111 minptime=10;useinbandfec=1 */
                int first_space = attr.index_of_char(' ');
                if (first_space > 5) {
                    uint8 pt = (uint8) int.parse(attr.substring(5, first_space - 5));
                    string params = attr.substring(first_space + 1);
                    var codec = current_media.find_codec_by_pt(pt);
                    if (codec != null) {
                        codec.fmtp_parameters = params;
                    }
                }
            } else if (attr.has_prefix("rtcp-fb:")) {
                /* a=rtcp-fb:96 nack pli */
                int first_space = attr.index_of_char(' ');
                if (first_space > 8) {
                    uint8 pt = (uint8) int.parse(attr.substring(8, first_space - 8));
                    string fb = attr.substring(first_space + 1);
                    var codec = current_media.find_codec_by_pt(pt);
                    if (codec != null) {
                        codec.add_feedback(fb);
                    }
                }
            } else if (attr.has_prefix("ssrc:")) {
                /* a=ssrc:123456 cname:user@domain */
                string[] parts = attr.substring(5).split(" ");
                if (parts.length >= 2) {
                    uint32 ssrc = (uint32) int64.parse(parts[0]);
                    string cname = "";
                    string msid = "";
                    for (int i = 1; i < parts.length; i++) {
                        if (parts[i].has_prefix("cname:")) cname = parts[i].substring(6);
                        else if (parts[i].has_prefix("msid:")) msid = parts[i].substring(5);
                    }
                    current_media.ssrcs.add(new SsrcInfo(ssrc, cname, msid));
                }
            }
        }
    }
}
