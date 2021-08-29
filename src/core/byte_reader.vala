/*
 * Solas: Real-Time WebRTC Media Engine
 * Byte and Bitstream Reader
 */

namespace Solas.Core {

    public errordomain ReaderError {
        UNDERFLOW,
        MALFORMED_DATA
    }

    public class ByteReader : Object {
        private uint8[] buffer;
        private size_t position;
        private size_t limit;

        /* Bit-level reading state */
        private uint8 bit_buffer;
        private int bit_count;

        public ByteReader(uint8[] data, size_t offset = 0, size_t length = 0) {
            this.buffer = data;
            this.position = offset;
            this.limit = (length == 0) ? data.length : (offset + length);
            if (this.limit > data.length) {
                this.limit = data.length;
            }
            this.bit_buffer = 0;
            this.bit_count = 0;
        }

        public static ByteReader from_buffer(ByteBuffer buf) {
            return new ByteReader(buf.to_array());
        }

        public size_t offset {
            get { return this.position; }
        }

        public size_t remaining {
            get { return (this.position < this.limit) ? (this.limit - this.position) : 0; }
        }

        public bool has_remaining {
            get { return this.remaining > 0 || this.bit_count > 0; }
        }

        public void seek(size_t pos) throws ReaderError {
            if (pos > this.limit) {
                throw new ReaderError.UNDERFLOW("Cannot seek beyond reader limit");
            }
            this.position = pos;
            this.bit_buffer = 0;
            this.bit_count = 0;
        }

        public void skip(size_t count) throws ReaderError {
            if (this.position + count > this.limit) {
                throw new ReaderError.UNDERFLOW("Not enough bytes to skip");
            }
            this.position += count;
            this.bit_buffer = 0;
            this.bit_count = 0;
        }

        public uint8 read_uint8() throws ReaderError {
            align_bits();
            if (this.position >= this.limit) {
                throw new ReaderError.UNDERFLOW("End of stream reached on read_uint8");
            }
            return this.buffer[this.position++];
        }

        public uint8 peek_uint8() throws ReaderError {
            align_bits();
            if (this.position >= this.limit) {
                throw new ReaderError.UNDERFLOW("End of stream reached on peek_uint8");
            }
            return this.buffer[this.position];
        }

        public int8 read_int8() throws ReaderError {
            return (int8) read_uint8();
        }

        public uint16 read_uint16_be() throws ReaderError {
            uint8 b0 = read_uint8();
            uint8 b1 = read_uint8();
            return (uint16) (((uint16) b0 << 8) | (uint16) b1);
        }

        public uint16 read_uint16_le() throws ReaderError {
            uint8 b0 = read_uint8();
            uint8 b1 = read_uint8();
            return (uint16) (((uint16) b1 << 8) | (uint16) b0);
        }

        public int16 read_int16_be() throws ReaderError {
            return (int16) read_uint16_be();
        }

        public uint32 read_uint24_be() throws ReaderError {
            uint8 b0 = read_uint8();
            uint8 b1 = read_uint8();
            uint8 b2 = read_uint8();
            return (((uint32) b0 << 16) | ((uint32) b1 << 8) | (uint32) b2);
        }

        public uint32 read_uint32_be() throws ReaderError {
            uint8 b0 = read_uint8();
            uint8 b1 = read_uint8();
            uint8 b2 = read_uint8();
            uint8 b3 = read_uint8();
            return (((uint32) b0 << 24) | ((uint32) b1 << 16) | ((uint32) b2 << 8) | (uint32) b3);
        }

        public uint32 read_uint32_le() throws ReaderError {
            uint8 b0 = read_uint8();
            uint8 b1 = read_uint8();
            uint8 b2 = read_uint8();
            uint8 b3 = read_uint8();
            return (((uint32) b3 << 24) | ((uint32) b2 << 16) | ((uint32) b1 << 8) | (uint32) b0);
        }

        public int32 read_int32_be() throws ReaderError {
            return (int32) read_uint32_be();
        }

        public uint64 read_uint64_be() throws ReaderError {
            uint64 hi = (uint64) read_uint32_be();
            uint64 lo = (uint64) read_uint32_be();
            return (hi << 32) | lo;
        }

        public uint8[] read_bytes(size_t count) throws ReaderError {
            align_bits();
            if (this.position + count > this.limit) {
                throw new ReaderError.UNDERFLOW("Not enough bytes to read chunk of %u", (uint) count);
            }
            uint8[] result = new uint8[count];
            Memory.copy(result, &this.buffer[this.position], count);
            this.position += count;
            return result;
        }

        public ByteBuffer read_byte_buffer(size_t count) throws ReaderError {
            return ByteBuffer.wrap(read_bytes(count));
        }

        public string read_string(size_t count) throws ReaderError {
            uint8[] raw = read_bytes(count);
            var sb = new StringBuilder();
            sb.append_len((string) raw, (ssize_t) count);
            return sb.str;
        }

        /**
         * Reads between 1 and 32 bits from the bitstream.
         * Used for unpacking RTP packet flags, VP8 descriptors, and H.264 slice headers.
         */
        public uint32 read_bits(int bits) throws ReaderError requires (bits >= 1 && bits <= 32) {
            uint32 result = 0;
            while (bits > 0) {
                if (this.bit_count == 0) {
                    if (this.position >= this.limit) {
                        throw new ReaderError.UNDERFLOW("End of stream in bitstream reader");
                    }
                    this.bit_buffer = this.buffer[this.position++];
                    this.bit_count = 8;
                }

                int take = (bits < this.bit_count) ? bits : this.bit_count;
                int shift = this.bit_count - take;
                uint8 mask = (uint8) ((1 << take) - 1);
                uint32 chunk = (uint32) ((this.bit_buffer >> shift) & mask);

                result = (result << take) | chunk;
                this.bit_count -= take;
                bits -= take;
            }
            return result;
        }

        public bool read_bit() throws ReaderError {
            return read_bits(1) == 1;
        }

        public void align_bits() {
            this.bit_buffer = 0;
            this.bit_count = 0;
        }
    }
}
