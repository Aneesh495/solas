/*
 * Solas: Real-Time WebRTC Media Engine
 * Base RTCP Packet and Compound Packet Demultiplexer (RFC 3550)
 */

using Solas.Core;

namespace Solas.Protocol.Rtcp {

    public abstract class RtcpPacket : Object {
        public uint8 version { get; set; default = 2; }
        public bool padding { get; set; default = false; }
        public uint8 count_or_format { get; set; default = 0; }
        public PacketType packet_type { get; construct; }

        public abstract void serialize(ByteWriter writer);
    }

    public class RtcpCompoundPacket : Object {
        public Gee.ArrayList<RtcpPacket> packets { get; private set; }

        public RtcpCompoundPacket() {
            this.packets = new Gee.ArrayList<RtcpPacket>();
        }

        public void add_packet(RtcpPacket pkt) {
            this.packets.add(pkt);
        }

        public uint8[] serialize() {
            var writer = new ByteWriter(1500);
            foreach (var pkt in this.packets) {
                pkt.serialize(writer);
            }
            return writer.to_array();
        }

        public static RtcpCompoundPacket parse(uint8[] data) throws RtcpError {
            var compound = new RtcpCompoundPacket();
            var reader = new ByteReader(data);

            while (reader.remaining >= 4) {
                size_t pkt_start = reader.offset;
                try {
                    uint8 b0 = reader.read_uint8();
                    uint8 pt = reader.read_uint8();
                    uint16 length_words = reader.read_uint16_be();
                    size_t pkt_total_bytes = (size_t) (length_words + 1) * 4;

                    if (reader.remaining < pkt_total_bytes - 4) {
                        throw new RtcpError.HEADER_UNDERFLOW("RTCP packet length %u exceeds remaining buffer %u".printf(
                            (uint) pkt_total_bytes, (uint) reader.remaining + 4));
                    }

                    uint8 fmt = (uint8) (b0 & 0x1F);
                    reader.seek(pkt_start);
                    uint8[] pkt_bytes = reader.read_bytes(pkt_total_bytes);

                    switch ((PacketType) pt) {
                        case PacketType.SENDER_REPORT:
                            compound.add_packet(SenderReport.parse(pkt_bytes));
                            break;

                        case PacketType.RECEIVER_REPORT:
                            compound.add_packet(ReceiverReport.parse(pkt_bytes));
                            break;

                        case PacketType.TRANSPORT_FEEDBACK:
                            if (fmt == (uint8) TransportFeedbackFormat.GENERIC_NACK) {
                                compound.add_packet(GenericNack.parse(pkt_bytes));
                            } else if (fmt == (uint8) TransportFeedbackFormat.TWCC) {
                                compound.add_packet(TwccFeedback.parse(pkt_bytes));
                            }
                            break;

                        case PacketType.PAYLOAD_FEEDBACK:
                            if (fmt == (uint8) PayloadFeedbackFormat.PLI) {
                                compound.add_packet(PictureLossIndication.parse(pkt_bytes));
                            } else if (fmt == (uint8) PayloadFeedbackFormat.FIR) {
                                compound.add_packet(FullIntraRequest.parse(pkt_bytes));
                            } else if (fmt == (uint8) PayloadFeedbackFormat.REMB) {
                                compound.add_packet(RembFeedback.parse(pkt_bytes));
                            }
                            break;

                        default:
                            /* Skip unhandled RTCP packet types cleanly */
                            break;
                    }
                } catch (ReaderError e) {
                    throw new RtcpError.HEADER_UNDERFLOW("Underflow reading compound RTCP: %s".printf(e.message));
                }
            }

            return compound;
        }
    }
}
