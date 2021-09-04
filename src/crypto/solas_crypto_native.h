#ifndef SOLAS_CRYPTO_NATIVE_H
#define SOLAS_CRYPTO_NATIVE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* CRC32 IEEE 802.3 */
uint32_t solas_crypto_crc32(const uint8_t *data, size_t length);

/* STUN Fingerprint: CRC32 XOR 0x5354554E */
uint32_t solas_crypto_stun_fingerprint(const uint8_t *data, size_t length);

/* SHA-1 digest (20 bytes output) */
bool solas_crypto_sha1(const uint8_t *data, size_t length, uint8_t *out_md);

/* SHA-256 digest (32 bytes output) */
bool solas_crypto_sha256(const uint8_t *data, size_t length, uint8_t *out_md);

/* HMAC-SHA1 */
bool solas_crypto_hmac_sha1(const uint8_t *key, size_t key_len,
                            const uint8_t *data, size_t data_len,
                            uint8_t *out_mac, size_t *out_mac_len);

/* HMAC-SHA256 */
bool solas_crypto_hmac_sha256(const uint8_t *key, size_t key_len,
                              const uint8_t *data, size_t data_len,
                              uint8_t *out_mac, size_t *out_mac_len);

/* AES-128-CTR and AES-256-CTR encrypt/decrypt (keystream XOR) */
bool solas_crypto_aes_ctr(const uint8_t *key, size_t key_len,
                          const uint8_t *iv_16,
                          const uint8_t *input, size_t length,
                          uint8_t *output);

/* Cryptographically secure random bytes */
bool solas_crypto_random_bytes(uint8_t *out_buf, size_t length);

#ifdef __cplusplus
}
#endif

#endif /* SOLAS_CRYPTO_NATIVE_H */
