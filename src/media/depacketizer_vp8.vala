/*
 * Solas: Real-Time WebRTC Media Engine
 * VP8 Payload Descriptor and Keyframe Parser (RFC 7741)
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Media {

    public class DepacketizerVp8 : MediaDepacketizer {

        public DepacketizerVp8() {
            Object(codec_id: CodecId.VP8);
        }

        /**
         * Inspects VP8 payload descriptor and uncompressed header to identify keyframe.
         * RFC 7741 Section 4.2 & RFC 6386 Section 9.1:
         * A VP8 keyframe has:
         * - S-bit = 1 (start of partition)
         * - Partition index = 0
         * - In the uncompressed frame header: bit 0 of first byte is 0 (P-bit = 0 for keyframe).
         * - Start code: 0x9D 0x01 0x2A
         */
        public override bool is_keyframe(RtpPacket packet) {
            var info = parse_frame_info(packet);
            return info != null && info.frame_type == FrameType.KEYFRAME;
        }

        public VideoFrameInfo? parse_frame_info(RtpPacket packet) {
            uint8[] payload = packet.payload;
            if (payload.length < 1) return null;

            var reader = new ByteReader(payload);
            var info = new VideoFrameInfo();
            try {
                uint8 b0 = reader.read_uint8();
                bool x_bit = ((b0 & 0x80) != 0);
                bool s_bit = ((b0 & 0x10) != 0);
                uint8 part_id = (uint8) (b0 & 0x0F);

                info.is_partition_start = s_bit;

                if (x_bit && reader.has_remaining) {
                    uint8 b1 = reader.read_uint8();
                    bool i_bit = ((b1 & 0x80) != 0);
                    bool l_bit = ((b1 & 0x40) != 0);
                    bool t_bit = ((b1 & 0x20) != 0);
                    bool k_bit = ((b1 & 0x10) != 0);

                    if (i_bit && reader.has_remaining) {
                        uint8 pid0 = reader.read_uint8();
                        if ((pid0 & 0x80) != 0 && reader.has_remaining) {
                            /* 15-bit PictureID */
                            uint8 pid1 = reader.read_uint8();
                            info.picture_id = (int) ((((uint16) (pid0 & 0x7F)) << 8) | (uint16) pid1);
                        } else {
                            /* 7-bit PictureID */
                            info.picture_id = (int) (pid0 & 0x7F);
                        }
                    }

                    if (l_bit && reader.has_remaining) reader.skip(1); /* TL0PICIDX */
                    if ((t_bit || k_bit) && reader.has_remaining) reader.skip(1); /* TID / KEYIDX */
                }

                if (s_bit && part_id == 0 && reader.remaining >= 10) {
                    /* Uncompressed VP8 frame header */
                    uint8 frame_hdr0 = reader.read_uint8();
                    bool is_key = ((frame_hdr0 & 0x01) == 0); /* Inverse keyframe flag: 0 = key, 1 = inter */

                    if (is_key) {
                        reader.skip(2); /* Skip version and show_frame */
                        uint8 sync0 = reader.read_uint8();
                        uint8 sync1 = reader.read_uint8();
                        uint8 sync2 = reader.read_uint8();

                        /* Check VP8 sync code: 0x9D 0x01 0x2A */
                        if (sync0 == 0x9D && sync1 == 0x01 && sync2 == 0x2A) {
                            info.frame_type = FrameType.KEYFRAME;
                            uint16 raw_w = reader.read_uint16_le();
                            uint16 raw_h = reader.read_uint16_le();
                            info.width = (uint32) (raw_w & 0x3FFF);
                            info.height = (uint32) (raw_h & 0x3FFF);
                            return info;
                        }
                    } else {
                        info.frame_type = FrameType.DELTAFRAME;
                        return info;
                    }
                }

                info.frame_type = FrameType.DELTAFRAME;
                return info;

            } catch (ReaderError e) {
                return null;
            }
        }

        public override uint8[] extract_payload(RtpPacket packet) {
            uint8[] payload = packet.payload;
            if (payload.length < 1) return payload;

            var reader = new ByteReader(payload);
            try {
                uint8 b0 = reader.read_uint8();
                bool x_bit = ((b0 & 0x80) != 0);

                if (x_bit && reader.has_remaining) {
                    uint8 b1 = reader.read_uint8();
                    bool i_bit = ((b1 & 0x80) != 0);
                    bool l_bit = ((b1 & 0x40) != 0);
                    bool t_bit = ((b1 & 0x20) != 0);
                    bool k_bit = ((b1 & 0x10) != 0);

                    if (i_bit && reader.has_remaining) {
                        uint8 pid0 = reader.read_uint8();
                        if ((pid0 & 0x80) != 0 && reader.has_remaining) {
                            reader.skip(1);
                        }
                    }

                    if (l_bit && reader.has_remaining) reader.skip(1);
                    if ((t_bit || k_bit) && reader.has_remaining) reader.skip(1);
                }

                return reader.read_bytes(reader.remaining);
            } catch (ReaderError e) {
                return payload;
            }
        }
    }
}
