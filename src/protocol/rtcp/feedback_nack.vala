/*
 * Solas: Real-Time WebRTC Media Engine
 * Generic NACK Feedback Packet (RFC 4585 FMT=1)
 */

using Solas.Core;

namespace Solas.Protocol.Rtcp {

    public class NackEntry : Object {
        public uint16 packet_id { get; set; }
        public uint16 bitmask_lost { get; set; }

        public NackEntry(uint16 pid, uint16 blp = 0) {
            this.packet_id = pid;
            this.bitmask_lost = blp;
        }
    }

    public class GenericNack : RtcpPacket {
        public uint32 sender_ssrc { get; set; }
        public uint32 media_ssrc { get; set; }
        public Gee.ArrayList<NackEntry> nack_list { get; private set; }

        public GenericNack(uint32 sender_ssrc = 0, uint32 media_ssrc = 0) {
            Object(packet_type: PacketType.TRANSPORT_FEEDBACK);
            this.count_or_format = (uint8) TransportFeedbackFormat.GENERIC_NACK;
            this.sender_ssrc = sender_ssrc;
            this.media_ssrc = media_ssrc;
            this.nack_list = new Gee.ArrayList<NackEntry>();
        }

        public void add_lost_sequence(uint16 seq) {
            if (!this.nack_list.is_empty) {
                var last = this.nack_list.get(this.nack_list.size - 1);
                int delta = (int) (seq - last.packet_id);
                if (delta > 0 && delta <= 16) {
                    last.bitmask_lost |= (uint16) (1 << (delta - 1));
                    return;
                }
            }
            this.nack_list.add(new NackEntry(seq, 0));
        }

        public Gee.ArrayList<uint16> get_lost_sequence_numbers() {
            var res = new Gee.ArrayList<uint16>();
            foreach (var entry in this.nack_list) {
                res.add(entry.packet_id);
                for (int i = 0; i < 16; i++) {
                    if ((entry.bitmask_lost & (1 << i)) != 0) {
                        res.add((uint16) (entry.packet_id + i + 1));
                    }
                }
            }
            return res;
        }

        public override void serialize(ByteWriter writer) {
            writer.write_uint8(0x80 | (uint8) TransportFeedbackFormat.GENERIC_NACK);
            writer.write_uint8((uint8) PacketType.TRANSPORT_FEEDBACK);

            uint16 len_words = (uint16) ((12 + this.nack_list.size * 4) / 4 - 1);
            writer.write_uint16_be(len_words);

            writer.write_uint32_be(this.sender_ssrc);
            writer.write_uint32_be(this.media_ssrc);

            foreach (var entry in this.nack_list) {
                writer.write_uint16_be(entry.packet_id);
                writer.write_uint16_be(entry.bitmask_lost);
            }
        }

        public static GenericNack parse(uint8[] data) throws RtcpError {
            if (data.length < 12) {
                throw new RtcpError.HEADER_UNDERFLOW("Data too short for GenericNack");
            }
            var reader = new ByteReader(data);
            try {
                reader.skip(2); /* Skip b0, pt */
                uint16 len_words = reader.read_uint16_be();
                var nack = new GenericNack();
                nack.sender_ssrc = reader.read_uint32_be();
                nack.media_ssrc = reader.read_uint32_be();

                size_t entries = (size_t) (len_words + 1 - 3);
                for (size_t i = 0; i < entries && reader.remaining >= 4; i++) {
                    uint16 pid = reader.read_uint16_be();
                    uint16 blp = reader.read_uint16_be();
                    nack.nack_list.add(new NackEntry(pid, blp));
                }

                return nack;
            } catch (ReaderError e) {
                throw new RtcpError.HEADER_UNDERFLOW("Underflow parsing GenericNack: %s".printf(e.message));
            }
        }
    }
}
