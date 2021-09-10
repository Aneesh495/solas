/*
 * Solas: Real-Time WebRTC Media Engine
 * SDP Offer / Answer Negotiation State Machine
 */

namespace Solas.Protocol.Sdp {

    public class SdpNegotiator : Object {
        private SessionDescription server_capabilities;

        public SdpNegotiator(SessionDescription? capabilities = null) {
            if (capabilities != null) {
                this.server_capabilities = capabilities;
            } else {
                this.server_capabilities = create_default_capabilities();
            }
        }

        public static SessionDescription create_default_capabilities() {
            var sdp = new SessionDescription();

            /* Audio section: Opus */
            var audio = new MediaDescription(MediaType.AUDIO, 9);
            audio.mid = "audio";
            var opus = new CodecCapability(111, "opus", 48000, 2);
            opus.fmtp_parameters = "minptime=10;useinbandfec=1";
            opus.add_feedback("transport-cc");
            audio.add_codec(opus);
            sdp.add_media(audio);

            /* Video section: VP8, H264 */
            var video = new MediaDescription(MediaType.VIDEO, 9);
            video.mid = "video";
            var vp8 = new CodecCapability(96, "VP8", 90000, 1);
            vp8.add_feedback("nack");
            vp8.add_feedback("nack pli");
            vp8.add_feedback("ccm fir");
            vp8.add_feedback("goog-remb");
            vp8.add_feedback("transport-cc");
            video.add_codec(vp8);

            var h264 = new CodecCapability(98, "H264", 90000, 1);
            h264.fmtp_parameters = "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f";
            h264.add_feedback("nack");
            h264.add_feedback("nack pli");
            h264.add_feedback("transport-cc");
            video.add_codec(h264);

            sdp.add_media(video);
            return sdp;
        }

        /**
         * Generates an SDP Answer matching an incoming SDP Offer.
         */
        public SessionDescription negotiate_answer(SessionDescription offer,
                                                  string server_ice_ufrag,
                                                  string server_ice_pwd,
                                                  string server_fingerprint) throws SdpError {
            var answer = new SessionDescription();
            answer.origin_username = "solas";
            answer.session_id = offer.session_id;
            answer.session_version = "2";

            foreach (var offer_m in offer.media_sections) {
                var answer_m = new MediaDescription(offer_m.media_type, offer_m.port);
                answer_m.mid = offer_m.mid;
                answer_m.ice_ufrag = server_ice_ufrag;
                answer_m.ice_pwd = server_ice_pwd;
                answer_m.fingerprint_hash = "sha-256";
                answer_m.fingerprint_val = server_fingerprint;
                answer_m.setup_role = SetupRole.PASSIVE; /* Server is passive in DTLS */
                answer_m.rtcp_mux = offer_m.rtcp_mux;
                answer_m.rtcp_rsize = offer_m.rtcp_rsize;

                /* Invert direction: if client is sendrecv, server answers sendrecv;
                 * if client is sendonly, server answers recvonly. */
                if (offer_m.direction == MediaDirection.SEND_RECV) {
                    answer_m.direction = MediaDirection.SEND_RECV;
                } else if (offer_m.direction == MediaDirection.SEND_ONLY) {
                    answer_m.direction = MediaDirection.RECV_ONLY;
                } else if (offer_m.direction == MediaDirection.RECV_ONLY) {
                    answer_m.direction = MediaDirection.SEND_ONLY;
                } else {
                    answer_m.direction = MediaDirection.INACTIVE;
                }

                /* Find matching codecs from server capabilities */
                var cap_m = this.server_capabilities.get_media_by_mid(offer_m.mid);
                if (cap_m == null) {
                    /* Match by media type */
                    foreach (var m in this.server_capabilities.media_sections) {
                        if (m.media_type == offer_m.media_type) {
                            cap_m = m;
                            break;
                        }
                    }
                }

                if (cap_m != null) {
                    foreach (var offer_codec in offer_m.codecs) {
                        var matched_cap = cap_m.find_codec_by_name(offer_codec.codec_name);
                        if (matched_cap != null) {
                            /* Keep offer's payload type for decodability */
                            var negotiated = new CodecCapability(offer_codec.payload_type,
                                                                 offer_codec.codec_name,
                                                                 offer_codec.clock_rate,
                                                                 offer_codec.channels);
                            negotiated.fmtp_parameters = (offer_codec.fmtp_parameters != "") ?
                                                         offer_codec.fmtp_parameters : matched_cap.fmtp_parameters;

                            foreach (var fb in matched_cap.rtcp_feedback) {
                                negotiated.add_feedback(fb);
                            }
                            answer_m.add_codec(negotiated);
                        }
                    }
                }

                if (answer_m.codecs.is_empty) {
                    /* Port 0 rejects unsupported media streams (RFC 3264) */
                    answer_m.port = 0;
                }

                answer.add_media(answer_m);
            }

            return answer;
        }
    }
}
