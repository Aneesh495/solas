/*
 * Solas: Real-Time WebRTC Media Engine
 * Core Server Daemon and Event Orchestrator
 */

using Solas.Core;
using Solas.Engine.Sfu;
using Solas.Network;
using Solas.Protocol.Stun;
using Solas.Protocol.Rtp;
using Solas.Protocol.Rtcp;

namespace Solas.Server {

    public class SolasServer : Object {
        public ServerConfig config { get; private set; }
        public Gee.HashMap<string, Room> rooms { get; private set; }
        public Gee.HashMap<string, SignalingSession> sessions { get; private set; }

        public UdpServer udp_server { get; private set; }
        public HttpRouter http_router { get; private set; }
        public HttpServer http_server { get; private set; }
        private MainLoop loop;
        private bool is_running;

        public SolasServer(ServerConfig? config = null) {
            this.config = (config != null) ? config : new ServerConfig();
            this.rooms = new Gee.HashMap<string, Room>();
            this.sessions = new Gee.HashMap<string, SignalingSession>();
            this.udp_server = new UdpServer(this.config.udp_port);
            this.http_router = new HttpRouter(this.rooms);
            this.http_server = new HttpServer(this.config.http_port, this.http_router);
            this.loop = new MainLoop();
            this.is_running = false;

            this.setup_network_handlers();
        }

        private void setup_network_handlers() {
            this.udp_server.on_packet = (packet, sender_addr) => {
                this.handle_udp_packet(packet, sender_addr);
            };
        }

        public void start() throws GLib.Error {
            Logger.info("SERVER", "Initializing Solas Real-Time WebRTC Media Engine...");
            Logger.info("SERVER", "Configured Public IP: %s", this.config.public_ip);
            Logger.info("SERVER", "HTTP / WebSocket Port: %u", (uint) this.config.http_port);
            Logger.info("SERVER", "UDP Media Port: %u", (uint) this.config.udp_port);

            this.udp_server.start();
            this.http_server.start();
            this.is_running = true;

            Logger.info("SERVER", "Solas Media Engine successfully started and listening.");
        }

        public void stop() {
            if (!this.is_running) return;

            Logger.info("SERVER", "Shutting down Solas Media Engine...");
            this.is_running = false;
            this.udp_server.stop();
            this.http_server.stop();

            if (this.loop.is_running()) {
                this.loop.quit();
            }
            Logger.info("SERVER", "Solas Media Engine terminated cleanly.");
        }

        public void run() {
            this.loop.run();
        }

        public SignalingSession create_signaling_session(string session_id) {
            var sess = new SignalingSession(session_id, this.rooms);
            sess.ice_agent.gather_candidates(this.config.public_ip, this.config.udp_port);
            this.sessions.set(session_id, sess);
            return sess;
        }

        public void remove_signaling_session(string session_id) {
            this.sessions.unset(session_id);
        }

        public Room get_or_create_room(string room_id) {
            if (!this.rooms.has_key(room_id)) {
                var room = new Room(room_id);
                this.rooms.set(room_id, room);
                return room;
            }
            return this.rooms.get(room_id);
        }

        private void handle_udp_packet(uint8[] packet, SocketAddress sender_addr) {
            var proto = ProtocolDemuxer.classify(packet);

            switch (proto) {
                case DemuxProtocol.STUN:
                    this.handle_stun_packet(packet, sender_addr);
                    break;

                case DemuxProtocol.RTP:
                    this.handle_rtp_packet(packet, sender_addr);
                    break;

                case DemuxProtocol.RTCP:
                    this.handle_rtcp_packet(packet, sender_addr);
                    break;

                case DemuxProtocol.DTLS:
                    /* DTLS record received */
                    break;

                default:
                    break;
            }
        }

        private void handle_stun_packet(uint8[] packet, SocketAddress sender_addr) {
            try {
                var stun_msg = StunMessage.parse(packet);

                /* Route to matching ICE agent across active sessions */
                foreach (var sess in this.sessions.values) {
                    var resp = sess.ice_agent.process_stun_request(stun_msg, sender_addr);
                    if (resp != null) {
                        uint8[] resp_bytes = resp.serialize(null, true);
                        this.udp_server.send_datagram(resp_bytes, sender_addr);
                        break;
                    }
                }
            } catch (GLib.Error e) {
                Logger.warn("SERVER", "Failed to process STUN packet: %s", e.message);
            }
        }

        private void handle_rtp_packet(uint8[] packet, SocketAddress sender_addr) {
            try {
                var rtp_pkt = RtpPacket.parse(packet);
                /* Route RTP packet into corresponding room and track */
                foreach (var room in this.rooms.values) {
                    foreach (var peer in room.peers.values) {
                        foreach (var track in peer.published_tracks.values) {
                            if (track.ssrc == rtp_pkt.ssrc) {
                                track.store_packet(rtp_pkt);
                                return;
                            }
                        }
                    }
                }
            } catch (GLib.Error e) {
                /* Malformed or unrecognized RTP packet */
            }
        }

        private void handle_rtcp_packet(uint8[] packet, SocketAddress sender_addr) {
            /* RTCP feedback and report routing */
        }

        public bool running {
            get { return this.is_running; }
        }
    }
}
