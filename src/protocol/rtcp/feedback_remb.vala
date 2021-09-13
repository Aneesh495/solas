/*
 * Solas: Real-Time WebRTC Media Engine
 * Receiver Estimated Maximum Bitrate (REMB)
 */

using Solas.Core;

namespace Solas.Protocol.Rtcp {

    public const uint32 REMB_UNIQUE_IDENTIFIER = 0x52454D42U; /* "REMB" */

    public class RembFeedback : RtcpPacket {
        public uint32 sender_ssrc { get; set; }
        public uint64 bitrate_bps { get; set; }
        public Gee.ArrayList<uint32> ssrc_feedback { get; private set; }

        public RembFeedback(uint32 sender_ssrc = 0, uint64 bitrate_bps = 0) {
            Object(packet_type: PacketType.PAYLOAD_FEEDBACK);
            this.count_or_format = (uint8) PayloadFeedbackFormat.REMB;
            this.sender_ssrc = sender_ssrc;
            this.bitrate_bps = bitrate_bps;
            this.ssrc_feedback = new Gee.ArrayList<uint32>();
        }

        public void add_ssrc(uint32 ssrc) {
            this.ssrc_feedback.add(ssrc);
        }

        public override void serialize(ByteWriter writer) {
            writer.write_uint8(0x80 | (uint8) PayloadFeedbackFormat.REMB);
            writer.write_uint8((uint8) PacketType.PAYLOAD_FEEDBACK);

            /* Length = (16 bytes header + 4 * num_ssrc) / 4 - 1 */
            uint16 len_words = (uint16) ((16 + this.ssrc_feedback.size * 4) / 4 - 1);
            writer.write_uint16_be(len_words);

            writer.write_uint32_be(this.sender_ssrc);
            writer.write_uint32_be(0); /* Media SSRC is 0 for REMB */

            writer.write_uint32_be(REMB_UNIQUE_IDENTIFIER);

            /* Number of SSRCs (8 bits) | Exp (6 bits) | Mantissa (18 bits) */
            uint8 num_ssrc = (uint8) (this.ssrc_feedback.size & 0xFF);
            writer.write_uint8(num_ssrc);

            uint8 exp = 0;
            uint64 mantissa = this.bitrate_bps;
            while (mantissa > 0x3FFFF && exp < 63) {
                mantissa >>= 1;
                exp++;
            }

            uint32 br_field = (((uint32) (exp & 0x3F) << 18) | (uint32) (mantissa & 0x3FFFF));
            writer.write_uint24_be(br_field);

            foreach (uint32 s in this.ssrc_feedback) {
                writer.write_uint32_be(s);
            }
        }

        public static RembFeedback parse(uint8[] data) throws RtcpError {
            if (data.length < 20) {
                throw new RtcpError.HEADER_UNDERFLOW("Data too short for REMB");
            }
            var reader = new ByteReader(data);
            try {
                reader.skip(4);
                var remb = new RembFeedback();
                remb.sender_ssrc = reader.read_uint32_be();
                reader.skip(4);

                uint32 id = reader.read_uint32_be();
                if (id != REMB_UNIQUE_IDENTIFIER) {
                    throw new RtcpError.MALFORMED_PACKET("Not a valid REMB packet identifier");
                }

                uint8 num_ssrc = reader.read_uint8();
                uint32 br_field = reader.read_uint24_be();
                uint8 exp = (uint8) ((br_field >> 18) & 0x3F);
                uint32 mantissa = br_field & 0x3FFFF;
                remb.bitrate_bps = ((uint64) mantissa) << exp;

                for (int i = 0; i < num_ssrc && reader.remaining >= 4; i++) {
                    remb.add_ssrc(reader.read_uint32_be());
                }

                return remb;
            } catch (ReaderError e) {
                throw new RtcpError.HEADER_UNDERFLOW("Underflow reading REMB: %s".printf(e.message));
            }
        }
    }
}
