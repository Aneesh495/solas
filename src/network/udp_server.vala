/*
 * Solas: Real-Time WebRTC Media Engine
 * High-Throughput Asynchronous UDP Socket Engine
 */

using Solas.Core;

namespace Solas.Network {

    public delegate void UdpPacketHandler(uint8[] packet, SocketAddress sender_addr);

    public class UdpServer : Object {
        private Socket? socket;
        private uint16 bind_port;
        private bool is_running;
        private Cancellable cancellable;
        public UdpPacketHandler? on_packet;

        public UdpServer(uint16 port = 5004) {
            this.bind_port = port;
            this.socket = null;
            this.is_running = false;
            this.cancellable = new Cancellable();
        }

        public void start() throws GLib.Error {
            this.socket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
            var addr = new InetSocketAddress(new InetAddress.any(SocketFamily.IPV4), this.bind_port);
            this.socket.bind(addr, true);
            this.socket.set_blocking(false);
            this.is_running = true;

            Logger.info("UDP", "Solas UDP media multiplexer listening on 0.0.0.0:%u", (uint) this.bind_port);
        }

        public void stop() {
            this.is_running = false;
            this.cancellable.cancel();
            if (this.socket != null) {
                try {
                    this.socket.close();
                } catch (GLib.Error e) {
                    /* Ignored on shutdown */
                }
            }
        }

        public ssize_t send_datagram(uint8[] data, SocketAddress dest_addr) throws GLib.Error {
            if (this.socket == null) return -1;
            return this.socket.send_to(dest_addr, data, this.cancellable);
        }

        public bool running {
            get { return this.is_running; }
        }

        public uint16 port {
            get { return this.bind_port; }
        }
    }
}
