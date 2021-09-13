/*
 * Solas: Real-Time WebRTC Media Engine
 * RTP Packet Parser and Serializer (RFC 3550 / RFC 8285)
 */

using Solas.Core;

namespace Solas.Protocol.Rtp {

    public errordomain RtpError {
        HEADER_UNDERFLOW,
        INVALID_VERSION,
        MALFORMED_EXTENSION,
        MALFORMED_PAYLOAD
    }

    public class RtpPacket : Object {
        public uint8 version { get; set; }
        public bool padding { get; set; }
        public bool extension { get; set; }
        public uint8 csrc_count { get; set; }
        public bool marker { get; set; }
        public uint8 payload_type { get; set; }
        public uint16 sequence_number { get; set; }
        public uint32 timestamp { get; set; }
        public uint32 ssrc { get; set; }

        public Gee.ArrayList<uint32> csrc_list { get; private set; }
        public uint16 extension_profile { get; set; }
        public Gee.ArrayList<RtpHeaderExtension> extensions { get; private set; }

        public uint8[] payload;
        public uint8 padding_bytes { get; set; }

        public RtpPacket() {
            this.version = 2;
            this.padding = false;
            this.extension = false;
            this.csrc_count = 0;
            this.marker = false;
            this.payload_type = 0;
            this.sequence_number = 0;
            this.timestamp = 0;
            this.ssrc = 0;
            this.csrc_list = new Gee.ArrayList<uint32>();
            this.extension_profile = RTP_EXTENSION_PROFILE_ONE_BYTE;
            this.extensions = new Gee.ArrayList<RtpHeaderExtension>();
            this.payload = new uint8[0];
            this.padding_bytes = 0;
        }

        public void add_extension(RtpHeaderExtension ext) {
            this.extension = true;
            this.extensions.add(ext);
        }

        public RtpHeaderExtension? find_extension_by_id(uint8 id) {
            foreach (var ext in this.extensions) {
                if (ext.id == id) {
                    return ext;
                }
            }
            return null;
        }

        public uint8[] serialize() {
            var writer = new ByteWriter(1500, 64);

            /* Byte 0: V(2) | P(1) | X(1) | CC(4) */
            uint8 b0 = (uint8) (((this.version & 0x03) << 6) |
                               ((this.padding ? 1 : 0) << 5) |
                               ((this.extension ? 1 : 0) << 4) |
                               (this.csrc_list.size & 0x0F));
            writer.write_uint8(b0);

            /* Byte 1: M(1) | PT(7) */
            uint8 b1 = (uint8) (((this.marker ? 1 : 0) << 7) | (this.payload_type & 0x7F));
            writer.write_uint8(b1);

            writer.write_uint16_be(this.sequence_number);
            writer.write_uint32_be(this.timestamp);
            writer.write_uint32_be(this.ssrc);

            /* CSRC list */
            foreach (uint32 csrc in this.csrc_list) {
                writer.write_uint32_be(csrc);
            }

            /* Header Extensions */
            if (this.extension && !this.extensions.is_empty) {
                writer.write_uint16_be(this.extension_profile);

                /* Serialize extensions into temporary buffer to compute length in 32-bit words */
                var ext_writer = new ByteWriter(256);
                foreach (var ext in this.extensions) {
                    if (this.extension_profile == RTP_EXTENSION_PROFILE_ONE_BYTE) {
                        /* One-byte extension: ID (4 bits) | Len - 1 (4 bits) */
                        uint8 len_val = (uint8) (ext.data.length - 1);
                        uint8 hdr = (uint8) (((ext.id & 0x0F) << 4) | (len_val & 0x0F));
                        ext_writer.write_uint8(hdr);
                        ext_writer.write_bytes(ext.data);
                    }
                }

                /* Pad extension to multiple of 4 bytes */
                size_t pad = (4 - (ext_writer.size % 4)) % 4;
                if (pad > 0) {
                    ext_writer.write_zero_padding(pad);
                }

                uint16 words = (uint16) (ext_writer.size / 4);
                writer.write_uint16_be(words);
                writer.write_bytes(ext_writer.to_array());
            }

            /* Payload */
            writer.write_bytes(this.payload);

            /* Padding */
            if (this.padding && this.padding_bytes > 0) {
                if (this.padding_bytes > 1) {
                    writer.write_zero_padding(this.padding_bytes - 1);
                }
                writer.write_uint8(this.padding_bytes);
            }

            return writer.to_array();
        }

        public static RtpPacket parse(uint8[] data) throws RtpError {
            if (data.length < 12) {
                throw new RtpError.HEADER_UNDERFLOW("Packet size %u is smaller than 12-byte RTP header".printf((uint) data.length));
            }

            var reader = new ByteReader(data);
            try {
                uint8 b0 = reader.read_uint8();
                uint8 b1 = reader.read_uint8();

                var pkt = new RtpPacket();
                pkt.version = (uint8) ((b0 >> 6) & 0x03);
                if (pkt.version != 2) {
                    throw new RtpError.INVALID_VERSION("Unsupported RTP version: %u".printf((uint) pkt.version));
                }

                pkt.padding = ((b0 & 0x20) != 0);
                pkt.extension = ((b0 & 0x10) != 0);
                pkt.csrc_count = (uint8) (b0 & 0x0F);

                pkt.marker = ((b1 & 0x80) != 0);
                pkt.payload_type = (uint8) (b1 & 0x7F);

                pkt.sequence_number = reader.read_uint16_be();
                pkt.timestamp = reader.read_uint32_be();
                pkt.ssrc = reader.read_uint32_be();

                /* Read CSRCs */
                for (int i = 0; i < pkt.csrc_count; i++) {
                    pkt.csrc_list.add(reader.read_uint32_be());
                }

                /* Read Header Extensions */
                if (pkt.extension) {
                    pkt.extension_profile = reader.read_uint16_be();
                    uint16 ext_words = reader.read_uint16_be();
                    size_t ext_bytes = (size_t) ext_words * 4;

                    if (reader.remaining < ext_bytes) {
                        throw new RtpError.MALFORMED_EXTENSION("Header extension claims %u bytes but only %u remain".printf(
                            (uint) ext_bytes, (uint) reader.remaining));
                    }

                    size_t start_ext_pos = reader.offset;
                    if (pkt.extension_profile == RTP_EXTENSION_PROFILE_ONE_BYTE) {
                        while (reader.offset < start_ext_pos + ext_bytes) {
                            uint8 b = reader.read_uint8();
                            if (b == 0) continue; /* Padding byte */

                            uint8 id = (uint8) ((b >> 4) & 0x0F);
                            uint8 len = (uint8) ((b & 0x0F) + 1); /* RFC 8285: len = 1 + value */

                            if (id == 15) {
                                /* ID 15 marks special stop symbol */
                                break;
                            }

                            if (reader.offset + len > start_ext_pos + ext_bytes) {
                                break;
                            }

                            uint8[] ext_data = reader.read_bytes(len);
                            pkt.extensions.add(new RtpHeaderExtension(id, ext_data));
                        }
                    }

                    /* Align reader to end of extensions */
                    reader.seek(start_ext_pos + ext_bytes);
                }

                /* Calculate payload and padding */
                size_t payload_len = reader.remaining;
                if (pkt.padding && payload_len > 0) {
                    pkt.padding_bytes = data[data.length - 1];
                    if (pkt.padding_bytes <= payload_len) {
                        payload_len -= pkt.padding_bytes;
                    }
                }

                pkt.payload = reader.read_bytes(payload_len);
                return pkt;

            } catch (ReaderError e) {
                throw new RtpError.HEADER_UNDERFLOW("Underflow reading RTP packet: %s".printf(e.message));
            }
        }
    }
}
