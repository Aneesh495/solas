/*
 * Solas: Real-Time WebRTC Media Engine
 * STUN Message Encoder and Decoder (RFC 5389 / RFC 8489)
 */

using Solas.Core;
using Solas.Crypto;

namespace Solas.Protocol.Stun {

    public class StunMessage : Object {
        public MessageType message_type { get; set; }
        public uint8[] transaction_id;
        public Gee.ArrayList<StunAttribute> attributes { get; private set; }

        public StunMessage(MessageType type = MessageType.BINDING_REQUEST) {
            this.message_type = type;
            this.transaction_id = new uint8[STUN_TRANSACTION_ID_LENGTH];
            this.attributes = new Gee.ArrayList<StunAttribute>();
        }

        public static StunMessage create_binding_request() {
            var msg = new StunMessage(MessageType.BINDING_REQUEST);
            try {
                uint8[] tid = Engine.random_bytes(STUN_TRANSACTION_ID_LENGTH);
                Memory.copy(msg.transaction_id, tid, STUN_TRANSACTION_ID_LENGTH);
            } catch (CryptoError e) {
                Logger.error("STUN", "Failed to generate random transaction ID: %s", e.message);
            }
            return msg;
        }

        public static StunMessage create_binding_response(StunMessage request, string mapped_ip, uint16 mapped_port) {
            var res = new StunMessage(MessageType.BINDING_SUCCESS_RESPONSE);
            Memory.copy(res.transaction_id, request.transaction_id, STUN_TRANSACTION_ID_LENGTH);
            res.add_attribute(new XorMappedAddressAttribute(mapped_ip, mapped_port));
            return res;
        }

        public void add_attribute(StunAttribute attr) {
            this.attributes.add(attr);
        }

        public T? get_attribute<T>() {
            foreach (var attr in this.attributes) {
                if (attr is T) {
                    return (T) attr;
                }
            }
            return null;
        }

        /**
         * Serializes the STUN message into a byte array, optionally signing with
         * MESSAGE-INTEGRITY (HMAC-SHA1) and appending CRC32 FINGERPRINT.
         */
        public uint8[] serialize(uint8[]? integrity_key = null, bool add_fingerprint = true) throws CryptoError {
            var writer = new ByteWriter(512);

            /* Fixed STUN 20-byte Header */
            writer.write_uint16_be((uint16) this.message_type);
            writer.write_uint16_be(0); /* Placeholder for message length (excluding 20-byte header) */
            writer.write_uint32_be(STUN_MAGIC_COOKIE);
            writer.write_bytes(this.transaction_id);

            /* Serialize regular attributes */
            foreach (var attr in this.attributes) {
                if (!(attr is MessageIntegrityAttribute) && !(attr is FingerprintAttribute)) {
                    attr.serialize(writer, this.transaction_id);
                }
            }

            /* If integrity key is provided, compute and append MESSAGE-INTEGRITY */
            if (integrity_key != null) {
                /* Length in header must reflect up to end of MESSAGE-INTEGRITY attribute */
                size_t payload_len_for_mi = writer.size - STUN_HEADER_LENGTH + 24; /* 4 attr hdr + 20 hmac */
                uint8[] bytes_for_mi = writer.to_array();
                bytes_for_mi[2] = (uint8) ((payload_len_for_mi >> 8) & 0xFF);
                bytes_for_mi[3] = (uint8) (payload_len_for_mi & 0xFF);

                uint8[] hmac = Engine.hmac_sha1(integrity_key, bytes_for_mi);
                var mi_attr = new MessageIntegrityAttribute(hmac);
                mi_attr.serialize(writer, this.transaction_id);
            }

            /* If fingerprint requested, compute and append FINGERPRINT */
            if (add_fingerprint) {
                /* Length in header must reflect the entire message including FINGERPRINT */
                size_t total_payload_len = writer.size - STUN_HEADER_LENGTH + 8; /* 4 attr hdr + 4 fp */
                uint8[] bytes_for_fp = writer.to_array();
                bytes_for_fp[2] = (uint8) ((total_payload_len >> 8) & 0xFF);
                bytes_for_fp[3] = (uint8) (total_payload_len & 0xFF);

                uint32 fp = Engine.stun_fingerprint(bytes_for_fp);
                var fp_attr = new FingerprintAttribute(fp);
                fp_attr.serialize(writer, this.transaction_id);
            }

            /* Final length update */
            uint8[] final_bytes = writer.to_array();
            size_t final_payload_len = final_bytes.length - STUN_HEADER_LENGTH;
            final_bytes[2] = (uint8) ((final_payload_len >> 8) & 0xFF);
            final_bytes[3] = (uint8) (final_payload_len & 0xFF);

            return final_bytes;
        }

        /**
         * Parses a raw STUN packet from a byte array.
         */
        public static StunMessage parse(uint8[] data) throws StunError {
            if (data.length < STUN_HEADER_LENGTH) {
                throw new StunError.MALFORMED_HEADER("Data too short for STUN header (%u bytes)".printf((uint) data.length));
            }

            var reader = new ByteReader(data);
            try {
                uint16 type_val = reader.read_uint16_be();
                uint16 msg_len = reader.read_uint16_be();
                uint32 magic = reader.read_uint32_be();

                if (magic != STUN_MAGIC_COOKIE) {
                    throw new StunError.INVALID_MAGIC_COOKIE("Invalid STUN magic cookie: 0x%08X".printf(magic));
                }

                if (data.length < STUN_HEADER_LENGTH + msg_len) {
                    throw new StunError.MALFORMED_HEADER("STUN packet truncated (expected %u, got %u)".printf(
                        (uint) (STUN_HEADER_LENGTH + msg_len), (uint) data.length));
                }

                var msg = new StunMessage((MessageType) type_val);
                msg.transaction_id = reader.read_bytes(STUN_TRANSACTION_ID_LENGTH);

                size_t bytes_read = 0;
                while (bytes_read < msg_len) {
                    uint16 attr_type = reader.read_uint16_be();
                    uint16 attr_len = reader.read_uint16_be();

                    switch ((AttributeType) attr_type) {
                        case AttributeType.XOR_MAPPED_ADDRESS:
                            var xor_attr = XorMappedAddressAttribute.parse(reader, attr_len, msg.transaction_id);
                            msg.add_attribute(xor_attr);
                            break;

                        case AttributeType.USERNAME:
                            var user_attr = UsernameAttribute.parse(reader, attr_len);
                            msg.add_attribute(user_attr);
                            break;

                        case AttributeType.PRIORITY:
                            var prio_attr = PriorityAttribute.parse(reader);
                            msg.add_attribute(prio_attr);
                            break;

                        case AttributeType.USE_CANDIDATE:
                            msg.add_attribute(UseCandidateAttribute.parse());
                            break;

                        case AttributeType.MESSAGE_INTEGRITY:
                            uint8[] hmac = reader.read_bytes(20);
                            msg.add_attribute(new MessageIntegrityAttribute(hmac));
                            break;

                        case AttributeType.FINGERPRINT:
                            uint32 fp = reader.read_uint32_be();
                            msg.add_attribute(new FingerprintAttribute(fp));
                            break;

                        default:
                            /* Unknown or unhandled attribute: skip with 4-byte padding */
                            reader.skip(attr_len);
                            size_t pad = (4 - (attr_len % 4)) % 4;
                            if (pad > 0) {
                                reader.skip(pad);
                            }
                            break;
                    }

                    size_t full_attr_len = 4 + attr_len + ((4 - (attr_len % 4)) % 4);
                    bytes_read += full_attr_len;
                }

                return msg;
            } catch (ReaderError e) {
                throw new StunError.ATTRIBUTE_UNDERFLOW("Underflow during STUN parsing: %s".printf(e.message));
            }
        }
    }
}
