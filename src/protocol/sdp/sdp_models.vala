/*
 * Solas: Real-Time WebRTC Media Engine
 * SDP Data Models and Codec Capabilities
 */

namespace Solas.Protocol.Sdp {

    public class CodecCapability : Object {
        public uint8 payload_type { get; set; }
        public string codec_name { get; set; }
        public uint32 clock_rate { get; set; }
        public int channels { get; set; }
        public string fmtp_parameters { get; set; }
        public Gee.ArrayList<string> rtcp_feedback { get; private set; }

        public CodecCapability(uint8 pt, string name, uint32 clock_rate = 90000, int channels = 1) {
            this.payload_type = pt;
            this.codec_name = name;
            this.clock_rate = clock_rate;
            this.channels = channels;
            this.fmtp_parameters = "";
            this.rtcp_feedback = new Gee.ArrayList<string>();
        }

        public void add_feedback(string fb) {
            this.rtcp_feedback.add(fb);
        }

        public bool matches(CodecCapability other) {
            return this.codec_name.down() == other.codec_name.down() &&
                   this.clock_rate == other.clock_rate &&
                   this.channels == other.channels;
        }
    }

    public class SsrcInfo : Object {
        public uint32 ssrc { get; set; }
        public string cname { get; set; }
        public string msid { get; set; }

        public SsrcInfo(uint32 ssrc, string cname = "", string msid = "") {
            this.ssrc = ssrc;
            this.cname = cname;
            this.msid = msid;
        }
    }

    public class MediaDescription : Object {
        public MediaType media_type { get; set; }
        public uint16 port { get; set; }
        public string protocol { get; set; }
        public string mid { get; set; }
        public MediaDirection direction { get; set; }
        public string ice_ufrag { get; set; }
        public string ice_pwd { get; set; }
        public string fingerprint_hash { get; set; }
        public string fingerprint_val { get; set; }
        public SetupRole setup_role { get; set; }
        public bool rtcp_mux { get; set; }
        public bool rtcp_rsize { get; set; }

        public Gee.ArrayList<CodecCapability> codecs { get; private set; }
        public Gee.ArrayList<SsrcInfo> ssrcs { get; private set; }

        public MediaDescription(MediaType type = MediaType.VIDEO, uint16 port = 9) {
            this.media_type = type;
            this.port = port;
            this.protocol = "UDP/TLS/RTP/SAVPF";
            this.mid = "";
            this.direction = MediaDirection.SEND_RECV;
            this.ice_ufrag = "";
            this.ice_pwd = "";
            this.fingerprint_hash = "sha-256";
            this.fingerprint_val = "";
            this.setup_role = SetupRole.ACTPASS;
            this.rtcp_mux = true;
            this.rtcp_rsize = true;
            this.codecs = new Gee.ArrayList<CodecCapability>();
            this.ssrcs = new Gee.ArrayList<SsrcInfo>();
        }

        public void add_codec(CodecCapability codec) {
            this.codecs.add(codec);
        }

        public CodecCapability? find_codec_by_name(string name) {
            foreach (var c in this.codecs) {
                if (c.codec_name.down() == name.down()) {
                    return c;
                }
            }
            return null;
        }

        public CodecCapability? find_codec_by_pt(uint8 pt) {
            foreach (var c in this.codecs) {
                if (c.payload_type == pt) {
                    return c;
                }
            }
            return null;
        }
    }

    public class SessionDescription : Object {
        public int version { get; set; }
        public string origin_username { get; set; }
        public string session_id { get; set; }
        public string session_version { get; set; }
        public string session_name { get; set; }
        public string connection_address { get; set; }
        public string ice_ufrag { get; set; }
        public string ice_pwd { get; set; }
        public string fingerprint_hash { get; set; }
        public string fingerprint_val { get; set; }
        public Gee.ArrayList<string> bundle_mids { get; private set; }
        public Gee.ArrayList<MediaDescription> media_sections { get; private set; }

        public SessionDescription() {
            this.version = 0;
            this.origin_username = "-";
            this.session_id = "10001";
            this.session_version = "1";
            this.session_name = "Solas WebRTC Engine";
            this.connection_address = "0.0.0.0";
            this.ice_ufrag = "";
            this.ice_pwd = "";
            this.fingerprint_hash = "";
            this.fingerprint_val = "";
            this.bundle_mids = new Gee.ArrayList<string>();
            this.media_sections = new Gee.ArrayList<MediaDescription>();
        }

        public void add_media(MediaDescription media) {
            this.media_sections.add(media);
            if (media.mid != "") {
                this.bundle_mids.add(media.mid);
            }
        }

        public MediaDescription? get_media_by_mid(string mid) {
            foreach (var m in this.media_sections) {
                if (m.mid == mid) {
                    return m;
                }
            }
            return null;
        }
    }
}
