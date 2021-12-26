/*
 * Solas: Real-Time WebRTC Media Engine
 * Test Suite: RFC 9605 Secure Frame (SFrame) E2EE Cipher
 */

using Solas.Core;
using Solas.Crypto;

class Solas.TestSFrame {

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/crypto/sframe/encrypt_decrypt_roundtrip", () => {
            var cipher = new SFrameCipher(16);

            uint8[] enc_key = new uint8[16];
            uint8[] auth_key = new uint8[32];
            for (int i = 0; i < 16; i++) enc_key[i] = (uint8) (i + 1);
            for (int i = 0; i < 32; i++) auth_key[i] = (uint8) (i + 0x20);

            uint64 key_id = 42;
            cipher.add_key(key_id, enc_key, auth_key);

            string raw_payload = "High Definition Video Frame - End to End Encrypted via SFrame RFC 9605";
            uint8[] plaintext = raw_payload.data;
            uint64 counter = 1001;

            try {
                uint8[] encrypted = cipher.encrypt_frame(key_id, counter, plaintext);
                assert(encrypted.length > plaintext.length);

                uint64 out_kid = 0;
                uint64 out_ctr = 0;
                uint8[] decrypted = cipher.decrypt_frame(encrypted, out out_kid, out out_ctr);

                assert(out_kid == key_id);
                assert(out_ctr == counter);
                assert(decrypted.length == plaintext.length);
                assert((string) decrypted == raw_payload);
            } catch (GLib.Error e) {
                printerr("Caught error: %s\n", e.message);
                assert_not_reached();
            }
        });

        Test.add_func("/crypto/sframe/tampered_tag_rejection", () => {
            var cipher = new SFrameCipher(16);
            uint8[] enc_key = new uint8[16];
            uint8[] auth_key = new uint8[32];
            for (int i = 0; i < 16; i++) enc_key[i] = (uint8) (i + 5);
            for (int i = 0; i < 32; i++) auth_key[i] = (uint8) (i + 10);

            cipher.add_key(7, enc_key, auth_key);
            uint8[] plaintext = "Sensitive Audio Packet".data;

            try {
                uint8[] encrypted = cipher.encrypt_frame(7, 50, plaintext);
                // Corrupt 1 byte in the ciphertext or tag
                encrypted[encrypted.length - 1] ^= 0xFF;

                uint64 out_kid, out_ctr;
                bool caught = false;
                try {
                    cipher.decrypt_frame(encrypted, out out_kid, out out_ctr);
                } catch (SFrameError e) {
                    caught = true;
                }
                assert(caught);
            } catch (GLib.Error e) {
                printerr("Caught error: %s\n", e.message);
                assert_not_reached();
            }
        });

        Test.add_func("/crypto/sframe/key_rotation_epoch", () => {
            var cipher = new SFrameCipher(16);
            uint8[] k1 = new uint8[16];
            uint8[] a1 = new uint8[32];
            uint8[] k2 = new uint8[16];
            uint8[] a2 = new uint8[32];
            for (int i = 0; i < 16; i++) {
                k1[i] = (uint8) i;
                k2[i] = (uint8) (i + 50);
            }
            for (int i = 0; i < 32; i++) {
                a1[i] = (uint8) i;
                a2[i] = (uint8) (i + 50);
            }

            cipher.add_key(1, k1, a1);
            cipher.add_key(2, k2, a2);

            try {
                uint8[] enc1 = cipher.encrypt_frame(1, 10, "Epoch 1 media".data);
                uint8[] enc2 = cipher.encrypt_frame(2, 1, "Epoch 2 media".data);

                uint64 kid1, ctr1, kid2, ctr2;
                uint8[] dec1 = cipher.decrypt_frame(enc1, out kid1, out ctr1);
                uint8[] dec2 = cipher.decrypt_frame(enc2, out kid2, out ctr2);

                assert(kid1 == 1);
                assert(kid2 == 2);
                assert((string) dec1 == "Epoch 1 media");
                assert((string) dec2 == "Epoch 2 media");
            } catch (GLib.Error e) {
                printerr("Caught error: %s\n", e.message);
                assert_not_reached();
            }
        });

        Test.add_func("/crypto/sframe/replay_attack_prevention", () => {
            var sender = new SFrameCipher(16);
            var receiver = new SFrameCipher(16);
            uint8[] k = new uint8[16];
            uint8[] a = new uint8[32];
            sender.add_key(99, k, a);
            receiver.add_key(99, k, a);

            try {
                // Generate packet at counter 500
                uint8[] enc500 = sender.encrypt_frame(99, 500, "Frame 500".data);

                // Receiver processes newer packet at counter 1000
                uint8[] enc1000 = sender.encrypt_frame(99, 1000, "Frame 1000".data);
                uint64 out_k, out_c;
                receiver.decrypt_frame(enc1000, out out_k, out out_c);

                // Now attempt to replay old frame from counter 500 (more than 128 behind 1000)
                bool replay_caught = false;
                try {
                    receiver.decrypt_frame(enc500, out out_k, out out_c);
                } catch (SFrameError e) {
                    replay_caught = true;
                }
                assert(replay_caught);
            } catch (GLib.Error e) {
                printerr("Caught error: %s\n", e.message);
                assert_not_reached();
            }
        });

        return Test.run();
    }
}
