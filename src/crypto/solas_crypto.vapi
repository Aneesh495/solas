[CCode (cheader_filename = "crypto/solas_crypto_native.h")]
namespace Solas.Crypto.Native {
    [CCode (cname = "solas_crypto_crc32")]
    public static uint32 crc32([CCode (array_length_type = "size_t")] uint8[] data);

    [CCode (cname = "solas_crypto_stun_fingerprint")]
    public static uint32 stun_fingerprint([CCode (array_length_type = "size_t")] uint8[] data);

    [CCode (cname = "solas_crypto_sha1")]
    public static bool sha1([CCode (array_length_type = "size_t")] uint8[] data, [CCode (array_length = false)] uint8[] out_md);

    [CCode (cname = "solas_crypto_sha256")]
    public static bool sha256([CCode (array_length_type = "size_t")] uint8[] data, [CCode (array_length = false)] uint8[] out_md);

    [CCode (cname = "solas_crypto_hmac_sha1")]
    public static bool hmac_sha1([CCode (array_length_type = "size_t")] uint8[] key,
                                 [CCode (array_length_type = "size_t")] uint8[] data,
                                 [CCode (array_length = false)] uint8[] out_mac,
                                 out size_t out_mac_len);

    [CCode (cname = "solas_crypto_hmac_sha256")]
    public static bool hmac_sha256([CCode (array_length_type = "size_t")] uint8[] key,
                                   [CCode (array_length_type = "size_t")] uint8[] data,
                                   [CCode (array_length = false)] uint8[] out_mac,
                                   out size_t out_mac_len);

    [CCode (cname = "solas_crypto_aes_ctr")]
    public static bool aes_ctr([CCode (array_length_type = "size_t")] uint8[] key,
                               [CCode (array_length = false)] uint8[] iv_16,
                               [CCode (array_length_type = "size_t")] uint8[] input,
                               [CCode (array_length = false)] uint8[] output);

    [CCode (cname = "solas_crypto_random_bytes")]
    public static bool random_bytes([CCode (array_length_type = "size_t")] uint8[] out_buf);
}
