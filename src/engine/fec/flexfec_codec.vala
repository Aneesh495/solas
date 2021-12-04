/*
 * Solas: Real-Time WebRTC Media Engine
 * FlexFEC XOR Parity Encoder and Loss Recovery Decoder (RFC 8627)
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Engine.Fec {

    public class FlexFecEncoder : Object {
        public uint32 protected_ssrc { get; construct; }
        public int fec_group_size { get; construct; }

        private Gee.ArrayList<RtpPacket> pending_packets;
        private uint16 seq_base;

        public FlexFecEncoder(uint32 ssrc, int group_size = 4) {
            GLib.Object(protected_ssrc: ssrc, fec_group_size: group_size);
            this.pending_packets = new Gee.ArrayList<RtpPacket>();
            this.seq_base = 0;
        }

        /**
         * Feeds a media packet into the FEC block.
         * Returns a generated FlexFecPacket when the block reaches fec_group_size.
         */
        public FlexFecPacket? add_packet(RtpPacket pkt) {
            if (this.pending_packets.is_empty) {
                this.seq_base = pkt.sequence_number;
            }

            this.pending_packets.add(pkt);

            if (this.pending_packets.size >= this.fec_group_size) {
                return this.generate_fec_packet();
            }

            return null;
        }

        private FlexFecPacket generate_fec_packet() {
            uint16 mask = 0;
            uint16 len_recovery = 0;
            uint32 ts_recovery = 0;
            size_t max_payload_len = 0;

            for (int i = 0; i < this.pending_packets.size; i++) {
                var p = this.pending_packets[i];
                int offset = (int) (p.sequence_number - this.seq_base);
                if (offset >= 0 && offset < 16) {
                    mask |= (uint16) (1 << offset);
                }

                uint16 p_len = (p.payload != null) ? (uint16) p.payload.length : 0;
                len_recovery ^= p_len;
                ts_recovery ^= p.timestamp;

                if (p_len > max_payload_len) {
                    max_payload_len = p_len;
                }
            }

            uint8[] parity = new uint8[max_payload_len];
            for (int i = 0; i < this.pending_packets.size; i++) {
                var p = this.pending_packets[i];
                if (p.payload == null) continue;

                for (size_t b = 0; b < p.payload.length; b++) {
                    parity[b] ^= p.payload[b];
                }
            }

            var fec = new FlexFecPacket(this.protected_ssrc, this.seq_base, mask);
            fec.length_recovery = len_recovery;
            fec.timestamp_recovery = ts_recovery;
            fec.parity_payload = parity;

            this.pending_packets.clear();
            return fec;
        }
    }

    public class FlexFecDecoder : Object {
        public uint32 protected_ssrc { get; construct; }
        private Gee.HashMap<int, RtpPacket> packet_cache;

        public FlexFecDecoder(uint32 ssrc) {
            GLib.Object(protected_ssrc: ssrc);
            this.packet_cache = new Gee.HashMap<int, RtpPacket>();
        }

        public void add_media_packet(RtpPacket pkt) {
            this.packet_cache.set((int) pkt.sequence_number, pkt);
        }

        /**
         * Examines an incoming FlexFEC packet to check if exactly one missing packet can be recovered.
         * Returns reconstructed RtpPacket if recovery succeeds, or null if no recovery needed or impossible.
         */
        public RtpPacket? try_recover(FlexFecPacket fec) {
            int missing_seq = -1;
            int missing_count = 0;
            var present_packets = new Gee.ArrayList<RtpPacket>();

            for (int bit = 0; bit < 16; bit++) {
                if ((fec.mask & (1 << bit)) == 0) continue;

                int seq = (int) fec.seq_base + bit;
                var pkt = this.packet_cache.get(seq);
                if (pkt != null) {
                    present_packets.add(pkt);
                } else {
                    missing_seq = seq;
                    missing_count++;
                }
            }

            /* Recovery is only possible if exactly one packet is missing */
            if (missing_count != 1 || missing_seq == -1) {
                return null;
            }

            /* Recover payload length and timestamp */
            uint16 rec_len = fec.length_recovery;
            uint32 rec_ts = fec.timestamp_recovery;

            foreach (var p in present_packets) {
                uint16 p_len = (p.payload != null) ? (uint16) p.payload.length : 0;
                rec_len ^= p_len;
                rec_ts ^= p.timestamp;
            }

            /* Recover payload bytes */
            uint8[] rec_payload = new uint8[rec_len];
            for (size_t b = 0; b < rec_len; b++) {
                uint8 byte_val = (b < fec.parity_payload.length) ? fec.parity_payload[b] : 0;
                foreach (var p in present_packets) {
                    if (p.payload != null && b < p.payload.length) {
                        byte_val ^= p.payload[b];
                    }
                }
                rec_payload[b] = byte_val;
            }

            var recovered = new RtpPacket();
            recovered.version = 2;
            recovered.ssrc = this.protected_ssrc;
            recovered.sequence_number = (uint16) missing_seq;
            recovered.timestamp = rec_ts;
            recovered.payload = rec_payload;

            /* Store in cache to assist future FEC recoveries */
            this.packet_cache.set(missing_seq, recovered);

            return recovered;
        }
    }
}
