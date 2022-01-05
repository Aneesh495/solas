/*
 * Solas: Real-Time WebRTC Media Engine
 * Test Suite: Deterministic Protocol Fuzzing and Malformed Packet Decoder Hardening
 */

using Solas.Core;
using Solas.Protocol.Stun;
using Solas.Protocol.Rtp;
using Solas.Protocol.Rtcp;
using Solas.Crypto;

class Solas.TestFuzz {

    private class LcgRng {
        private uint64 state;

        public LcgRng(uint64 seed) {
            this.state = seed;
        }

        public uint32 next_u32() {
            this.state = this.state * 6364136223846793005ULL + 1442695040888963407ULL;
            return (uint32) (this.state >> 32);
        }

        public uint8 next_u8() {
            return (uint8) (next_u32() & 0xFF);
        }

        public uint8[] random_buffer(size_t len) {
            uint8[] buf = new uint8[len];
            for (size_t i = 0; i < len; i++) {
                buf[i] = next_u8();
            }
            return buf;
        }
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/fuzz/stun/corrupted_inputs_no_crash", () => {
            var rng = new LcgRng(0xDEADBEEF);
            int iterations = 500;

            for (int iter = 0; iter < iterations; iter++) {
                size_t len = (size_t) (rng.next_u32() % 256);
                uint8[] garbage = rng.random_buffer(len);

                try {
                    var msg = StunMessage.parse(garbage);
                    try {
                        uint8[] reserialized = msg.serialize();
                        assert(reserialized.length >= 20);
                    } catch (GLib.Error e) {
                        // Encryption/HMAC error in fuzz is caught
                    }
                } catch (StunError e) {
                    // Graceful rejection as expected
                }
            }
        });

        Test.add_func("/fuzz/rtp/corrupted_inputs_no_crash", () => {
            var rng = new LcgRng(0xCAFEF00D);
            int iterations = 500;

            for (int iter = 0; iter < iterations; iter++) {
                size_t len = (size_t) (rng.next_u32() % 300);
                uint8[] garbage = rng.random_buffer(len);

                try {
                    var rtp = RtpPacket.parse(garbage);
                    uint8[] reserialized = rtp.serialize();
                    assert(reserialized.length >= 12);
                } catch (RtpError e) {
                    // Graceful rejection as expected
                }
            }
        });

        Test.add_func("/fuzz/rtcp/compound_corrupted_inputs_no_crash", () => {
            var rng = new LcgRng(0x1337C0DE);
            int iterations = 500;

            for (int iter = 0; iter < iterations; iter++) {
                size_t len = (size_t) (rng.next_u32() % 256);
                uint8[] garbage = rng.random_buffer(len);

                try {
                    var compound = RtcpCompoundPacket.parse(garbage);
                    assert(compound != null);
                } catch (RtcpError e) {
                    // Graceful rejection as expected
                }
            }
        });

        Test.add_func("/fuzz/sframe/corrupted_frames_no_crash", () => {
            var rng = new LcgRng(0x8BADF00D);
            var cipher = new SFrameCipher(16);
            uint8[] k = new uint8[16];
            uint8[] a = new uint8[32];
            cipher.add_key(1, k, a);

            int iterations = 500;
            for (int iter = 0; iter < iterations; iter++) {
                size_t len = (size_t) (rng.next_u32() % 128);
                uint8[] garbage = rng.random_buffer(len);

                try {
                    uint64 kid, ctr;
                    cipher.decrypt_frame(garbage, out kid, out ctr);
                } catch (SFrameError e) {
                    // Graceful rejection as expected
                }
            }
        });

        return Test.run();
    }
}
