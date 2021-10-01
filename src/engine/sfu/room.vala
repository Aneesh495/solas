/*
 * Solas: Real-Time WebRTC Media Engine
 * Multi-Party Conference Room and Topology Routing Hub
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Protocol.Rtcp;
using Solas.Protocol.Sdp;

namespace Solas.Engine.Sfu {

    public class Room : Object {
        public string room_id { get; set; }
        public int64 created_at_ms { get; private set; }
        public Gee.HashMap<string, Peer> peers { get; private set; }
        public ActiveSpeakerDetector speaker_detector { get; private set; }

        public signal void peer_joined(Peer peer);
        public signal void peer_left(string peer_id);
        public signal void track_published(Peer peer, MediaTrack track);
        public signal void active_speaker_changed(string peer_id);

        public Room(string id) {
            this.room_id = id;
            this.created_at_ms = Clock.get_monotonic_time_ms();
            this.peers = new Gee.HashMap<string, Peer>();
            this.speaker_detector = new ActiveSpeakerDetector();
        }

        public void add_peer(Peer peer) {
            this.peers.set(peer.peer_id, peer);
            this.peer_joined(peer);

            /* Auto-subscribe to all existing published tracks in room */
            foreach (var other in this.peers.values) {
                if (other.peer_id != peer.peer_id) {
                    foreach (var track in other.published_tracks.values) {
                        peer.add_subscription(track);
                    }
                }
            }
        }

        public void remove_peer(string peer_id) {
            if (this.peers.has_key(peer_id)) {
                this.peers.unset(peer_id);
                this.speaker_detector.remove_peer(peer_id);
                this.peer_left(peer_id);

                /* Remove subscriptions from other peers */
                foreach (var other in this.peers.values) {
                    var to_remove = new Gee.ArrayList<string>();
                    foreach (var track in other.subscribed_tracks.values) {
                        if (track.track_id.has_prefix(peer_id + ":")) {
                            to_remove.add(track.track_id);
                        }
                    }
                    foreach (string tid in to_remove) {
                        other.remove_subscription(tid);
                    }
                }
            }
        }

        public void publish_track(Peer peer, MediaTrack track) {
            peer.add_published_track(track);
            this.track_published(peer, track);

            /* Fan-out subscription to all other peers in room */
            foreach (var other in this.peers.values) {
                if (other.peer_id != peer.peer_id) {
                    other.add_subscription(track);
                }
            }
        }

        /**
         * High-frequency packet routing: forwards incoming RTP media from publisher
         * to all subscribed peers in the room.
         */
        public void route_rtp_packet(string publisher_id, RtpPacket packet) {
            var pub = this.peers.get(publisher_id);
            if (pub == null) return;

            /* Check audio level for active speaker election */
            var audio_ext = packet.find_extension_by_id(1);
            if (audio_ext != null) {
                bool vad;
                uint8 level;
                if (audio_ext.parse_audio_level(out vad, out level)) {
                    string prev_speaker = this.speaker_detector.dominant_speaker;
                    this.speaker_detector.update_audio_level(publisher_id, level, vad);
                    if (this.speaker_detector.dominant_speaker != prev_speaker) {
                        this.active_speaker_changed(this.speaker_detector.dominant_speaker);
                    }
                }
            }

            /* Fan-out to subscribers */
            foreach (var sub in this.peers.values) {
                if (sub.peer_id != publisher_id && sub.is_connected) {
                    sub.send_rtp(packet);
                }
            }
        }

        public int peer_count {
            get { return this.peers.size; }
        }
    }
}
