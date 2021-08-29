/*
 * Solas: Real-Time WebRTC Media Engine
 * Byte and Bitstream Serializer
 */

namespace Solas.Core {

    public class ByteWriter : Object {
        private ByteBuffer buffer;
        private uint8 bit_accumulator;
        private int bit_count;

        public ByteWriter(size_t capacity = 1024, size_t headroom = 64) {
            this.buffer = new ByteBuffer(capacity, headroom);
            this.bit_accumulator = 0;
            this.bit_count = 0;
        }

        public size_t size {
            get { return this.buffer.size + (this.bit_count > 0 ? 1 : 0); }
        }

        public void write_uint8(uint8 val) {
            flush_bits();
            this.buffer.append_uint8(val);
        }

        public void write_int8(int8 val) {
            write_uint8((uint8) val);
        }

        public void write_uint16_be(uint16 val) {
            flush_bits();
            this.buffer.append_uint8((uint8) ((val >> 8) & 0xFF));
            this.buffer.append_uint8((uint8) (val & 0xFF));
        }

        public void write_uint16_le(uint16 val) {
            flush_bits();
            this.buffer.append_uint8((uint8) (val & 0xFF));
            this.buffer.append_uint8((uint8) ((val >> 8) & 0xFF));
        }

        public void write_int16_be(int16 val) {
            write_uint16_be((uint16) val);
        }

        public void write_uint24_be(uint32 val) {
            flush_bits();
            this.buffer.append_uint8((uint8) ((val >> 16) & 0xFF));
            this.buffer.append_uint8((uint8) ((val >> 8) & 0xFF));
            this.buffer.append_uint8((uint8) (val & 0xFF));
        }

        public void write_uint32_be(uint32 val) {
            flush_bits();
            this.buffer.append_uint8((uint8) ((val >> 24) & 0xFF));
            this.buffer.append_uint8((uint8) ((val >> 16) & 0xFF));
            this.buffer.append_uint8((uint8) ((val >> 8) & 0xFF));
            this.buffer.append_uint8((uint8) (val & 0xFF));
        }

        public void write_uint32_le(uint32 val) {
            flush_bits();
            this.buffer.append_uint8((uint8) (val & 0xFF));
            this.buffer.append_uint8((uint8) ((val >> 8) & 0xFF));
            this.buffer.append_uint8((uint8) ((val >> 16) & 0xFF));
            this.buffer.append_uint8((uint8) ((val >> 24) & 0xFF));
        }

        public void write_int32_be(int32 val) {
            write_uint32_be((uint32) val);
        }

        public void write_uint64_be(uint64 val) {
            flush_bits();
            write_uint32_be((uint32) ((val >> 32) & 0xFFFFFFFF));
            write_uint32_be((uint32) (val & 0xFFFFFFFF));
        }

        public void write_bytes(uint8[] bytes) {
            flush_bits();
            this.buffer.append_bytes(bytes, bytes.length);
        }

        public void write_string(string text) {
            flush_bits();
            unowned uint8[] raw = (uint8[]) text;
            this.buffer.append_bytes(raw, text.length);
        }

        public void write_zero_padding(size_t count) {
            flush_bits();
            uint8[] zeros = new uint8[count];
            this.buffer.append_bytes(zeros, count);
        }

        /**
         * Writes between 1 and 32 bits into the bitstream accumulator.
         */
        public void write_bits(uint32 val, int bits) requires (bits >= 1 && bits <= 32) {
            for (int i = bits - 1; i >= 0; i--) {
                uint8 bit = (uint8) ((val >> i) & 1);
                this.bit_accumulator = (uint8) ((this.bit_accumulator << 1) | bit);
                this.bit_count++;
                if (this.bit_count == 8) {
                    this.buffer.append_uint8(this.bit_accumulator);
                    this.bit_accumulator = 0;
                    this.bit_count = 0;
                }
            }
        }

        public void write_bit(bool bit) {
            write_bits(bit ? 1 : 0, 1);
        }

        public void flush_bits() {
            if (this.bit_count > 0) {
                this.bit_accumulator = (uint8) (this.bit_accumulator << (8 - this.bit_count));
                this.buffer.append_uint8(this.bit_accumulator);
                this.bit_accumulator = 0;
                this.bit_count = 0;
            }
        }

        public ByteBuffer to_buffer() {
            flush_bits();
            return this.buffer.copy();
        }

        public uint8[] to_array() {
            flush_bits();
            return this.buffer.to_array();
        }
    }
}
