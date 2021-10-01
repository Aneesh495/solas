/*
 * Solas: Real-Time WebRTC Media Engine
 * Peer Connection and Transport Lifecycle
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Protocol.Rtcp;
using Solas.Protocol.Sdp;
using Solas.Engine.Congestion;
using Solas.Engine.Jitter;

namespace Solas.Engine.Sfu {

    public delegate void PacketDispatchFunc(RtpPacket packet);
    public delegate void RtcpDispatchFunc(RtcpPacket packet);

    public class Peer : Object {
        public string peer_id { get; set; }
        public string display_name { get; set; }
        public bool is_connected { get; set; }
        public string ice_ufrag { get; set; }
        public string ice_pwd { get; set; }
        public string dtls_fingerprint { get; set; }

        public Gee.HashMap<string, MediaTrack> published_tracks { get; private set; }
        public Gee.HashMap<string, MediaTrack> subscribed_tracks { get; private set; }

        public BandwidthEstimator bwe { get; private set; }
        public Pacer pacer { get; private set; }
        public PlayoutDelayEstimator playout_estimator { get; private set; }

        public PacketDispatchFunc? on_packet_dispatch;
        public RtcpDispatchFunc? on_rtcp_dispatch;

        public Peer(string id, string name = "") {
            this.peer_id = id;
            this.display_name = (name != "") ? name : id;
            this.is_connected = true;
            this.ice_ufrag = "";
            this.ice_pwd = "";
            this.dtls_fingerprint = "";
            this.published_tracks = new Gee.HashMap<string, MediaTrack>();
            this.subscribed_tracks = new Gee.HashMap<string, MediaTrack>();
            this.bwe = new BandwidthEstimator();
            this.pacer = new Pacer();
            this.playout_estimator = new PlayoutDelayEstimator();
        }

        public void add_published_track(MediaTrack track) {
            this.published_tracks.set(track.track_id, track);
        }

        public void add_subscription(MediaTrack track) {
            this.subscribed_tracks.set(track.track_id, track);
        }

        public void remove_subscription(string track_id) {
            this.subscribed_tracks.unset(track_id);
        }

        public void send_rtp(RtpPacket packet) {
            if (this.on_packet_dispatch != null) {
                this.on_packet_dispatch(packet);
            }
        }

        public void send_rtcp(RtcpPacket packet) {
            if (this.on_rtcp_dispatch != null) {
                this.on_rtcp_dispatch(packet);
            }
        }
    }
}
