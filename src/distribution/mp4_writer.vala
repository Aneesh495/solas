/*
 * Solas: Real-Time WebRTC Media Engine
 * ISO-BMFF Segmented MP4 Container Writer
 */

using Solas.Core;

namespace Solas.Distribution {

    public class Mp4Writer : Object {
        public uint32 track_id { get; construct; }
        public uint32 timescale { get; construct; }
        public bool is_video { get; construct; }
        public uint32 width { get; construct; }
        public uint32 height { get; construct; }

        private uint32 sequence_number;
        private uint64 current_decode_time;

        public Mp4Writer(uint32 track_id = 1, uint32 timescale = 90000, bool is_video = true, uint32 w = 1280, uint32 h = 720) {
            GLib.Object(track_id: track_id, timescale: timescale, is_video: is_video, width: w, height: h);
            this.sequence_number = 1;
            this.current_decode_time = 0;
        }

        /**
         * Generates the fMP4 initialization segment (ftyp + moov).
         */
        public uint8[] generate_init_segment() {
            uint8[] ftyp = Fmp4Box.create_ftyp();
            uint8[] moov = Fmp4Box.create_moov_init(this.track_id, this.timescale, this.is_video, this.width, this.height);

            var writer = new ByteWriter(ftyp.length + moov.length);
            writer.write_bytes(ftyp);
            writer.write_bytes(moov);
            return writer.to_array();
        }

        /**
         * Encapsulates a media sample into a fragment segment (moof + mdat).
         */
        public uint8[] write_sample(uint8[] sample_data, uint32 duration, bool is_keyframe) {
            uint8[] moof = Fmp4Box.create_moof(this.sequence_number++, this.track_id, this.current_decode_time,
                                               sample_data.length, duration);
            uint8[] mdat = Fmp4Box.create_mdat(sample_data);

            this.current_decode_time += (uint64) duration;

            var writer = new ByteWriter(moof.length + mdat.length);
            writer.write_bytes(moof);
            writer.write_bytes(mdat);
            return writer.to_array();
        }
    }
}
