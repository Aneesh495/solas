/*
 * Solas: Real-Time WebRTC Media Engine
 * Zero-Copy Fixed-Size Slab Memory Allocator for High-Throughput Media Buffers
 */

using Solas.Core;

namespace Solas.Core {

    public errordomain SlabError {
        POOL_EXHAUSTED,
        INVALID_SLOT_ID,
        DOUBLE_FREE
    }

    public class SlabSlot : Object {
        public int slot_id { get; private set; }
        public ByteBuffer buffer { get; private set; }
        public bool in_use { get; set; default = false; }

        public SlabSlot(int slot_id, size_t slot_size) {
            this.slot_id = slot_id;
            this.buffer = new ByteBuffer(slot_size, 64);
            this.in_use = false;
        }

        public void reset() {
            this.buffer.reset();
            this.in_use = false;
        }
    }

    public class SlabPool : Object {
        private Gee.ArrayList<SlabSlot> slots;
        private Gee.ArrayList<int> free_stack;
        public size_t slot_size { get; private set; }
        public int capacity { get; private set; }

        public int active_count {
            get { return this.capacity - this.free_stack.size; }
        }
        public int peak_count { get; private set; default = 0; }
        public uint64 total_allocations { get; private set; default = 0; }
        public uint64 exhaustion_events { get; private set; default = 0; }

        public SlabPool(size_t slot_size = 2048, int capacity = 1024) {
            this.slot_size = slot_size;
            this.capacity = capacity;
            this.slots = new Gee.ArrayList<SlabSlot>();
            this.free_stack = new Gee.ArrayList<int>();

            for (int i = 0; i < capacity; i++) {
                var slot = new SlabSlot(i, slot_size);
                this.slots.add(slot);
                this.free_stack.add(i);
            }
        }

        /**
         * Acquire an existing pre-allocated buffer from the slab pool.
         */
        public ByteBuffer acquire(out int out_slot_id) throws SlabError {
            if (this.free_stack.is_empty) {
                this.exhaustion_events++;
                throw new SlabError.POOL_EXHAUSTED("Slab pool of size %d is completely exhausted".printf(this.capacity));
            }

            int slot_id = this.free_stack.remove_at(this.free_stack.size - 1);
            var slot = this.slots.get(slot_id);
            slot.in_use = true;
            slot.buffer.reset();

            this.total_allocations++;
            int current_active = this.active_count;
            if (current_active > this.peak_count) {
                this.peak_count = current_active;
            }

            out_slot_id = slot_id;
            return slot.buffer;
        }

        /**
         * Return a buffer slot back to the freelist stack.
         */
        public void release(int slot_id) throws SlabError {
            if (slot_id < 0 || slot_id >= this.capacity) {
                throw new SlabError.INVALID_SLOT_ID("Slot ID %d out of bounds".printf(slot_id));
            }

            var slot = this.slots.get(slot_id);
            if (!slot.in_use) {
                throw new SlabError.DOUBLE_FREE("Slot ID %d was not in active use (double free)".printf(slot_id));
            }

            slot.reset();
            this.free_stack.add(slot_id);
        }

        /**
         * Reset the entire slab pool to initial clean state.
         */
        public void purge() {
            this.free_stack.clear();
            for (int i = 0; i < this.capacity; i++) {
                this.slots.get(i).reset();
                this.free_stack.add(i);
            }
        }
    }
}
