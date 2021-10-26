/*
 * Solas: Real-Time WebRTC Media Engine
 * Network Impairment and Channel Degradation Simulator
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Bench {

    public class NetworkImpairment : Object {
        public double loss_rate_percent { get; set; }
        public double jitter_ms { get; set; }
        public double base_delay_ms { get; set; }
        public double reorder_rate_percent { get; set; }

        private RtpPacket? held_packet;
        private uint64 total_packets;
        private uint64 dropped_packets;

        public NetworkImpairment(double loss_rate = 0.0, double base_delay = 0.0, double jitter = 0.0) {
            this.loss_rate_percent = loss_rate;
            this.base_delay_ms = base_delay;
            this.jitter_ms = jitter;
            this.reorder_rate_percent = 0.0;
            this.held_packet = null;
            this.total_packets = 0;
            this.dropped_packets = 0;
        }

        /**
         * Simulates packet transit across the impaired channel.
         * Returns list of packets ready to deliver (may be 0, 1, or 2 if reordered).
         */
        public Gee.ArrayList<RtpPacket> process_packet(RtpPacket packet) {
            var output = new Gee.ArrayList<RtpPacket>();
            this.total_packets++;

            /* 1. Simulate packet drop */
            if (this.loss_rate_percent > 0.0) {
                double roll = (double) (GLib.Random.next_int() % 10000) / 100.0;
                if (roll < this.loss_rate_percent) {
                    this.dropped_packets++;
                    return output; /* Packet lost */
                }
            }

            /* 2. Simulate packet reordering */
            if (this.reorder_rate_percent > 0.0 && this.held_packet == null) {
                double roll = (double) (GLib.Random.next_int() % 10000) / 100.0;
                if (roll < this.reorder_rate_percent) {
                    this.held_packet = packet;
                    return output; /* Hold this packet, will deliver next turn */
                }
            }

            output.add(packet);

            /* If there was a held packet, deliver it after the current packet */
            if (this.held_packet != null) {
                output.add(this.held_packet);
                this.held_packet = null;
            }

            return output;
        }

        public double actual_loss_rate {
            get {
                if (this.total_packets == 0) return 0.0;
                return ((double) this.dropped_packets / (double) this.total_packets) * 100.0;
            }
        }

        public uint64 total_processed {
            get { return this.total_packets; }
        }

        public uint64 total_dropped {
            get { return this.dropped_packets; }
        }
    }
}
