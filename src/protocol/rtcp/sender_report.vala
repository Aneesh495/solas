/*
 * Solas: Real-Time WebRTC Media Engine
 * RTCP Sender Report (SR) and Reception Report Blocks (RFC 3550)
 */

using Solas.Core;

namespace Solas.Protocol.Rtcp {

    public class ReceptionReportBlock : Object {
        public uint32 ssrc { get; set; }
        public uint8 fraction_lost { get; set; }
        public int32 cumulative_lost { get; set; }
        public uint32 highest_seq_received { get; set; }
        public uint32 interarrival_jitter { get; set; }
        public uint32 last_sr { get; set; }
        public uint32 delay_since_last_sr { get; set; }

        public ReceptionReportBlock(uint32 ssrc = 0) {
            this.ssrc = ssrc;
            this.fraction_lost = 0;
            this.cumulative_lost = 0;
            this.highest_seq_received = 0;
            this.interarrival_jitter = 0;
            this.last_sr = 0;
            this.delay_since_last_sr = 0;
        }

        public void serialize(ByteWriter writer) {
            writer.write_uint32_be(this.ssrc);
            writer.write_uint8(this.fraction_lost);
            writer.write_uint24_be((uint32) (this.cumulative_lost & 0x00FFFFFF));
            writer.write_uint32_be(this.highest_seq_received);
            writer.write_uint32_be(this.interarrival_jitter);
            writer.write_uint32_be(this.last_sr);
            writer.write_uint32_be(this.delay_since_last_sr);
        }

        public static ReceptionReportBlock parse(ByteReader reader) throws RtcpError {
            try {
                var rb = new ReceptionReportBlock();
                rb.ssrc = reader.read_uint32_be();
                rb.fraction_lost = reader.read_uint8();
                uint32 cum = reader.read_uint24_be();
                if ((cum & 0x00800000) != 0) {
                    cum |= 0xFF000000U; /* Sign extension for 24-bit signed int */
                }
                rb.cumulative_lost = (int32) cum;
                rb.highest_seq_received = reader.read_uint32_be();
                rb.interarrival_jitter = reader.read_uint32_be();
                rb.last_sr = reader.read_uint32_be();
                rb.delay_since_last_sr = reader.read_uint32_be();
                return rb;
            } catch (ReaderError e) {
                throw new RtcpError.HEADER_UNDERFLOW("Underflow reading ReceptionReportBlock: %s".printf(e.message));
            }
        }
    }

    public class SenderReport : RtcpPacket {
        public uint32 ssrc { get; set; }
        public uint64 ntp_timestamp { get; set; }
        public uint32 rtp_timestamp { get; set; }
        public uint32 packet_count { get; set; }
        public uint32 octet_count { get; set; }
        public Gee.ArrayList<ReceptionReportBlock> report_blocks { get; private set; }

        public SenderReport(uint32 ssrc = 0) {
            Object(packet_type: PacketType.SENDER_REPORT);
            this.ssrc = ssrc;
            this.ntp_timestamp = 0;
            this.rtp_timestamp = 0;
            this.packet_count = 0;
            this.octet_count = 0;
            this.report_blocks = new Gee.ArrayList<ReceptionReportBlock>();
        }

        public override void serialize(ByteWriter writer) {
            uint8 count = (uint8) (this.report_blocks.size & 0x1F);
            uint8 b0 = (uint8) (0x80 | count); /* V=2, P=0 */
            writer.write_uint8(b0);
            writer.write_uint8((uint8) PacketType.SENDER_REPORT);

            /* Length = (28 bytes sender info + 24 * report_blocks) / 4 - 1 */
            uint16 len_words = (uint16) ((28 + this.report_blocks.size * 24) / 4 - 1);
            writer.write_uint16_be(len_words);

            writer.write_uint32_be(this.ssrc);
            writer.write_uint64_be(this.ntp_timestamp);
            writer.write_uint32_be(this.rtp_timestamp);
            writer.write_uint32_be(this.packet_count);
            writer.write_uint32_be(this.octet_count);

            foreach (var rb in this.report_blocks) {
                rb.serialize(writer);
            }
        }

        public static SenderReport parse(uint8[] data) throws RtcpError {
            if (data.length < 28) {
                throw new RtcpError.HEADER_UNDERFLOW("Data too short for SenderReport");
            }
            var reader = new ByteReader(data);
            try {
                uint8 b0 = reader.read_uint8();
                uint8 pt = reader.read_uint8();
                uint16 len_words = reader.read_uint16_be();

                if (pt != (uint8) PacketType.SENDER_REPORT) {
                    throw new RtcpError.MALFORMED_PACKET("Not a Sender Report packet");
                }

                uint8 rc = (uint8) (b0 & 0x1F);
                var sr = new SenderReport();
                sr.ssrc = reader.read_uint32_be();
                sr.ntp_timestamp = reader.read_uint64_be();
                sr.rtp_timestamp = reader.read_uint32_be();
                sr.packet_count = reader.read_uint32_be();
                sr.octet_count = reader.read_uint32_be();

                for (int i = 0; i < rc; i++) {
                    sr.report_blocks.add(ReceptionReportBlock.parse(reader));
                }

                return sr;
            } catch (ReaderError e) {
                throw new RtcpError.HEADER_UNDERFLOW("Underflow parsing SenderReport: %s".printf(e.message));
            }
        }
    }
}
