/*
 * Solas: Real-Time WebRTC Media Engine
 * TURN ChannelData Framing and Custom Attributes (RFC 5766)
 */

using Solas.Core;
using Solas.Protocol.Stun;

namespace Solas.Protocol.Turn {

    public class ChannelDataMessage : Object {
        public uint16 channel_number { get; set; }
        public uint8[] data;

        public ChannelDataMessage(uint16 channel, uint8[] payload) {
            this.channel_number = channel;
            this.data = payload;
        }

        public uint8[] serialize() {
            var writer = new ByteWriter(this.data.length + 4);
            writer.write_uint16_be(this.channel_number);
            writer.write_uint16_be((uint16) this.data.length);
            writer.write_bytes(this.data);

            /* ChannelData is padded to 4-byte boundaries */
            size_t pad = (4 - (this.data.length % 4)) % 4;
            if (pad > 0) {
                writer.write_zero_padding(pad);
            }

            return writer.to_array();
        }

        public static ChannelDataMessage? parse(uint8[] packet) {
            if (packet.length < 4) return null;

            var reader = new ByteReader(packet);
            try {
                uint16 ch = reader.read_uint16_be();
                if (ch < MIN_CHANNEL_NUMBER || ch > MAX_CHANNEL_NUMBER) {
                    return null;
                }

                uint16 len = reader.read_uint16_be();
                if (reader.remaining < len) return null;

                uint8[] payload = reader.read_bytes(len);
                return new ChannelDataMessage(ch, payload);
            } catch (ReaderError e) {
                return null;
            }
        }
    }

    public class LifetimeAttribute : StunAttribute {
        public uint32 lifetime_seconds { get; set; }

        public LifetimeAttribute(uint32 seconds = DEFAULT_LIFETIME_SECONDS) {
            Object(attr_type: (AttributeType) TurnAttributeType.LIFETIME);
            this.lifetime_seconds = seconds;
        }

        public override void serialize(ByteWriter writer, uint8[] transaction_id) {
            writer.write_uint16_be((uint16) TurnAttributeType.LIFETIME);
            writer.write_uint16_be(4);
            writer.write_uint32_be(this.lifetime_seconds);
        }

        public static LifetimeAttribute parse(ByteReader reader) throws ReaderError {
            uint32 s = reader.read_uint32_be();
            return new LifetimeAttribute(s);
        }
    }

    public class ChannelNumberAttribute : StunAttribute {
        public uint16 channel_number { get; set; }

        public ChannelNumberAttribute(uint16 channel) {
            Object(attr_type: (AttributeType) TurnAttributeType.CHANNEL_NUMBER);
            this.channel_number = channel;
        }

        public override void serialize(ByteWriter writer, uint8[] transaction_id) {
            writer.write_uint16_be((uint16) TurnAttributeType.CHANNEL_NUMBER);
            writer.write_uint16_be(4);
            writer.write_uint16_be(this.channel_number);
            writer.write_uint16_be(0x0000); /* Reserved RFFU */
        }

        public static ChannelNumberAttribute parse(ByteReader reader) throws ReaderError {
            uint16 ch = reader.read_uint16_be();
            reader.skip(2); /* Skip RFFU */
            return new ChannelNumberAttribute(ch);
        }
    }

    public class DataAttribute : StunAttribute {
        public uint8[] data;

        public DataAttribute(uint8[] payload) {
            Object(attr_type: (AttributeType) TurnAttributeType.DATA);
            this.data = payload;
        }

        public override void serialize(ByteWriter writer, uint8[] transaction_id) {
            writer.write_uint16_be((uint16) TurnAttributeType.DATA);
            writer.write_uint16_be((uint16) this.data.length);
            writer.write_bytes(this.data);

            size_t pad = (4 - (this.data.length % 4)) % 4;
            if (pad > 0) {
                writer.write_zero_padding(pad);
            }
        }
    }
}
