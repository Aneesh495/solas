/*
 * Solas: Real-Time WebRTC Media Engine
 * SCTP (RFC 4960) and WebRTC Data Channel (RFC 8831 / RFC 8832) Types
 */

using Solas.Core;

namespace Solas.Protocol.Sctp {

    public errordomain SctpError {
        INVALID_PACKET,
        TRUNCATED,
        CHECKSUM_MISMATCH,
        PROTOCOL_VIOLATION
    }

    public enum SctpChunkType {
        DATA = 0x00,
        INIT = 0x01,
        INIT_ACK = 0x02,
        SACK = 0x03,
        HEARTBEAT = 0x04,
        HEARTBEAT_ACK = 0x05,
        ABORT = 0x06,
        SHUTDOWN = 0x07,
        SHUTDOWN_ACK = 0x08,
        ERROR = 0x09,
        COOKIE_ECHO = 0x0A,
        COOKIE_ACK = 0x0B,
        ECNE = 0x0C,
        CWR = 0x0D,
        SHUTDOWN_COMPLETE = 0x0E
    }

    public enum SctpPpid {
        DCEP = 50,
        STRING = 51,
        BINARY_PARTIAL = 52,
        BINARY = 53,
        STRING_PARTIAL = 54,
        STRING_EMPTY = 56,
        BINARY_EMPTY = 57
    }

    public enum DcepMessageType {
        OPEN = 0x03,
        ACK = 0x02
    }

    public enum DataChannelChannelType {
        RELIABLE = 0x00,
        RELIABLE_UNORDERED = 0x80,
        PARTIAL_RELIABLE_REXMIT = 0x01,
        PARTIAL_RELIABLE_REXMIT_UNORDERED = 0x81,
        PARTIAL_RELIABLE_TIMED = 0x02,
        PARTIAL_RELIABLE_TIMED_UNORDERED = 0x82
    }
}
