/*
 * Solas: Real-Time WebRTC Media Engine
 * RTCP Protocol Enumerations and Definitions (RFC 3550 / RFC 4585 / RFC 5104 / RFC 8888)
 */

namespace Solas.Protocol.Rtcp {

    public enum PacketType {
        UNKNOWN = 0,
        SENDER_REPORT = 200,
        RECEIVER_REPORT = 201,
        SOURCE_DESCRIPTION = 202,
        GOODBYE = 203,
        APPLICATION = 204,
        TRANSPORT_FEEDBACK = 205,
        PAYLOAD_FEEDBACK = 206
    }

    public enum TransportFeedbackFormat {
        GENERIC_NACK = 1,
        TWCC = 15
    }

    public enum PayloadFeedbackFormat {
        PLI = 1,
        SLI = 2,
        RPSI = 3,
        FIR = 4,
        REMB = 15
    }

    public errordomain RtcpError {
        MALFORMED_PACKET,
        HEADER_UNDERFLOW,
        INVALID_LENGTH,
        UNSUPPORTED_TYPE
    }
}
