/*
 * Solas: Real-Time WebRTC Media Engine
 * Multi-Track Conference Session Recording Engine
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Distribution {

    public class RecordingSession : Object {
        public string session_id { get; construct; }
        public string room_id { get; construct; }
        public bool is_recording { get; private set; }

        public uint32 video_frame_count { get; private set; }
        public uint32 audio_frame_count { get; private set; }
        public size_t total_bytes_recorded { get; private set; }

        private Mp4Writer video_writer;
        private Mp4Writer audio_writer;
        private Gee.ArrayList<ByteBuffer> recorded_segments;
        private int64 start_time_ms;
        private int64 end_time_ms;

        public signal void segment_recorded(uint32 frame_index, size_t bytes);

        public RecordingSession(string session_id, string room_id) {
            GLib.Object(session_id: session_id, room_id: room_id);
            this.is_recording = false;
            this.video_frame_count = 0;
            this.audio_frame_count = 0;
            this.total_bytes_recorded = 0;
            this.recorded_segments = new Gee.ArrayList<ByteBuffer>();

            this.video_writer = new Mp4Writer(1, 90000, true, 1920, 1080);
            this.audio_writer = new Mp4Writer(2, 48000, false, 0, 0);
        }

        public void start() {
            this.is_recording = true;
            this.start_time_ms = Clock.get_monotonic_time_ms();

            /* Write video and audio initialisation headers */
            uint8[] v_init = this.video_writer.generate_init_segment();
            this.recorded_segments.add(ByteBuffer.wrap(v_init));
            this.total_bytes_recorded += v_init.length;

            uint8[] a_init = this.audio_writer.generate_init_segment();
            this.recorded_segments.add(ByteBuffer.wrap(a_init));
            this.total_bytes_recorded += a_init.length;
        }

        public void record_video_packet(RtpPacket pkt, bool is_keyframe) {
            if (!this.is_recording || pkt.payload == null || pkt.payload.length == 0) return;

            /* 90kHz timescale: 3000 ticks = 33.3ms at 30fps */
            uint32 duration = 3000;
            uint8[] frag = this.video_writer.write_sample(pkt.payload, duration, is_keyframe);

            this.recorded_segments.add(ByteBuffer.wrap(frag));
            this.total_bytes_recorded += frag.length;
            this.video_frame_count++;

            this.segment_recorded(this.video_frame_count, frag.length);
        }

        public void record_audio_packet(RtpPacket pkt) {
            if (!this.is_recording || pkt.payload == null || pkt.payload.length == 0) return;

            /* 48kHz timescale: 960 ticks = 20ms */
            uint32 duration = 960;
            uint8[] frag = this.audio_writer.write_sample(pkt.payload, duration, false);

            this.recorded_segments.add(ByteBuffer.wrap(frag));
            this.total_bytes_recorded += frag.length;
            this.audio_frame_count++;

            this.segment_recorded(this.audio_frame_count, frag.length);
        }

        public void stop() {
            if (!this.is_recording) return;
            this.is_recording = false;
            this.end_time_ms = Clock.get_monotonic_time_ms();
        }

        public int64 get_duration_ms() {
            if (this.start_time_ms == 0) return 0;
            int64 finish = (this.is_recording) ? Clock.get_monotonic_time_ms() : this.end_time_ms;
            return finish - this.start_time_ms;
        }

        public int get_segment_count() {
            return this.recorded_segments.size;
        }

        public uint8[] get_segment(int index) {
            return this.recorded_segments[index].to_array();
        }
    }
}
