/*
 * Solas: Real-Time WebRTC Media Engine
 * SDP Enumerations and Definitions (RFC 4566 / RFC 8866)
 */

namespace Solas.Protocol.Sdp {

    public enum MediaType {
        UNKNOWN = 0,
        AUDIO = 1,
        VIDEO = 2,
        APPLICATION = 3
    }

    public enum MediaDirection {
        INACTIVE = 0,
        SEND_ONLY = 1,
        RECV_ONLY = 2,
        SEND_RECV = 3
    }

    public enum SetupRole {
        UNKNOWN = 0,
        ACTPASS = 1,
        ACTIVE = 2,
        PASSIVE = 3,
        HOLDCONN = 4
    }

    public errordomain SdpError {
        PARSE_ERROR,
        INVALID_FORMAT,
        UNSUPPORTED_CODEC,
        NEGOTIATION_FAILED
    }
}
