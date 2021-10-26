/*
 * Solas: Real-Time WebRTC Media Engine
 * High-Precision Synthetic RTP Media Stream Generator
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Protocol.Sdp;

namespace Solas.Bench {

    public class SyntheticPublisher : Object {
        public string peer_id { get; set; }
        public uint32 audio_ssrc { get; set; }
        public uint32 video_ssrc { get; set; }
        public uint16 audio_seq { get; private set; }
        public uint16 video_seq { get; private set; }
        public uint32 audio_ts { get; private set; }
        public uint32 video_ts { get; private set; }

        public uint32 target_bitrate_kbps { get; set; }
        public int fps { get; set; }
        public int audio_packet_rate_hz { get; set; }

        public SyntheticPublisher(string peer_id, uint32 audio_ssrc = 10001, uint32 video_ssrc = 20001, uint32 bitrate_kbps = 1500) {
            this.peer_id = peer_id;
            this.audio_ssrc = audio_ssrc;
            this.video_ssrc = video_ssrc;
            this.target_bitrate_kbps = bitrate_kbps;
            this.fps = 30;
            this.audio_packet_rate_hz = 50; /* 20ms frames */

            this.audio_seq = (uint16) (GLib.Random.next_int() & 0xFFFF);
            this.video_seq = (uint16) (GLib.Random.next_int() & 0xFFFF);
            this.audio_ts = (uint32) GLib.Random.next_int();
            this.video_ts = (uint32) GLib.Random.next_int();
        }

        /**
         * Generates a 20ms Opus audio RTP packet (PT 111, 48kHz clock rate -> 960 samples/pkt).
         */
        public RtpPacket generate_audio_packet() {
            var pkt = new RtpPacket();
            pkt.version = 2;
            pkt.payload_type = 111;
            pkt.sequence_number = this.audio_seq++;
            pkt.timestamp = this.audio_ts;
            this.audio_ts += 960; /* 48000 Hz / 50 pkts/s = 960 */
            pkt.ssrc = this.audio_ssrc;
            pkt.marker = false;

            /* Simulated 80-byte Opus audio frame (32 kbps) */
            uint8[] payload = new uint8[80];
            for (int i = 0; i < 80; i++) {
                payload[i] = (uint8) ((i * 7) & 0xFF);
            }
            pkt.payload = payload;

            return pkt;
        }

        /**
         * Generates one video frame slice.
         * If frame_bytes > 1200 MTU, multiple RTP packets are generated.
         */
        public Gee.ArrayList<RtpPacket> generate_video_frame(bool is_keyframe = false) {
            var list = new Gee.ArrayList<RtpPacket>();

            /* Target frame size in bytes = (target_bitrate_kbps * 1000 / 8) / fps */
            size_t frame_bytes = (size_t) ((this.target_bitrate_kbps * 125) / (uint32) this.fps);
            if (is_keyframe) frame_bytes *= 3; /* Keyframes are typically ~3x larger */
            if (frame_bytes < 200) frame_bytes = 200;

            const size_t MAX_PAYLOAD_SIZE = 1180;
            size_t remaining = frame_bytes;

            while (remaining > 0) {
                size_t slice = (remaining > MAX_PAYLOAD_SIZE) ? MAX_PAYLOAD_SIZE : remaining;
                remaining -= slice;

                var pkt = new RtpPacket();
                pkt.version = 2;
                pkt.payload_type = 96; /* VP8 */
                pkt.sequence_number = this.video_seq++;
                pkt.timestamp = this.video_ts;
                pkt.ssrc = this.video_ssrc;
                pkt.marker = (remaining == 0); /* Marker bit on last slice of video frame */

                uint8[] payload = new uint8[slice];
                for (size_t i = 0; i < slice; i++) {
                    payload[i] = (uint8) (i & 0xFF);
                }
                pkt.payload = payload;

                list.add(pkt);
            }

            /* Advance 90kHz timestamp by (90000 / fps) */
            this.video_ts += (uint32) (90000 / this.fps);

            return list;
        }
    }
}
