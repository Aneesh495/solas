/*
 * Solas: Real-Time WebRTC Media Engine
 * Low-Latency Live HLS Segmenter
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Distribution {

    public class MediaSegment : Object {
        public uint32 sequence_number { get; set; }
        public double duration_seconds { get; set; }
        public uint8[] data;

        public MediaSegment(uint32 seq, double duration_secs, uint8[] data) {
            this.sequence_number = seq;
            this.duration_seconds = duration_secs;
            this.data = data;
        }
    }

    public class LiveSegmenter : Object {
        private uint32 track_id;
        private uint32 timescale;
        private bool is_video;
        private uint32 current_seq;
        private uint64 current_decode_time;
        private ByteWriter current_fragment_mdat;
        private double segment_target_duration_secs;
        private int64 segment_start_time_us;

        public signal void segment_ready(MediaSegment segment);

        public LiveSegmenter(uint32 track_id = 1, uint32 timescale = 90000, bool is_video = true, double target_duration = 2.0) {
            this.track_id = track_id;
            this.timescale = timescale;
            this.is_video = is_video;
            this.current_seq = 1;
            this.current_decode_time = 0;
            this.current_fragment_mdat = new ByteWriter(65536);
            this.segment_target_duration_secs = target_duration;
            this.segment_start_time_us = Clock.get_monotonic_time_us();
        }

        public uint8[] get_initialization_segment() {
            var writer = new ByteWriter(1024);
            writer.write_bytes(Fmp4Box.create_ftyp());
            writer.write_bytes(Fmp4Box.create_moov_init(this.track_id, this.timescale, this.is_video));
            return writer.to_array();
        }

        public void push_sample(uint8[] sample_data, bool is_keyframe, uint32 duration_units, int64 now_us = 0) {
            if (now_us == 0) now_us = Clock.get_monotonic_time_us();

            double elapsed_secs = (double) (now_us - this.segment_start_time_us) / 1000000.0;

            /* Check if segment should be emitted on keyframe boundary */
            if ((elapsed_secs >= this.segment_target_duration_secs && is_keyframe) || elapsed_secs >= (this.segment_target_duration_secs * 2.0)) {
                flush_segment(elapsed_secs);
                this.segment_start_time_us = now_us;
            }

            /* Append 4-byte length prefix + sample payload */
            this.current_fragment_mdat.write_uint32_be((uint32) sample_data.length);
            this.current_fragment_mdat.write_bytes(sample_data);
            this.current_decode_time += duration_units;
        }

        private void flush_segment(double duration_secs) {
            if (this.current_fragment_mdat.size == 0) return;

            uint8[] mdat_data = this.current_fragment_mdat.to_array();
            uint8[] moof = Fmp4Box.create_moof(this.current_seq, this.track_id, this.current_decode_time, mdat_data.length, (uint32) (duration_secs * this.timescale));
            uint8[] mdat = Fmp4Box.create_mdat(mdat_data);

            var seg_writer = new ByteWriter(moof.length + mdat.length);
            seg_writer.write_bytes(moof);
            seg_writer.write_bytes(mdat);

            var seg = new MediaSegment(this.current_seq, duration_secs, seg_writer.to_array());
            this.segment_ready(seg);

            this.current_seq++;
            this.current_fragment_mdat = new ByteWriter(65536);
        }
    }
}
