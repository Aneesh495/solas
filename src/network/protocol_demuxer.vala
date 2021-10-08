/*
 * Solas: Real-Time WebRTC Media Engine
 * O(1) Multiplexed UDP Packet Demultiplexer (RFC 7983)
 */

namespace Solas.Network {

    public enum DemuxProtocol {
        UNKNOWN = 0,
        STUN = 1,
        DTLS = 2,
        RTP = 3,
        RTCP = 4
    }

    public class ProtocolDemuxer : Object {

        /**
         * Fast O(1) classification of incoming UDP datagram based on first byte (RFC 7983).
         * - 0..1: STUN
         * - 20..63: DTLS
         * - 128..191: RTP or RTCP
         */
        public static DemuxProtocol classify(uint8[] packet) {
            if (packet.length < 1) {
                return DemuxProtocol.UNKNOWN;
            }

            uint8 b0 = packet[0];

            /* STUN: bits 00 => values 0 or 1 */
            if (b0 <= 1) {
                return DemuxProtocol.STUN;
            }

            /* DTLS: values 20 to 63 (ContentType handshake=22, change_cipher=20, alert=21, app=23) */
            if (b0 >= 20 && b0 <= 63) {
                return DemuxProtocol.DTLS;
            }

            /* RTP / RTCP: version 2 => 128..191 */
            if (b0 >= 128 && b0 <= 191) {
                if (packet.length >= 2) {
                    uint8 pt = (uint8) (packet[1] & 0x7F);
                    /* RTCP payload types standard range: 64..95 or 200..211 */
                    if ((pt >= 64 && pt <= 95) || (packet[1] >= 200 && packet[1] <= 211)) {
                        return DemuxProtocol.RTCP;
                    }
                }
                return DemuxProtocol.RTP;
            }

            return DemuxProtocol.UNKNOWN;
        }
    }
}
