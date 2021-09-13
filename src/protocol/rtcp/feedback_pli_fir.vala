/*
 * Solas: Real-Time WebRTC Media Engine
 * Picture Loss Indication (PLI) and Full Intra Request (FIR)
 */

using Solas.Core;

namespace Solas.Protocol.Rtcp {

    public class PictureLossIndication : RtcpPacket {
        public uint32 sender_ssrc { get; set; }
        public uint32 media_ssrc { get; set; }

        public PictureLossIndication(uint32 sender_ssrc = 0, uint32 media_ssrc = 0) {
            Object(packet_type: PacketType.PAYLOAD_FEEDBACK);
            this.count_or_format = (uint8) PayloadFeedbackFormat.PLI;
            this.sender_ssrc = sender_ssrc;
            this.media_ssrc = media_ssrc;
        }

        public override void serialize(ByteWriter writer) {
            writer.write_uint8(0x80 | (uint8) PayloadFeedbackFormat.PLI);
            writer.write_uint8((uint8) PacketType.PAYLOAD_FEEDBACK);
            writer.write_uint16_be(2); /* 12 bytes = 3 words, len = 2 */
            writer.write_uint32_be(this.sender_ssrc);
            writer.write_uint32_be(this.media_ssrc);
        }

        public static PictureLossIndication parse(uint8[] data) throws RtcpError {
            if (data.length < 12) {
                throw new RtcpError.HEADER_UNDERFLOW("Data too short for PLI");
            }
            var reader = new ByteReader(data);
            try {
                reader.skip(4);
                var pli = new PictureLossIndication();
                pli.sender_ssrc = reader.read_uint32_be();
                pli.media_ssrc = reader.read_uint32_be();
                return pli;
            } catch (ReaderError e) {
                throw new RtcpError.HEADER_UNDERFLOW("Underflow reading PLI: %s".printf(e.message));
            }
        }
    }

    public class FirEntry : Object {
        public uint32 ssrc { get; set; }
        public uint8 seq_nr { get; set; }

        public FirEntry(uint32 ssrc, uint8 seq) {
            this.ssrc = ssrc;
            this.seq_nr = seq;
        }
    }

    public class FullIntraRequest : RtcpPacket {
        public uint32 sender_ssrc { get; set; }
        public Gee.ArrayList<FirEntry> entries { get; private set; }

        public FullIntraRequest(uint32 sender_ssrc = 0) {
            Object(packet_type: PacketType.PAYLOAD_FEEDBACK);
            this.count_or_format = (uint8) PayloadFeedbackFormat.FIR;
            this.sender_ssrc = sender_ssrc;
            this.entries = new Gee.ArrayList<FirEntry>();
        }

        public void add_entry(uint32 ssrc, uint8 seq) {
            this.entries.add(new FirEntry(ssrc, seq));
        }

        public override void serialize(ByteWriter writer) {
            writer.write_uint8(0x80 | (uint8) PayloadFeedbackFormat.FIR);
            writer.write_uint8((uint8) PacketType.PAYLOAD_FEEDBACK);

            uint16 len_words = (uint16) ((12 + this.entries.size * 8) / 4 - 1);
            writer.write_uint16_be(len_words);

            writer.write_uint32_be(this.sender_ssrc);
            writer.write_uint32_be(0); /* Media SSRC is 0 in FIR header */

            foreach (var e in this.entries) {
                writer.write_uint32_be(e.ssrc);
                writer.write_uint8(e.seq_nr);
                writer.write_zero_padding(3); /* 24 bits reserved */
            }
        }

        public static FullIntraRequest parse(uint8[] data) throws RtcpError {
            if (data.length < 12) {
                throw new RtcpError.HEADER_UNDERFLOW("Data too short for FIR");
            }
            var reader = new ByteReader(data);
            try {
                reader.skip(4);
                var fir = new FullIntraRequest();
                fir.sender_ssrc = reader.read_uint32_be();
                reader.skip(4); /* Skip unused media SSRC */

                while (reader.remaining >= 8) {
                    uint32 ssrc = reader.read_uint32_be();
                    uint8 seq = reader.read_uint8();
                    reader.skip(3);
                    fir.add_entry(ssrc, seq);
                }
                return fir;
            } catch (ReaderError e) {
                throw new RtcpError.HEADER_UNDERFLOW("Underflow reading FIR: %s".printf(e.message));
            }
        }
    }
}
