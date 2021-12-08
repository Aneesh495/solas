/*
 * Solas: Real-Time WebRTC Media Engine
 * ISO-BMFF Fragmented MP4 (fMP4) Box Generator (ISO/IEC 14496-12)
 */

using Solas.Core;

namespace Solas.Distribution {

    public class Fmp4Box : Object {
        public string fourcc { get; set; }
        public uint8[] payload;

        public Fmp4Box(string fourcc, uint8[]? payload = null) {
            this.fourcc = fourcc;
            this.payload = (payload != null) ? payload : new uint8[0];
        }

        public uint8[] serialize() {
            var writer = new ByteWriter(this.payload.length + 8);
            uint32 box_size = (uint32) (this.payload.length + 8);
            writer.write_uint32_be(box_size);
            writer.write_string(this.fourcc);
            writer.write_bytes(this.payload);
            return writer.to_array();
        }

        public static uint8[] create_ftyp() {
            var writer = new ByteWriter(32);
            writer.write_string("iso6"); /* Major brand */
            writer.write_uint32_be(1);    /* Minor version */
            writer.write_string("isom"); /* Compatible brands */
            writer.write_string("mp42");
            writer.write_string("iso6");
            var box = new Fmp4Box("ftyp", writer.to_array());
            return box.serialize();
        }

        public static uint8[] create_moov_init(uint32 track_id, uint32 timescale, bool is_video, uint32 width = 1280, uint32 height = 720) {
            var moov_writer = new ByteWriter(512);

            /* mvhd: movie header */
            var mvhd_writer = new ByteWriter(128);
            mvhd_writer.write_uint8(0); /* Version 0 */
            mvhd_writer.write_zero_padding(3); /* Flags */
            mvhd_writer.write_uint32_be(0); /* Creation time */
            mvhd_writer.write_uint32_be(0); /* Modification time */
            mvhd_writer.write_uint32_be(timescale); /* Timescale */
            mvhd_writer.write_uint32_be(0); /* Duration */
            mvhd_writer.write_uint32_be(0x00010000); /* Rate 1.0 */
            mvhd_writer.write_uint16_be(0x0100); /* Volume 1.0 */
            mvhd_writer.write_zero_padding(10); /* Reserved */
            /* Unity matrix */
            mvhd_writer.write_uint32_be(0x00010000); mvhd_writer.write_uint32_be(0); mvhd_writer.write_uint32_be(0);
            mvhd_writer.write_uint32_be(0); mvhd_writer.write_uint32_be(0x00010000); mvhd_writer.write_uint32_be(0);
            mvhd_writer.write_uint32_be(0); mvhd_writer.write_uint32_be(0); mvhd_writer.write_uint32_be(0x40000000);
            mvhd_writer.write_zero_padding(24); /* Pre-defined */
            mvhd_writer.write_uint32_be(track_id + 1); /* Next track ID */

            var mvhd_box = new Fmp4Box("mvhd", mvhd_writer.to_array());
            moov_writer.write_bytes(mvhd_box.serialize());

            /* mvex: movie extends */
            var mvex_writer = new ByteWriter(64);
            var trex_writer = new ByteWriter(32);
            trex_writer.write_uint32_be(0); /* Version and flags */
            trex_writer.write_uint32_be(track_id);
            trex_writer.write_uint32_be(1); /* Default sample description index */
            trex_writer.write_uint32_be(0); /* Default duration */
            trex_writer.write_uint32_be(0); /* Default size */
            trex_writer.write_uint32_be(0); /* Default flags */

            var trex_box = new Fmp4Box("trex", trex_writer.to_array());
            mvex_writer.write_bytes(trex_box.serialize());
            var mvex_box = new Fmp4Box("mvex", mvex_writer.to_array());
            moov_writer.write_bytes(mvex_box.serialize());

            var moov_box = new Fmp4Box("moov", moov_writer.to_array());
            return moov_box.serialize();
        }

        public static uint8[] create_moof(uint32 seq_number, uint32 track_id, uint64 base_decode_time, size_t sample_size, uint32 sample_duration) {
            var moof_writer = new ByteWriter(256);

            /* mfhd: fragment header */
            var mfhd_writer = new ByteWriter(16);
            mfhd_writer.write_uint32_be(0); /* Version & flags */
            mfhd_writer.write_uint32_be(seq_number);
            var mfhd_box = new Fmp4Box("mfhd", mfhd_writer.to_array());
            moof_writer.write_bytes(mfhd_box.serialize());

            /* traf: track fragment */
            var traf_writer = new ByteWriter(128);

            /* tfhd */
            var tfhd_writer = new ByteWriter(32);
            tfhd_writer.write_uint32_be(0x00020000); /* Default base is moof */
            tfhd_writer.write_uint32_be(track_id);
            var tfhd_box = new Fmp4Box("tfhd", tfhd_writer.to_array());
            traf_writer.write_bytes(tfhd_box.serialize());

            /* tfdt: 64-bit decode time */
            var tfdt_writer = new ByteWriter(32);
            tfdt_writer.write_uint8(1); /* Version 1 (64-bit) */
            tfdt_writer.write_zero_padding(3);
            tfdt_writer.write_uint64_be(base_decode_time);
            var tfdt_box = new Fmp4Box("tfdt", tfdt_writer.to_array());
            traf_writer.write_bytes(tfdt_box.serialize());

            /* trun: track run */
            var trun_writer = new ByteWriter(32);
            trun_writer.write_uint32_be(0x00000301); /* Flags: data-offset, duration, size present */
            trun_writer.write_uint32_be(1); /* Sample count: 1 */
            trun_writer.write_int32_be(0); /* Data offset placeholder */
            trun_writer.write_uint32_be(sample_duration);
            trun_writer.write_uint32_be((uint32) sample_size);
            var trun_box = new Fmp4Box("trun", trun_writer.to_array());
            traf_writer.write_bytes(trun_box.serialize());

            var traf_box = new Fmp4Box("traf", traf_writer.to_array());
            moof_writer.write_bytes(traf_box.serialize());

            var moof_box = new Fmp4Box("moof", moof_writer.to_array());
            return moof_box.serialize();
        }

        public static uint8[] create_mdat(uint8[] sample_data) {
            var box = new Fmp4Box("mdat", sample_data);
            return box.serialize();
        }
    }
}
