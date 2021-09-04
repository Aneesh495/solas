#include "solas_crypto_native.h"
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/rand.h>
#include <string.h>

/* Precomputed IEEE 802.3 CRC32 table */
static uint32_t crc32_tab[256];
static int crc32_tab_initialized = 0;

static void init_crc32_table(void) {
    uint32_t poly = 0xEDB88320;
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t crc = i;
        for (int j = 0; j < 8; j++) {
            if (crc & 1) {
                crc = (crc >> 1) ^ poly;
            } else {
                crc = crc >> 1;
            }
        }
        crc32_tab[i] = crc;
    }
    crc32_tab_initialized = 1;
}

uint32_t solas_crypto_crc32(const uint8_t *data, size_t length) {
    if (!crc32_tab_initialized) {
        init_crc32_table();
    }
    uint32_t crc = 0xFFFFFFFF;
    for (size_t i = 0; i < length; i++) {
        uint8_t index = (uint8_t)((crc ^ data[i]) & 0xFF);
        crc = (crc >> 8) ^ crc32_tab[index];
    }
    return ~crc;
}

uint32_t solas_crypto_stun_fingerprint(const uint8_t *data, size_t length) {
    uint32_t crc = solas_crypto_crc32(data, length);
    return crc ^ 0x5354554EU;
}

bool solas_crypto_sha1(const uint8_t *data, size_t length, uint8_t *out_md) {
    unsigned int md_len = 20;
    return EVP_Digest(data, length, out_md, &md_len, EVP_sha1(), NULL) == 1;
}

bool solas_crypto_sha256(const uint8_t *data, size_t length, uint8_t *out_md) {
    unsigned int md_len = 32;
    return EVP_Digest(data, length, out_md, &md_len, EVP_sha256(), NULL) == 1;
}

bool solas_crypto_hmac_sha1(const uint8_t *key, size_t key_len,
                            const uint8_t *data, size_t data_len,
                            uint8_t *out_mac, size_t *out_mac_len) {
    unsigned int len = 0;
    uint8_t *res = HMAC(EVP_sha1(), key, (int)key_len, data, data_len, out_mac, &len);
    if (!res) return false;
    if (out_mac_len) *out_mac_len = len;
    return true;
}

bool solas_crypto_hmac_sha256(const uint8_t *key, size_t key_len,
                              const uint8_t *data, size_t data_len,
                              uint8_t *out_mac, size_t *out_mac_len) {
    unsigned int len = 0;
    uint8_t *res = HMAC(EVP_sha256(), key, (int)key_len, data, data_len, out_mac, &len);
    if (!res) return false;
    if (out_mac_len) *out_mac_len = len;
    return true;
}

bool solas_crypto_aes_ctr(const uint8_t *key, size_t key_len,
                          const uint8_t *iv_16,
                          const uint8_t *input, size_t length,
                          uint8_t *output) {
    const EVP_CIPHER *cipher = NULL;
    if (key_len == 16) {
        cipher = EVP_aes_128_ctr();
    } else if (key_len == 32) {
        cipher = EVP_aes_256_ctr();
    } else {
        return false;
    }

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return false;

    if (EVP_EncryptInit_ex(ctx, cipher, NULL, key, iv_16) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    int out_len = 0;
    if (EVP_EncryptUpdate(ctx, output, &out_len, input, (int)length) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    int final_len = 0;
    EVP_EncryptFinal_ex(ctx, output + out_len, &final_len);
    EVP_CIPHER_CTX_free(ctx);
    return true;
}

bool solas_crypto_random_bytes(uint8_t *out_buf, size_t length) {
    return RAND_bytes(out_buf, (int)length) == 1;
}
