/*
 * Solas: Real-Time WebRTC Media Engine
 * STUN Attribute Models and Serializers (RFC 5389)
 */

using Solas.Core;
using Solas.Crypto;

namespace Solas.Protocol.Stun {

    public abstract class StunAttribute : Object {
        public AttributeType attr_type { get; construct; }

        public abstract void serialize(ByteWriter writer, uint8[] transaction_id);
    }

    public class XorMappedAddressAttribute : StunAttribute {
        public AddressFamily family { get; set; }
        public uint16 port { get; set; }
        public string address { get; set; }

        public XorMappedAddressAttribute(string address, uint16 port, AddressFamily family = AddressFamily.IPV4) {
            Object(attr_type: AttributeType.XOR_MAPPED_ADDRESS);
            this.address = address;
            this.port = port;
            this.family = family;
        }

        public override void serialize(ByteWriter writer, uint8[] transaction_id) {
            writer.write_uint16_be((uint16) AttributeType.XOR_MAPPED_ADDRESS);

            if (this.family == AddressFamily.IPV4) {
                writer.write_uint16_be(8); /* Length of attribute value */
                writer.write_uint8(0x00);  /* Reserved */
                writer.write_uint8((uint8) AddressFamily.IPV4);

                /* Port XOR'd with most significant 16 bits of magic cookie */
                uint16 xor_port = (uint16) (this.port ^ ((uint16) (STUN_MAGIC_COOKIE >> 16)));
                writer.write_uint16_be(xor_port);

                /* IPv4 address XOR'd with magic cookie */
                uint32 ip_num = parse_ipv4(this.address);
                uint32 xor_ip = ip_num ^ STUN_MAGIC_COOKIE;
                writer.write_uint32_be(xor_ip);
            }
        }

        public static XorMappedAddressAttribute parse(ByteReader reader, uint16 length, uint8[] transaction_id) throws StunError {
            try {
                reader.skip(1); /* Skip reserved byte */
                uint8 fam = reader.read_uint8();
                if (fam != (uint8) AddressFamily.IPV4) {
                    throw new StunError.UNSUPPORTED_FAMILY("Only IPv4 XOR mapped address currently supported");
                }

                uint16 xor_port = reader.read_uint16_be();
                uint16 port = (uint16) (xor_port ^ ((uint16) (STUN_MAGIC_COOKIE >> 16)));

                uint32 xor_ip = reader.read_uint32_be();
                uint32 ip_num = xor_ip ^ STUN_MAGIC_COOKIE;

                string ip_str = format_ipv4(ip_num);
                return new XorMappedAddressAttribute(ip_str, port, AddressFamily.IPV4);
            } catch (ReaderError e) {
                throw new StunError.ATTRIBUTE_UNDERFLOW("Underflow parsing XOR_MAPPED_ADDRESS: %s".printf(e.message));
            }
        }

        private static uint32 parse_ipv4(string ip) {
            string[] parts = ip.split(".");
            if (parts.length != 4) return 0;
            uint32 n0 = (uint32) int.parse(parts[0]);
            uint32 n1 = (uint32) int.parse(parts[1]);
            uint32 n2 = (uint32) int.parse(parts[2]);
            uint32 n3 = (uint32) int.parse(parts[3]);
            return (n0 << 24) | (n1 << 16) | (n2 << 8) | n3;
        }

        private static string format_ipv4(uint32 ip) {
            uint8 b0 = (uint8) ((ip >> 24) & 0xFF);
            uint8 b1 = (uint8) ((ip >> 16) & 0xFF);
            uint8 b2 = (uint8) ((ip >> 8) & 0xFF);
            uint8 b3 = (uint8) (ip & 0xFF);
            return "%u.%u.%u.%u".printf((uint) b0, (uint) b1, (uint) b2, (uint) b3);
        }
    }

    public class UsernameAttribute : StunAttribute {
        public string username { get; set; }

        public UsernameAttribute(string username) {
            Object(attr_type: AttributeType.USERNAME);
            this.username = username;
        }

        public override void serialize(ByteWriter writer, uint8[] transaction_id) {
            writer.write_uint16_be((uint16) AttributeType.USERNAME);
            writer.write_uint16_be((uint16) this.username.length);
            writer.write_string(this.username);

            /* Attributes are padded to 4-byte boundaries */
            size_t pad = (4 - (this.username.length % 4)) % 4;
            if (pad > 0) {
                writer.write_zero_padding(pad);
            }
        }

        public static UsernameAttribute parse(ByteReader reader, uint16 length) throws StunError {
            try {
                string val = reader.read_string(length);
                size_t pad = (4 - (length % 4)) % 4;
                if (pad > 0) {
                    reader.skip(pad);
                }
                return new UsernameAttribute(val);
            } catch (ReaderError e) {
                throw new StunError.ATTRIBUTE_UNDERFLOW("Underflow reading USERNAME: %s".printf(e.message));
            }
        }
    }

    public class PriorityAttribute : StunAttribute {
        public uint32 priority { get; set; }

        public PriorityAttribute(uint32 priority) {
            Object(attr_type: AttributeType.PRIORITY);
            this.priority = priority;
        }

        public override void serialize(ByteWriter writer, uint8[] transaction_id) {
            writer.write_uint16_be((uint16) AttributeType.PRIORITY);
            writer.write_uint16_be(4);
            writer.write_uint32_be(this.priority);
        }

        public static PriorityAttribute parse(ByteReader reader) throws StunError {
            try {
                uint32 prio = reader.read_uint32_be();
                return new PriorityAttribute(prio);
            } catch (ReaderError e) {
                throw new StunError.ATTRIBUTE_UNDERFLOW("Underflow reading PRIORITY: %s".printf(e.message));
            }
        }
    }

    public class UseCandidateAttribute : StunAttribute {
        public UseCandidateAttribute() {
            Object(attr_type: AttributeType.USE_CANDIDATE);
        }

        public override void serialize(ByteWriter writer, uint8[] transaction_id) {
            writer.write_uint16_be((uint16) AttributeType.USE_CANDIDATE);
            writer.write_uint16_be(0);
        }

        public static UseCandidateAttribute parse() {
            return new UseCandidateAttribute();
        }
    }

    public class MessageIntegrityAttribute : StunAttribute {
        public uint8[] hmac;

        public MessageIntegrityAttribute(uint8[] hmac) {
            Object(attr_type: AttributeType.MESSAGE_INTEGRITY);
            this.hmac = hmac;
        }

        public override void serialize(ByteWriter writer, uint8[] transaction_id) {
            writer.write_uint16_be((uint16) AttributeType.MESSAGE_INTEGRITY);
            writer.write_uint16_be(20); /* HMAC-SHA1 is 20 bytes */
            writer.write_bytes(this.hmac);
        }
    }

    public class FingerprintAttribute : StunAttribute {
        public uint32 fingerprint { get; set; }

        public FingerprintAttribute(uint32 fingerprint) {
            Object(attr_type: AttributeType.FINGERPRINT);
            this.fingerprint = fingerprint;
        }

        public override void serialize(ByteWriter writer, uint8[] transaction_id) {
            writer.write_uint16_be((uint16) AttributeType.FINGERPRINT);
            writer.write_uint16_be(4);
            writer.write_uint32_be(this.fingerprint);
        }
    }
}
