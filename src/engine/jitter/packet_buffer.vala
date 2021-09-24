/*
 * Solas: Real-Time WebRTC Media Engine
 * Packet Reordering Buffer
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Engine.Jitter {

    public class BufferedPacket : Object {
        public uint64 unwrapped_seq { get; set; }
        public int64 arrival_time_us { get; set; }
        public RtpPacket packet { get; set; }

        public BufferedPacket(uint64 seq, int64 arrival_us, RtpPacket pkt) {
            this.unwrapped_seq = seq;
            this.arrival_time_us = arrival_us;
            this.packet = pkt;
        }
    }

    public class PacketBuffer : Object {
        private Gee.ArrayList<BufferedPacket> packets;
        private size_t max_capacity;

        public PacketBuffer(size_t max_capacity = 300) {
            this.packets = new Gee.ArrayList<BufferedPacket>();
            this.max_capacity = max_capacity;
        }

        public size_t size {
            get { return this.packets.size; }
        }

        public bool is_empty {
            get { return this.packets.is_empty; }
        }

        public bool insert(uint64 unwrapped_seq, int64 arrival_us, RtpPacket pkt) {
            /* Check for duplicates */
            for (int i = 0; i < this.packets.size; i++) {
                var cur = this.packets.get(i);
                if (cur.unwrapped_seq == unwrapped_seq) {
                    return false; /* Duplicate dropped */
                }
                if (cur.unwrapped_seq > unwrapped_seq) {
                    this.packets.insert(i, new BufferedPacket(unwrapped_seq, arrival_us, pkt));
                    prune();
                    return true;
                }
            }

            this.packets.add(new BufferedPacket(unwrapped_seq, arrival_us, pkt));
            prune();
            return true;
        }

        public BufferedPacket? peek() {
            if (this.packets.is_empty) return null;
            return this.packets.get(0);
        }

        public BufferedPacket? pop() {
            if (this.packets.is_empty) return null;
            return this.packets.remove_at(0);
        }

        public BufferedPacket? get_by_seq(uint64 seq) {
            foreach (var p in this.packets) {
                if (p.unwrapped_seq == seq) {
                    return p;
                }
            }
            return null;
        }

        public void clear() {
            this.packets.clear();
        }

        private void prune() {
            while (this.packets.size > this.max_capacity) {
                this.packets.remove_at(0);
            }
        }
    }
}
