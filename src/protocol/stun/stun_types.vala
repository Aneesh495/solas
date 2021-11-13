/*
 * Solas: Real-Time WebRTC Media Engine
 * STUN Protocol Constants and Enumerations (RFC 5389 / RFC 8489)
 */

namespace Solas.Protocol.Stun {

    public const uint32 STUN_MAGIC_COOKIE = 0x2112A442U;
    public const size_t STUN_HEADER_LENGTH = 20;
    public const size_t STUN_TRANSACTION_ID_LENGTH = 12;

    public enum MessageClass {
        REQUEST = 0x00,
        INDICATION = 0x01,
        SUCCESS_RESPONSE = 0x02,
        ERROR_RESPONSE = 0x03
    }

    public enum MessageMethod {
        BINDING = 0x001
    }

    public enum MessageType {
        NONE = 0x0000,
        BINDING_REQUEST = 0x0001,
        BINDING_INDICATION = 0x0011,
        BINDING_SUCCESS_RESPONSE = 0x0101,
        BINDING_ERROR_RESPONSE = 0x0111
    }

    public enum AttributeType {
        NONE = 0x0000,
        MAPPED_ADDRESS = 0x0001,
        USERNAME = 0x0006,
        MESSAGE_INTEGRITY = 0x0008,
        ERROR_CODE = 0x0009,
        UNKNOWN_ATTRIBUTES = 0x000A,
        CHANNEL_NUMBER = 0x000C,
        LIFETIME = 0x000D,
        XOR_PEER_ADDRESS = 0x0012,
        DATA = 0x0013,
        REALM = 0x0014,
        NONCE = 0x0015,
        XOR_RELAYED_ADDRESS = 0x0016,
        EVEN_PORT = 0x0018,
        REQUESTED_TRANSPORT = 0x0019,
        DONT_FRAG = 0x001A,
        XOR_MAPPED_ADDRESS = 0x0020,
        RESERVATION_TOKEN = 0x0022,
        PRIORITY = 0x0024,
        USE_CANDIDATE = 0x0025,
        SOFTWARE = 0x8022,
        ALTERNATE_SERVER = 0x8023,
        FINGERPRINT = 0x8028,
        ICE_CONTROLLED = 0x8029,
        ICE_CONTROLLING = 0x802A
    }

    public enum AddressFamily {
        NONE = 0x00,
        IPV4 = 0x01,
        IPV6 = 0x02
    }

    public errordomain StunError {
        MALFORMED_HEADER,
        INVALID_MAGIC_COOKIE,
        ATTRIBUTE_UNDERFLOW,
        INTEGRITY_MISMATCH,
        FINGERPRINT_MISMATCH,
        UNSUPPORTED_FAMILY
    }
}
