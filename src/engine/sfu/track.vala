/*
 * Solas: Real-Time WebRTC Media Engine
 * Media Track Model and Packet Retransmission Cache
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Protocol.Sdp;
using Solas.Media;

namespace Solas.Engine.Sfu {

    public class TrackStats : Object {
        public uint64 packets_received { get; set; }
        public uint64 bytes_received { get; set; }
        public uint64 packets_sent { get; set; }
        public uint64 bytes_sent { get; set; }
        public uint64 nack_requests_received { get; set; }
        public uint64 nack_retransmissions_sent { get; set; }
        public double current_bitrate_kbps { get; set; }

        public TrackStats() {
            this.packets_received = 0;
            this.bytes_received = 0;
            this.packets_sent = 0;
            this.bytes_sent = 0;
            this.nack_requests_received = 0;
            this.nack_retransmissions_sent = 0;
            this.current_bitrate_kbps = 0.0;
        }
    }

    public class MediaTrack : Object {
        public string track_id { get; set; }
        public string stream_id { get; set; }
        public MediaType media_type { get; set; }
        public uint32 ssrc { get; set; }
        public uint32 rtx_ssrc { get; set; }
        public string mid { get; set; }
        public string rid { get; set; }
        public CodecCapability codec { get; set; }
        public bool muted { get; set; }
        public TrackStats stats { get; private set; }

        /* Circular ring buffer of recent packets for O(1) NACK servicing */
        private RtpPacket?[] packet_cache;
        private size_t cache_capacity;
        private BitrateMeter bitrate_meter;

        public const size_t DEFAULT_CACHE_SIZE = 512;

        public MediaTrack(string id, MediaType type, uint32 ssrc, CodecCapability codec) {
            this.track_id = id;
            this.stream_id = "";
            this.media_type = type;
            this.ssrc = ssrc;
            this.rtx_ssrc = 0;
            this.mid = "";
            this.rid = "";
            this.codec = codec;
            this.muted = false;
            this.stats = new TrackStats();
            this.cache_capacity = DEFAULT_CACHE_SIZE;
            this.packet_cache = new RtpPacket?[this.cache_capacity];
            this.bitrate_meter = new BitrateMeter(1000);
        }

        public void store_packet(RtpPacket packet, int64 now_us = 0) {
            if (now_us == 0) now_us = Clock.get_monotonic_time_us();

            size_t idx = (size_t) (packet.sequence_number % this.cache_capacity);
            this.packet_cache[idx] = packet;

            size_t pkt_bytes = packet.payload.length + 12;
            this.stats.packets_received++;
            this.stats.bytes_received += pkt_bytes;
            this.bitrate_meter.record(pkt_bytes, now_us);
            this.stats.current_bitrate_kbps = this.bitrate_meter.get_bitrate_kbps(now_us);
        }

        public RtpPacket? retrieve_packet_for_nack(uint16 seq) {
            size_t idx = (size_t) (seq % this.cache_capacity);
            var pkt = this.packet_cache[idx];
            if (pkt != null && pkt.sequence_number == seq) {
                this.stats.nack_retransmissions_sent++;
                return pkt;
            }
            return null;
        }
    }
}
