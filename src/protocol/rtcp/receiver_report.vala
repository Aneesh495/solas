/*
 * Solas: Real-Time WebRTC Media Engine
 * RTCP Receiver Report (RR) (RFC 3550)
 */

using Solas.Core;

namespace Solas.Protocol.Rtcp {

    public class ReceiverReport : RtcpPacket {
        public uint32 ssrc { get; set; }
        public Gee.ArrayList<ReceptionReportBlock> report_blocks { get; private set; }

        public ReceiverReport(uint32 ssrc = 0) {
            Object(packet_type: PacketType.RECEIVER_REPORT);
            this.ssrc = ssrc;
            this.report_blocks = new Gee.ArrayList<ReceptionReportBlock>();
        }

        public override void serialize(ByteWriter writer) {
            uint8 count = (uint8) (this.report_blocks.size & 0x1F);
            uint8 b0 = (uint8) (0x80 | count);
            writer.write_uint8(b0);
            writer.write_uint8((uint8) PacketType.RECEIVER_REPORT);

            uint16 len_words = (uint16) ((8 + this.report_blocks.size * 24) / 4 - 1);
            writer.write_uint16_be(len_words);

            writer.write_uint32_be(this.ssrc);

            foreach (var rb in this.report_blocks) {
                rb.serialize(writer);
            }
        }

        public static ReceiverReport parse(uint8[] data) throws RtcpError {
            if (data.length < 8) {
                throw new RtcpError.HEADER_UNDERFLOW("Data too short for ReceiverReport");
            }
            var reader = new ByteReader(data);
            try {
                uint8 b0 = reader.read_uint8();
                uint8 pt = reader.read_uint8();
                uint16 len_words = reader.read_uint16_be();

                if (pt != (uint8) PacketType.RECEIVER_REPORT) {
                    throw new RtcpError.MALFORMED_PACKET("Not a Receiver Report packet");
                }

                uint8 rc = (uint8) (b0 & 0x1F);
                var rr = new ReceiverReport();
                rr.ssrc = reader.read_uint32_be();

                for (int i = 0; i < rc; i++) {
                    rr.report_blocks.add(ReceptionReportBlock.parse(reader));
                }

                return rr;
            } catch (ReaderError e) {
                throw new RtcpError.HEADER_UNDERFLOW("Underflow parsing ReceiverReport: %s".printf(e.message));
            }
        }
    }
}
