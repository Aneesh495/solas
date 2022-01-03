/*
 * Solas: Real-Time WebRTC Media Engine
 * Test Suite: Zero-Copy Fixed-Size Slab Memory Allocator
 */

using Solas.Core;

class Solas.TestSlab {

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/core/slab/preallocation_and_properties", () => {
            var pool = new SlabPool(2048, 64);
            assert(pool.slot_size == 2048);
            assert(pool.capacity == 64);
            assert(pool.active_count == 0);
            assert(pool.peak_count == 0);
            assert(pool.total_allocations == 0);
        });

        Test.add_func("/core/slab/acquire_release_lifecycle", () => {
            var pool = new SlabPool(1500, 10);
            int slot1, slot2;

            try {
                var buf1 = pool.acquire(out slot1);
                assert(slot1 >= 0);
                assert(pool.active_count == 1);
                assert(pool.peak_count == 1);

                buf1.append_uint8(0xAA);
                assert(buf1.size == 1);

                var buf2 = pool.acquire(out slot2);
                assert(slot2 >= 0);
                assert(slot1 != slot2);
                assert(pool.active_count == 2);
                assert(pool.peak_count == 2);

                pool.release(slot1);
                assert(pool.active_count == 1);

                // Re-acquiring should reuse released slot
                int slot3;
                var buf3 = pool.acquire(out slot3);
                assert(slot3 == slot1);
                // Buffer was reset on release/acquire
                assert(buf3.size == 0);

                pool.release(slot2);
                pool.release(slot3);
                assert(pool.active_count == 0);
            } catch (GLib.Error e) {
                assert_not_reached();
            }
        });

        Test.add_func("/core/slab/pool_exhaustion_detection", () => {
            var pool = new SlabPool(512, 4);
            int[] slots = new int[4];

            try {
                for (int i = 0; i < 4; i++) {
                    pool.acquire(out slots[i]);
                }
                assert(pool.active_count == 4);

                bool exhausted = false;
                try {
                    int extra_slot;
                    pool.acquire(out extra_slot);
                } catch (SlabError e) {
                    exhausted = true;
                }
                assert(exhausted);
                assert(pool.exhaustion_events == 1);

                // Release one and verify acquire works again
                pool.release(slots[0]);
                assert(pool.active_count == 3);

                int recovered_slot;
                pool.acquire(out recovered_slot);
                assert(recovered_slot == slots[0]);
                assert(pool.active_count == 4);
            } catch (GLib.Error e) {
                assert_not_reached();
            }
        });

        Test.add_func("/core/slab/double_free_rejection", () => {
            var pool = new SlabPool(512, 4);
            int slot;

            try {
                pool.acquire(out slot);
                pool.release(slot);

                bool caught_double_free = false;
                try {
                    pool.release(slot);
                } catch (SlabError e) {
                    caught_double_free = true;
                }
                assert(caught_double_free);
            } catch (GLib.Error e) {
                assert_not_reached();
            }
        });

        return Test.run();
    }
}
