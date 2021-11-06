/*
 * Solas: Real-Time WebRTC Media Engine
 * AV1 RTP Payload Depacketizer and OBU Parser (RTP Payload Format for AV1)
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Media {

    public enum Av1ObuType {
        UNKNOWN = 0,
        SEQUENCE_HEADER = 1,
        TEMPORAL_DELIMITER = 2,
        FRAME_HEADER = 3,
        TILE_GROUP = 4,
        METADATA = 5,
        FRAME = 6,
        REDUNDANT_FRAME_HEADER = 7,
        TILE_LIST = 8,
        PADDING = 15
    }

    public class Av1Obu : Object {
        public Av1ObuType obu_type { get; set; }
        public bool has_extension { get; set; }
        public uint8 temporal_id { get; set; }
        public uint8 spatial_id { get; set; }
        public uint8[] payload;

        public Av1Obu(Av1ObuType type, uint8[] payload, bool has_ext = false, uint8 tid = 0, uint8 sid = 0) {
            this.obu_type = type;
            this.payload = payload;
            this.has_extension = has_ext;
            this.temporal_id = tid;
            this.spatial_id = sid;
        }
    }

    public class Av1Depacketizer : MediaDepacketizer {
        public bool new_coded_video_sequence { get; private set; }
        public uint8 temporal_id { get; private set; }
        public uint8 spatial_id { get; private set; }
        public Gee.ArrayList<Av1Obu> obus { get; private set; }

        public Av1Depacketizer() {
            Object(codec_id: CodecId.AV1);
            this.new_coded_video_sequence = false;
            this.temporal_id = 0;
            this.spatial_id = 0;
            this.obus = new Gee.ArrayList<Av1Obu>();
        }

        public bool parse_rtp_payload(RtpPacket packet) throws GLib.Error {
            if (packet.payload.length < 1) {
                return false;
            }

            var reader = new ByteReader(packet.payload);
            try {
                /* 1. Parse AV1 Aggregation Header: Z(1)|Y(1)|W(2)|N(1)|Res(3) */
                uint8 agg = reader.read_uint8();
                bool z_bit = (agg & 0x80) != 0;
                bool y_bit = (agg & 0x40) != 0;
                uint8 w_field = (uint8) ((agg >> 4) & 0x03);
                this.new_coded_video_sequence = (agg & 0x08) != 0;

                this.obus.clear();

                /* If W == 0, one OBU follows without an explicit length header */
                if (w_field == 0) {
                    if (reader.remaining > 0) {
                        uint8[] obu_bytes = reader.read_bytes(reader.remaining);
                        var obu = parse_obu_element(obu_bytes);
                        if (obu != null) this.obus.add(obu);
                    }
                } else {
                    /* W elements follow, each preceded by LEB128 length */
                    for (int i = 0; i < (int) w_field && reader.remaining > 0; i++) {
                        size_t obu_len = (i < (int) w_field - 1 || y_bit) ? read_leb128(reader) : reader.remaining;
                        if (obu_len > reader.remaining) obu_len = reader.remaining;

                        uint8[] obu_bytes = reader.read_bytes(obu_len);
                        var obu = parse_obu_element(obu_bytes);
                        if (obu != null) this.obus.add(obu);
                    }
                }

                foreach (var obu in this.obus) {
                    if (obu.has_extension) {
                        this.temporal_id = obu.temporal_id;
                        this.spatial_id = obu.spatial_id;
                    }
                }

                return true;
            } catch (ReaderError e) {
                return false;
            }
        }

        public override bool is_keyframe(RtpPacket packet) {
            try {
                this.parse_rtp_payload(packet);
                foreach (var obu in this.obus) {
                    if (obu.obu_type == Av1ObuType.SEQUENCE_HEADER) {
                        return true;
                    }
                }
            } catch (GLib.Error e) {
                return false;
            }
            return false;
        }

        public override uint8[] extract_payload(RtpPacket packet) {
            try {
                this.parse_rtp_payload(packet);
                var writer = new ByteWriter(packet.payload.length);
                foreach (var obu in this.obus) {
                    writer.write_bytes(obu.payload);
                }
                return writer.to_array();
            } catch (GLib.Error e) {
                return new uint8[0];
            }
        }

        private static Av1Obu? parse_obu_element(uint8[] data) {
            if (data.length < 1) return null;

            uint8 h0 = data[0];
            Av1ObuType type = (Av1ObuType) ((h0 >> 3) & 0x0F);
            bool has_ext = (h0 & 0x04) != 0;

            uint8 tid = 0;
            uint8 sid = 0;
            size_t offset = 1;

            if (has_ext && data.length > 1) {
                uint8 ext = data[1];
                tid = (uint8) ((ext >> 5) & 0x07);
                sid = (uint8) ((ext >> 3) & 0x03);
                offset = 2;
            }

            size_t payload_len = data.length - offset;
            uint8[] payload = new uint8[payload_len];
            if (payload_len > 0) {
                for (size_t i = 0; i < payload_len; i++) {
                    payload[i] = data[offset + i];
                }
            }

            return new Av1Obu(type, payload, has_ext, tid, sid);
        }

        private static size_t read_leb128(ByteReader reader) throws ReaderError {
            size_t value = 0;
            for (int i = 0; i < 8; i++) {
                uint8 b = reader.read_uint8();
                value |= ((size_t) (b & 0x7F)) << (i * 7);
                if ((b & 0x80) == 0) break;
            }
            return value;
        }
    }
}
