/*
 * Solas: Real-Time WebRTC Media Engine
 * H.264 NAL Unit Depacketizer and Keyframe Parser (RFC 6184)
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Media {

    public enum H264NalType {
        SLICE = 1,
        DPA = 2,
        DPB = 3,
        DPC = 4,
        IDR_SLICE = 5,
        SEI = 6,
        SPS = 7,
        PPS = 8,
        AUD = 9,
        STAP_A = 24,
        FU_A = 28
    }

    public class DepacketizerH264 : MediaDepacketizer {

        public DepacketizerH264() {
            Object(codec_id: CodecId.H264);
        }

        /**
         * Detects whether an RTP packet carries an H.264 keyframe (IDR slice or SPS/PPS).
         * Supports:
         * 1. Single NAL unit packet (NAL type 5, 7, 8).
         * 2. STAP-A aggregation packet (aggregating SPS + PPS + IDR).
         * 3. FU-A fragmentation unit (Start bit S=1 and NAL type 5).
         */
        public override bool is_keyframe(RtpPacket packet) {
            uint8[] payload = packet.payload;
            if (payload.length < 1) return false;

            uint8 nal_type = (uint8) (payload[0] & 0x1F);

            if (nal_type == H264NalType.IDR_SLICE || nal_type == H264NalType.SPS) {
                return true;
            }

            if (nal_type == H264NalType.STAP_A) {
                /* Inspect STAP-A aggregated NALUs */
                var reader = new ByteReader(payload, 1);
                try {
                    while (reader.remaining >= 2) {
                        uint16 nal_size = reader.read_uint16_be();
                        if (reader.remaining < nal_size || nal_size < 1) break;
                        uint8 inner_type = (uint8) (reader.peek_uint8() & 0x1F);
                        if (inner_type == H264NalType.IDR_SLICE || inner_type == H264NalType.SPS) {
                            return true;
                        }
                        reader.skip(nal_size);
                    }
                } catch (ReaderError e) {
                    return false;
                }
            } else if (nal_type == H264NalType.FU_A && payload.length >= 2) {
                /* FU indicator: payload[0]
                 * FU header: payload[1]: S(1) | E(1) | R(1) | Type(5) */
                bool s_bit = ((payload[1] & 0x80) != 0);
                uint8 inner_type = (uint8) (payload[1] & 0x1F);
                if (s_bit && inner_type == H264NalType.IDR_SLICE) {
                    return true;
                }
            }

            return false;
        }

        public override uint8[] extract_payload(RtpPacket packet) {
            uint8[] payload = packet.payload;
            if (payload.length < 2) return payload;

            uint8 nal_type = (uint8) (payload[0] & 0x1F);
            if (nal_type == H264NalType.FU_A) {
                /* Reconstruct NAL header: F and NRI from FU indicator, Type from FU header */
                uint8 reconstructed_hdr = (uint8) ((payload[0] & 0xE0) | (payload[1] & 0x1F));
                size_t fu_payload_len = payload.length - 2;
                uint8[] result = new uint8[1 + fu_payload_len];
                result[0] = reconstructed_hdr;
                Memory.copy(&result[1], &payload[2], fu_payload_len);
                return result;
            }

            return payload;
        }
    }
}
