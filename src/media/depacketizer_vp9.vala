/*
 * Solas: Real-Time WebRTC Media Engine
 * VP9 Scalable Video Coding (SVC) Depacketizer (RFC 7741)
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Media {

    public class Vp9PayloadDescriptor : Object {
        public bool has_picture_id { get; set; }
        public bool is_inter_predicted { get; set; }
        public bool has_layer_indices { get; set; }
        public bool is_flexible_mode { get; set; }
        public bool is_start_of_frame { get; set; }
        public bool is_end_of_frame { get; set; }
        public bool has_scalability_structure { get; set; }

        public int picture_id { get; set; }
        public uint8 temporal_layer_id { get; set; }
        public uint8 spatial_layer_id { get; set; }
        public bool is_switching_up_point { get; set; }

        public uint8 num_spatial_layers { get; set; }
        public Gee.ArrayList<uint32> layer_widths { get; private set; }
        public Gee.ArrayList<uint32> layer_heights { get; private set; }

        public Vp9PayloadDescriptor() {
            this.has_picture_id = false;
            this.is_inter_predicted = false;
            this.has_layer_indices = false;
            this.is_flexible_mode = false;
            this.is_start_of_frame = false;
            this.is_end_of_frame = false;
            this.has_scalability_structure = false;

            this.picture_id = -1;
            this.temporal_layer_id = 0;
            this.spatial_layer_id = 0;
            this.is_switching_up_point = false;

            this.num_spatial_layers = 1;
            this.layer_widths = new Gee.ArrayList<uint32>();
            this.layer_heights = new Gee.ArrayList<uint32>();
        }
    }

    public class DepacketizerVp9 : MediaDepacketizer {
        public Vp9PayloadDescriptor? last_descriptor { get; private set; }

        public DepacketizerVp9() {
            Object(codec_id: CodecId.VP9);
            this.last_descriptor = null;
        }

        public Vp9PayloadDescriptor? parse_descriptor(RtpPacket packet) throws MediaError {
            if (packet.payload.length < 1) {
                throw new MediaError.INVALID_PAYLOAD("VP9 payload too short");
            }

            var reader = new ByteReader(packet.payload);
            var desc = new Vp9PayloadDescriptor();

            try {
                /* Octet 0: I|P|L|F|B|E|V|Z */
                uint8 b0 = reader.read_uint8();
                desc.has_picture_id = (b0 & 0x80) != 0;
                desc.is_inter_predicted = (b0 & 0x40) != 0;
                desc.has_layer_indices = (b0 & 0x20) != 0;
                desc.is_flexible_mode = (b0 & 0x10) != 0;
                desc.is_start_of_frame = (b0 & 0x08) != 0;
                desc.is_end_of_frame = (b0 & 0x04) != 0;
                desc.has_scalability_structure = (b0 & 0x02) != 0;

                /* Picture ID */
                if (desc.has_picture_id) {
                    uint8 pid0 = reader.read_uint8();
                    if ((pid0 & 0x80) != 0) {
                        /* 15-bit Picture ID */
                        uint8 pid1 = reader.read_uint8();
                        desc.picture_id = ((int) (pid0 & 0x7F) << 8) | (int) pid1;
                    } else {
                        /* 7-bit Picture ID */
                        desc.picture_id = (int) (pid0 & 0x7F);
                    }
                }

                /* Layer Indices */
                if (desc.has_layer_indices) {
                    uint8 l0 = reader.read_uint8();
                    desc.temporal_layer_id = (uint8) ((l0 >> 5) & 0x07);
                    desc.is_switching_up_point = ((l0 & 0x10) != 0);
                    desc.spatial_layer_id = (uint8) ((l0 >> 1) & 0x07);

                    /* Non-flexible mode includes Temporal Layer P_DIFF */
                    bool tl0picidx_present = (l0 & 0x01) != 0;
                    if (tl0picidx_present) {
                        reader.skip(1); /* TL0PICIDX */
                    }
                }

                /* Reference Indices (in flexible mode with P=1) */
                if (desc.is_flexible_mode && desc.is_inter_predicted) {
                    bool has_next_p_diff = true;
                    while (has_next_p_diff && reader.remaining > 0) {
                        uint8 p_diff = reader.read_uint8();
                        has_next_p_diff = ((p_diff & 0x01) != 0);
                    }
                }

                /* Scalability Structure (SS) */
                if (desc.has_scalability_structure) {
                    uint8 ss0 = reader.read_uint8();
                    uint8 n_s = (uint8) (((ss0 >> 5) & 0x07) + 1);
                    bool has_resolution = ((ss0 & 0x10) != 0);
                    bool has_pg_desc = ((ss0 & 0x08) != 0);
                    desc.num_spatial_layers = n_s;

                    if (has_resolution) {
                        for (int s = 0; s < (int) n_s && reader.remaining >= 4; s++) {
                            uint16 width = reader.read_uint16_be();
                            uint16 height = reader.read_uint16_be();
                            desc.layer_widths.add((uint32) width);
                            desc.layer_heights.add((uint32) height);
                        }
                    }

                    if (has_pg_desc && reader.remaining > 0) {
                        uint8 n_g = reader.read_uint8();
                        for (int g = 0; g < (int) n_g && reader.remaining >= 1; g++) {
                            uint8 g0 = reader.read_uint8();
                            uint8 r = (uint8) ((g0 >> 2) & 0x03);
                            if (reader.remaining >= (size_t) r) {
                                reader.skip((size_t) r);
                            }
                        }
                    }
                }

                this.last_descriptor = desc;
                return desc;
            } catch (ReaderError e) {
                throw new MediaError.INVALID_PAYLOAD("VP9 payload underflow: " + e.message);
            }
        }

        public override bool is_keyframe(RtpPacket packet) {
            try {
                var desc = this.parse_descriptor(packet);
                if (desc == null) return false;

                /* In VP9, a keyframe is marked by P=0 (intra) and B=1 (start of frame) at base layer (SID=0) */
                return (!desc.is_inter_predicted && desc.is_start_of_frame && desc.spatial_layer_id == 0);
            } catch (GLib.Error e) {
                return false;
            }
        }

        public override uint8[] extract_payload(RtpPacket packet) {
            try {
                var reader = new ByteReader(packet.payload);
                uint8 b0 = reader.read_uint8();
                bool has_pic_id = (b0 & 0x80) != 0;
                bool is_inter = (b0 & 0x40) != 0;
                bool has_layers = (b0 & 0x20) != 0;
                bool is_flex = (b0 & 0x10) != 0;
                bool has_ss = (b0 & 0x02) != 0;

                if (has_pic_id) {
                    uint8 p = reader.read_uint8();
                    if ((p & 0x80) != 0) reader.skip(1);
                }

                if (has_layers) {
                    uint8 l0 = reader.read_uint8();
                    if ((l0 & 0x01) != 0) reader.skip(1);
                }

                if (is_flex && is_inter) {
                    bool has_next = true;
                    while (has_next && reader.remaining > 0) {
                        has_next = ((reader.read_uint8() & 0x01) != 0);
                    }
                }

                if (has_ss) {
                    uint8 ss0 = reader.read_uint8();
                    uint8 n_s = (uint8) (((ss0 >> 5) & 0x07) + 1);
                    if ((ss0 & 0x10) != 0) reader.skip(n_s * 4);
                    if ((ss0 & 0x08) != 0 && reader.remaining > 0) {
                        uint8 n_g = reader.read_uint8();
                        for (int g = 0; g < (int) n_g && reader.remaining >= 1; g++) {
                            uint8 g0 = reader.read_uint8();
                            uint8 r = (uint8) ((g0 >> 2) & 0x03);
                            if (reader.remaining >= (size_t) r) reader.skip(r);
                        }
                    }
                }

                return reader.read_bytes(reader.remaining);
            } catch (GLib.Error e) {
                return new uint8[0];
            }
        }
    }
}
