/*
 * Solas: Real-Time WebRTC Media Engine
 * Traversal Using Relays around NAT (TURN) Protocol Constants (RFC 5766)
 */

namespace Solas.Protocol.Turn {

    public enum TurnMethod {
        NONE = 0x000,
        ALLOCATE = 0x003,
        REFRESH = 0x004,
        SEND_INDICATION = 0x006,
        DATA_INDICATION = 0x007,
        CREATE_PERMISSION = 0x008,
        CHANNEL_BIND = 0x009
    }

    public enum TurnAttributeType {
        NONE = 0x0000,
        CHANNEL_NUMBER = 0x000C,
        LIFETIME = 0x000D,
        XOR_PEER_ADDRESS = 0x0012,
        DATA = 0x0013,
        XOR_RELAYED_ADDRESS = 0x0016,
        EVEN_PORT = 0x0018,
        REQUESTED_TRANSPORT = 0x0019,
        DONT_FRAG = 0x001A,
        RESERVATION_TOKEN = 0x0022
    }

    public const uint32 DEFAULT_LIFETIME_SECONDS = 600; /* 10 minutes */
    public const uint32 MAX_LIFETIME_SECONDS = 3600;    /* 1 hour */
    public const uint16 MIN_CHANNEL_NUMBER = 0x4000;
    public const uint16 MAX_CHANNEL_NUMBER = 0x7FFE;
}
