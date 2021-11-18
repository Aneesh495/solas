/*
 * Solas: Real-Time WebRTC Media Engine
 * WebRTC DataChannel Session and DCEP Protocol Handler (RFC 8831 / RFC 8832)
 */

using Solas.Core;

namespace Solas.Protocol.Sctp {

    public class DcepOpenMessage : Object {
        public DataChannelChannelType channel_type { get; set; }
        public uint16 priority { get; set; }
        public uint32 reliability_param { get; set; }
        public string label { get; set; }
        public string protocol { get; set; }

        public DcepOpenMessage(string label = "", string protocol = "",
                               DataChannelChannelType type = DataChannelChannelType.RELIABLE,
                               uint16 priority = 0, uint32 reliability = 0) {
            this.label = label;
            this.protocol = protocol;
            this.channel_type = type;
            this.priority = priority;
            this.reliability_param = reliability;
        }

        public uint8[] serialize() {
            uint16 label_len = (uint16) this.label.length;
            uint16 proto_len = (uint16) this.protocol.length;
            size_t total_size = 12 + label_len + proto_len;

            var writer = new ByteWriter(total_size);
            writer.write_uint8((uint8) DcepMessageType.OPEN);
            writer.write_uint8((uint8) this.channel_type);
            writer.write_uint16_be(this.priority);
            writer.write_uint32_be(this.reliability_param);
            writer.write_uint16_be(label_len);
            writer.write_uint16_be(proto_len);
            if (label_len > 0) {
                writer.write_string(this.label);
            }
            if (proto_len > 0) {
                writer.write_string(this.protocol);
            }

            return writer.to_array();
        }

        public static DcepOpenMessage parse(uint8[] payload) throws SctpError {
            if (payload.length < 12) {
                throw new SctpError.INVALID_PACKET("Truncated DCEP OPEN message header");
            }

            var reader = new ByteReader(payload);
            try {
                uint8 msg_type = reader.read_uint8();
                if (msg_type != (uint8) DcepMessageType.OPEN) {
                    throw new SctpError.INVALID_PACKET("Expected DCEP OPEN message type 0x03");
                }

                uint8 chan_type = reader.read_uint8();
                uint16 priority = reader.read_uint16_be();
                uint32 reliability = reader.read_uint32_be();
                uint16 label_len = reader.read_uint16_be();
                uint16 proto_len = reader.read_uint16_be();

                if (reader.remaining < (size_t) (label_len + proto_len)) {
                    throw new SctpError.INVALID_PACKET("DCEP label and protocol lengths exceed payload");
                }

                string label = "";
                if (label_len > 0) {
                    uint8[] label_bytes = reader.read_bytes(label_len);
                    uint8[] label_null = new uint8[label_len + 1];
                    Memory.copy(label_null, label_bytes, label_len);
                    label_null[label_len] = 0;
                    label = (string) label_null;
                }

                string proto = "";
                if (proto_len > 0) {
                    uint8[] proto_bytes = reader.read_bytes(proto_len);
                    uint8[] proto_null = new uint8[proto_len + 1];
                    Memory.copy(proto_null, proto_bytes, proto_len);
                    proto_null[proto_len] = 0;
                    proto = (string) proto_null;
                }

                return new DcepOpenMessage(label, proto, (DataChannelChannelType) chan_type, priority, reliability);
            } catch (ReaderError e) {
                throw new SctpError.INVALID_PACKET(e.message);
            }
        }
    }

    public class DcepAckMessage : Object {
        public static uint8[] serialize() {
            var writer = new ByteWriter(1);
            writer.write_uint8((uint8) DcepMessageType.ACK);
            return writer.to_array();
        }

        public static bool parse(uint8[] payload) {
            return (payload.length >= 1 && payload[0] == (uint8) DcepMessageType.ACK);
        }
    }

    public class DataChannel : Object {
        public uint16 id { get; set; }
        public string label { get; set; }
        public string protocol { get; set; }
        public DataChannelChannelType channel_type { get; set; }
        public bool is_open { get; set; }

        public signal void text_message_received(string message);
        public signal void binary_message_received(uint8[] data);

        public DataChannel(uint16 id, string label = "", string protocol = "",
                           DataChannelChannelType type = DataChannelChannelType.RELIABLE) {
            this.id = id;
            this.label = label;
            this.protocol = protocol;
            this.channel_type = type;
            this.is_open = false;
        }
    }

    public class DataChannelSession : Object {
        private Gee.HashMap<int, DataChannel> channels;
        private uint32 local_tsn;
        private uint16 local_seq;
        private uint16 local_port;
        private uint16 remote_port;

        public DataChannelSession(uint16 local_port = 5000, uint16 remote_port = 5000) {
            this.channels = new Gee.HashMap<int, DataChannel>();
            this.local_tsn = 1000;
            this.local_seq = 0;
            this.local_port = local_port;
            this.remote_port = remote_port;
        }

        public DataChannel? get_channel(uint16 id) {
            return this.channels.get((int) id);
        }

        public DataChannel register_channel(uint16 id, string label, string protocol = "",
                                            DataChannelChannelType type = DataChannelChannelType.RELIABLE) {
            var ch = new DataChannel(id, label, protocol, type);
            this.channels.set((int) id, ch);
            return ch;
        }

        /**
         * Dispatches an incoming SCTP packet, handling DCEP OPEN, ACK, string, and binary payloads.
         * Returns an optional SCTP response packet (such as a DCEP ACK).
         */
        public SctpPacket? handle_packet(SctpPacket pkt) throws SctpError {
            SctpPacket? response = null;

            foreach (var chunk in pkt.chunks) {
                if (chunk.chunk_type != SctpChunkType.DATA) {
                    continue;
                }

                var data_chunk = SctpDataChunk.parse(chunk);
                uint16 stream_id = data_chunk.stream_id;

                if (data_chunk.ppid == SctpPpid.DCEP) {
                    if (data_chunk.user_data.length > 0 && data_chunk.user_data[0] == (uint8) DcepMessageType.OPEN) {
                        var open_msg = DcepOpenMessage.parse(data_chunk.user_data);
                        var ch = this.register_channel(stream_id, open_msg.label, open_msg.protocol, open_msg.channel_type);
                        ch.is_open = true;

                        /* Generate DCEP ACK reply */
                        uint8[] ack_payload = DcepAckMessage.serialize();
                        var ack_chunk = new SctpDataChunk(this.local_tsn++, stream_id, this.local_seq++, SctpPpid.DCEP, ack_payload);
                        response = new SctpPacket(this.local_port, this.remote_port, pkt.verification_tag);
                        response.add_chunk(ack_chunk.to_chunk());
                    } else if (data_chunk.user_data.length > 0 && data_chunk.user_data[0] == (uint8) DcepMessageType.ACK) {
                        var ch = this.get_channel(stream_id);
                        if (ch != null) {
                            ch.is_open = true;
                        }
                    }
                } else if (data_chunk.ppid == SctpPpid.STRING) {
                    var ch = this.get_channel(stream_id);
                    if (ch != null) {
                        string msg = (string) data_chunk.user_data;
                        ch.text_message_received(msg);
                    }
                } else if (data_chunk.ppid == SctpPpid.BINARY) {
                    var ch = this.get_channel(stream_id);
                    if (ch != null) {
                        ch.binary_message_received(data_chunk.user_data);
                    }
                }
            }

            return response;
        }

        public SctpPacket create_open_packet(uint16 stream_id, string label, string protocol = "",
                                             DataChannelChannelType type = DataChannelChannelType.RELIABLE) {
            this.register_channel(stream_id, label, protocol, type);
            var open_msg = new DcepOpenMessage(label, protocol, type);
            uint8[] open_wire = open_msg.serialize();

            var data_chunk = new SctpDataChunk(this.local_tsn++, stream_id, this.local_seq++, SctpPpid.DCEP, open_wire);
            var pkt = new SctpPacket(this.local_port, this.remote_port, 0x12345678);
            pkt.add_chunk(data_chunk.to_chunk());
            return pkt;
        }

        public SctpPacket send_text(uint16 stream_id, string text) {
            uint8[] bytes = new uint8[text.length + 1];
            Memory.copy(bytes, (uint8[]) text, text.length);
            bytes[text.length] = 0;

            var data_chunk = new SctpDataChunk(this.local_tsn++, stream_id, this.local_seq++, SctpPpid.STRING, bytes);
            var pkt = new SctpPacket(this.local_port, this.remote_port, 0x12345678);
            pkt.add_chunk(data_chunk.to_chunk());
            return pkt;
        }

        public SctpPacket send_binary(uint16 stream_id, uint8[] data) {
            var data_chunk = new SctpDataChunk(this.local_tsn++, stream_id, this.local_seq++, SctpPpid.BINARY, data);
            var pkt = new SctpPacket(this.local_port, this.remote_port, 0x12345678);
            pkt.add_chunk(data_chunk.to_chunk());
            return pkt;
        }
    }
}
