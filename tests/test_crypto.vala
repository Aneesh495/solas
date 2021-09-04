/*
 * Unit tests for Solas.Crypto
 */
using Solas.Core;
using Solas.Crypto;

void test_crc32_and_stun_fingerprint() {
    uint8[] data = "123456789".data;
    uint32 crc = Engine.crc32(data);
    /* Standard CRC-32 for "123456789" is 0xCBF43926 */
    assert(crc == 0xCBF43926U);

    uint32 fp = Engine.stun_fingerprint(data);
    assert(fp == (0xCBF43926U ^ 0x5354554EU));
}

void test_hash_and_hmac() {
    try {
        /* SHA-256 of empty string is e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 */
        uint8[] empty = {};
        uint8[] hash256 = Engine.sha256(empty);
        assert(hash256.length == 32);
        assert(hash256[0] == 0xE3);
        assert(hash256[1] == 0xB0);

        /* HMAC-SHA1 test vector (RFC 2202 test case 2)
         * Key: "Jefe"
         * Data: "what do ya want for nothing?"
         * Digest: effcdf6ae5eb2fa2d27416d5f184df9c259a7c79
         */
        uint8[] key = "Jefe".data;
        uint8[] msg = "what do ya want for nothing?".data;
        uint8[] mac = Engine.hmac_sha1(key, msg);
        assert(mac.length == 20);
        assert(mac[0] == 0xEF);
        assert(mac[1] == 0xFC);
        assert(mac[18] == 0x7C);
        assert(mac[19] == 0x79);
    } catch (CryptoError e) {
        assert_not_reached();
    }
}

void test_aes_ctr_roundtrip() {
    try {
        uint8[] key16 = {
            0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
            0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
        };
        uint8[] iv16 = {
            0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7,
            0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff
        };

        uint8[] plaintext = "Solas Real-Time WebRTC Media Engine AES-CTR Test".data;
        uint8[] ciphertext = Engine.aes_ctr(key16, iv16, plaintext);
        assert(ciphertext.length == plaintext.length);

        /* CTR mode is symmetric: re-encrypting ciphertext with same IV yields plaintext */
        uint8[] decrypted = Engine.aes_ctr(key16, iv16, ciphertext);
        assert(decrypted.length == plaintext.length);
        for (int i = 0; i < plaintext.length; i++) {
            assert(decrypted[i] == plaintext[i]);
        }

        /* Random bytes */
        uint8[] rnd = Engine.random_bytes(16);
        assert(rnd.length == 16);
    } catch (CryptoError e) {
        assert_not_reached();
    }
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/crypto/crc32_and_stun", test_crc32_and_stun_fingerprint);
    Test.add_func("/solas/crypto/hash_and_hmac", test_hash_and_hmac);
    Test.add_func("/solas/crypto/aes_ctr_roundtrip", test_aes_ctr_roundtrip);
    Test.run();
}
