/*
 * Solas: Real-Time WebRTC Media Engine
 * SCTP Packet and Chunk Framing (RFC 4960)
 */

using Solas.Core;

namespace Solas.Protocol.Sctp {

    public class SctpChunk : Object {
        public SctpChunkType chunk_type { get; set; }
        public uint8 flags { get; set; }
        public uint8[] payload;

        public SctpChunk(SctpChunkType type, uint8 flags = 0, uint8[]? payload = null) {
            this.chunk_type = type;
            this.flags = flags;
            this.payload = (payload != null) ? payload : new uint8[0];
        }

        public size_t get_wire_size() {
            size_t unpadded = 4 + this.payload.length;
            /* 4-byte aligned */
            return (unpadded + 3) & ~3;
        }

        public void serialize(ByteWriter writer) {
            uint16 total_len = (uint16) (4 + this.payload.length);
            writer.write_uint8((uint8) this.chunk_type);
            writer.write_uint8(this.flags);
            writer.write_uint16_be(total_len);
            if (this.payload.length > 0) {
                writer.write_bytes(this.payload);
            }
            /* Add 4-byte alignment padding */
            size_t padding = (4 - (this.payload.length % 4)) % 4;
            for (size_t i = 0; i < padding; i++) {
                writer.write_uint8(0);
            }
        }

        public static SctpChunk parse(ByteReader reader) throws SctpError {
            if (reader.remaining < 4) {
                throw new SctpError.INVALID_PACKET("Truncated SCTP chunk header");
            }
            try {
                uint8 type = reader.read_uint8();
                uint8 flags = reader.read_uint8();
                uint16 len = reader.read_uint16_be();

                if (len < 4) {
                    throw new SctpError.INVALID_PACKET("Invalid SCTP chunk length: %u".printf(len));
                }

                size_t payload_len = len - 4;
                if (reader.remaining < payload_len) {
                    throw new SctpError.INVALID_PACKET("SCTP chunk payload exceeds remaining bytes");
                }

                uint8[] payload = reader.read_bytes(payload_len);

                /* Skip 4-byte alignment padding */
                size_t padding = (4 - (payload_len % 4)) % 4;
                if (reader.remaining >= padding) {
                    reader.skip(padding);
                }

                return new SctpChunk((SctpChunkType) type, flags, payload);
            } catch (ReaderError e) {
                throw new SctpError.INVALID_PACKET(e.message);
            }
        }
    }

    public class SctpDataChunk : Object {
        public uint32 tsn { get; set; }
        public uint16 stream_id { get; set; }
        public uint16 stream_seq { get; set; }
        public uint32 ppid { get; set; }
        public uint8[] user_data;

        public bool unordered { get; set; }
        public bool beginning { get; set; }
        public bool ending { get; set; }

        public SctpDataChunk(uint32 tsn, uint16 stream_id, uint16 stream_seq, uint32 ppid, uint8[] user_data) {
            this.tsn = tsn;
            this.stream_id = stream_id;
            this.stream_seq = stream_seq;
            this.ppid = ppid;
            this.user_data = user_data;
            this.unordered = false;
            this.beginning = true;
            this.ending = true;
        }

        public SctpChunk to_chunk() {
            uint8 flags = 0;
            if (this.unordered) flags |= 0x04;
            if (this.beginning) flags |= 0x02;
            if (this.ending) flags |= 0x01;

            var writer = new ByteWriter(12 + this.user_data.length);
            writer.write_uint32_be(this.tsn);
            writer.write_uint16_be(this.stream_id);
            writer.write_uint16_be(this.stream_seq);
            writer.write_uint32_be(this.ppid);
            writer.write_bytes(this.user_data);

            return new SctpChunk(SctpChunkType.DATA, flags, writer.to_array());
        }

        public static SctpDataChunk parse(SctpChunk chunk) throws SctpError {
            if (chunk.chunk_type != SctpChunkType.DATA) {
                throw new SctpError.INVALID_PACKET("Chunk is not DATA");
            }
            if (chunk.payload.length < 12) {
                throw new SctpError.INVALID_PACKET("DATA chunk payload less than 12-byte header");
            }

            var reader = new ByteReader(chunk.payload);
            try {
                uint32 tsn = reader.read_uint32_be();
                uint16 stream_id = reader.read_uint16_be();
                uint16 stream_seq = reader.read_uint16_be();
                uint32 ppid = reader.read_uint32_be();

                size_t data_len = chunk.payload.length - 12;
                uint8[] user_data = reader.read_bytes(data_len);

                var dc = new SctpDataChunk(tsn, stream_id, stream_seq, ppid, user_data);
                dc.unordered = (chunk.flags & 0x04) != 0;
                dc.beginning = (chunk.flags & 0x02) != 0;
                dc.ending = (chunk.flags & 0x01) != 0;

                return dc;
            } catch (ReaderError e) {
                throw new SctpError.INVALID_PACKET(e.message);
            }
        }
    }

    public class SctpPacket : Object {
        public const size_t COMMON_HEADER_LEN = 12;

        public uint16 src_port { get; set; }
        public uint16 dst_port { get; set; }
        public uint32 verification_tag { get; set; }
        public uint32 checksum { get; set; }
        public Gee.ArrayList<SctpChunk> chunks;

        public SctpPacket(uint16 src_port = 5000, uint16 dst_port = 5000, uint32 vtag = 0) {
            this.src_port = src_port;
            this.dst_port = dst_port;
            this.verification_tag = vtag;
            this.checksum = 0;
            this.chunks = new Gee.ArrayList<SctpChunk>();
        }

        public void add_chunk(SctpChunk chunk) {
            this.chunks.add(chunk);
        }

        public uint8[] serialize() {
            size_t total_size = COMMON_HEADER_LEN;
            foreach (var chunk in this.chunks) {
                total_size += chunk.get_wire_size();
            }

            var writer = new ByteWriter(total_size);
            writer.write_uint16_be(this.src_port);
            writer.write_uint16_be(this.dst_port);
            writer.write_uint32_be(this.verification_tag);
            /* Checksum placeholder (zero) */
            writer.write_uint32_be(0);

            foreach (var chunk in this.chunks) {
                chunk.serialize(writer);
            }

            uint8[] wire = writer.to_array();
            /* Calculate CRC32 checksum across entire packet with checksum field set to 0 */
            uint32 crc = Solas.Crypto.Native.crc32(wire);
            this.checksum = crc;

            /* Write checksum at offset 8 (little-endian per SCTP RFC 4960) */
            wire[8] = (uint8) (crc & 0xFF);
            wire[9] = (uint8) ((crc >> 8) & 0xFF);
            wire[10] = (uint8) ((crc >> 16) & 0xFF);
            wire[11] = (uint8) ((crc >> 24) & 0xFF);

            return wire;
        }

        public static SctpPacket parse(uint8[] data) throws SctpError {
            if (data.length < COMMON_HEADER_LEN) {
                throw new SctpError.INVALID_PACKET("Truncated SCTP common header");
            }

            var reader = new ByteReader(data);
            try {
                uint16 src_port = reader.read_uint16_be();
                uint16 dst_port = reader.read_uint16_be();
                uint32 vtag = reader.read_uint32_be();
                uint8 b0 = reader.read_uint8();
                uint8 b1 = reader.read_uint8();
                uint8 b2 = reader.read_uint8();
                uint8 b3 = reader.read_uint8();
                uint32 checksum = (uint32) b0 | ((uint32) b1 << 8) | ((uint32) b2 << 16) | ((uint32) b3 << 24);

                var pkt = new SctpPacket(src_port, dst_port, vtag);
                pkt.checksum = checksum;

                while (reader.remaining >= 4) {
                    var chunk = SctpChunk.parse(reader);
                    pkt.add_chunk(chunk);
                }

                return pkt;
            } catch (ReaderError e) {
                throw new SctpError.INVALID_PACKET(e.message);
            }
        }
    }
}
