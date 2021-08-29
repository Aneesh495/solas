/*
 * Solas: Real-Time WebRTC Media Engine
 * Core Byte Buffer and Slice Management
 */

namespace Solas.Core {

    /**
     * Contiguous reference-counted byte buffer with optional prepend headroom.
     * Prepend headroom allows transport encapsulation (such as SRTP auth tags,
     * UDP/IP headers) without memory reallocations.
     */
    public class ByteBuffer : Object {
        private uint8[] data;
        private size_t head;
        private size_t length;
        private size_t capacity;

        public const size_t DEFAULT_HEADROOM = 64;
        public const size_t DEFAULT_CAPACITY = 2048;

        public ByteBuffer(size_t capacity = DEFAULT_CAPACITY, size_t headroom = DEFAULT_HEADROOM) {
            this.capacity = capacity + headroom;
            this.head = headroom;
            this.length = 0;
            this.data = new uint8[this.capacity];
        }

        public static ByteBuffer wrap(uint8[] raw_data) {
            var buf = new ByteBuffer(raw_data.length, 0);
            Memory.copy(buf.data, raw_data, raw_data.length);
            buf.length = raw_data.length;
            return buf;
        }

        public static ByteBuffer from_string(string text) {
            unowned uint8[] raw = (uint8[]) text;
            var buf = new ByteBuffer(text.length, 0);
            Memory.copy(buf.data, raw, text.length);
            buf.length = text.length;
            return buf;
        }

        public size_t size {
            get { return this.length; }
        }

        public size_t available_capacity {
            get { return this.capacity - (this.head + this.length); }
        }

        public size_t available_headroom {
            get { return this.head; }
        }

        public uint8 get_at(size_t index) requires (index < this.length) {
            return this.data[this.head + index];
        }

        public void set_at(size_t index, uint8 val) requires (index < this.length) {
            this.data[this.head + index] = val;
        }

        public void append_uint8(uint8 val) {
            ensure_capacity(1);
            this.data[this.head + this.length] = val;
            this.length++;
        }

        public void append_bytes(uint8[] bytes, size_t count) {
            ensure_capacity(count);
            Memory.copy(&this.data[this.head + this.length], bytes, count);
            this.length += count;
        }

        public void prepend_bytes(uint8[] bytes, size_t count) requires (count <= this.head) {
            this.head -= count;
            Memory.copy(&this.data[this.head], bytes, count);
            this.length += count;
        }

        public void prepend_uint8(uint8 val) requires (this.head >= 1) {
            this.head--;
            this.data[this.head] = val;
            this.length++;
        }

        public void trim_front(size_t count) requires (count <= this.length) {
            this.head += count;
            this.length -= count;
        }

        public void trim_back(size_t count) requires (count <= this.length) {
            this.length -= count;
        }

        public void reset() {
            this.head = DEFAULT_HEADROOM;
            this.length = 0;
        }

        public void ensure_capacity(size_t extra) {
            if (this.head + this.length + extra > this.capacity) {
                size_t new_cap = (this.capacity + extra) * 2;
                uint8[] new_data = new uint8[new_cap];
                Memory.copy(&new_data[this.head], &this.data[this.head], this.length);
                this.data = new_data;
                this.capacity = new_cap;
            }
        }

        public uint8[] to_array() {
            uint8[] result = new uint8[this.length];
            Memory.copy(result, &this.data[this.head], this.length);
            return result;
        }

        public unowned uint8[] get_raw_pointer() {
            return (uint8[]) (&this.data[this.head]);
        }

        public ByteSlice slice(size_t offset, size_t slice_len) requires (offset + slice_len <= this.length) {
            return new ByteSlice(this, offset, slice_len);
        }

        public ByteBuffer copy() {
            var clone = new ByteBuffer(this.length, this.head);
            Memory.copy(&clone.data[this.head], &this.data[this.head], this.length);
            clone.length = this.length;
            return clone;
        }

        public string to_hex_string() {
            var sb = new StringBuilder();
            for (size_t i = 0; i < this.length; i++) {
                sb.append_printf("%02x ", this.data[this.head + i]);
            }
            return sb.str.strip();
        }
    }

    /**
     * Zero-copy slice view over a parent ByteBuffer.
     */
    public class ByteSlice : Object {
        private ByteBuffer parent;
        private size_t offset;
        private size_t slice_length;

        public ByteSlice(ByteBuffer parent, size_t offset, size_t slice_length) {
            this.parent = parent;
            this.offset = offset;
            this.slice_length = slice_length;
        }

        public size_t size {
            get { return this.slice_length; }
        }

        public uint8 get_at(size_t idx) requires (idx < this.slice_length) {
            return this.parent.get_at(this.offset + idx);
        }

        public ByteSlice subslice(size_t sub_offset, size_t sub_len) requires (sub_offset + sub_len <= this.slice_length) {
            return new ByteSlice(this.parent, this.offset + sub_offset, sub_len);
        }

        public uint8[] to_array() {
            uint8[] res = new uint8[this.slice_length];
            for (size_t i = 0; i < this.slice_length; i++) {
                res[i] = this.get_at(i);
            }
            return res;
        }

        public ByteBuffer to_buffer() {
            return ByteBuffer.wrap(this.to_array());
        }
    }
}
