/*
 * Solas: Real-Time WebRTC Media Engine
 * RFC 8837 Differentiated Services Code Point (DSCP) QoS Classifier
 */

using Solas.Core;

namespace Solas.Network {

    public enum DscpValue {
        CS0 = 0,    // Best Effort (signaling, default)
        CS1 = 8,    // Low Priority Data
        AF11 = 10,  // Assured Forwarding 11 (interactive bulk data)
        AF12 = 12,
        AF41 = 34,  // Assured Forwarding 41 (high priority video)
        AF42 = 36,  // Assured Forwarding 42 (medium priority video)
        AF43 = 38,  // Assured Forwarding 43 (low priority video)
        EF = 46     // Expedited Forwarding (interactive audio)
    }

    public enum TrafficClass {
        AUDIO_INTERACTIVE,
        VIDEO_INTERACTIVE_HIGH,
        VIDEO_INTERACTIVE_MEDIUM,
        VIDEO_BACKGROUND,
        DATA_CHANNEL_CRITICAL,
        DATA_CHANNEL_LOW,
        SIGNALING_BEST_EFFORT
    }

    public enum EcnMarking {
        NOT_ECT = 0,
        ECT_1 = 1,
        ECT_0 = 2,
        CE = 3       // Congestion Experienced
    }

    public class QosClassifier : Object {

        public static DscpValue traffic_class_to_dscp(TrafficClass tc) {
            switch (tc) {
                case TrafficClass.AUDIO_INTERACTIVE:
                    return DscpValue.EF;
                case TrafficClass.VIDEO_INTERACTIVE_HIGH:
                    return DscpValue.AF41;
                case TrafficClass.VIDEO_INTERACTIVE_MEDIUM:
                    return DscpValue.AF42;
                case TrafficClass.VIDEO_BACKGROUND:
                    return DscpValue.AF43;
                case TrafficClass.DATA_CHANNEL_CRITICAL:
                    return DscpValue.AF11;
                case TrafficClass.DATA_CHANNEL_LOW:
                    return DscpValue.CS1;
                case TrafficClass.SIGNALING_BEST_EFFORT:
                default:
                    return DscpValue.CS0;
            }
        }

        public static uint8 make_tos_byte(DscpValue dscp, EcnMarking ecn = EcnMarking.NOT_ECT) {
            uint8 dscp_val = (uint8) dscp;
            uint8 ecn_val = (uint8) ecn;
            return (uint8) (((dscp_val & 0x3F) << 2) | (ecn_val & 0x03));
        }

        public static void parse_tos_byte(uint8 tos, out DscpValue dscp, out EcnMarking ecn) {
            uint8 dscp_raw = (uint8) ((tos >> 2) & 0x3F);
            uint8 ecn_raw = (uint8) (tos & 0x03);

            ecn = (EcnMarking) ecn_raw;

            switch (dscp_raw) {
                case 46:
                    dscp = DscpValue.EF;
                    break;
                case 34:
                    dscp = DscpValue.AF41;
                    break;
                case 36:
                    dscp = DscpValue.AF42;
                    break;
                case 38:
                    dscp = DscpValue.AF43;
                    break;
                case 10:
                    dscp = DscpValue.AF11;
                    break;
                case 12:
                    dscp = DscpValue.AF12;
                    break;
                case 8:
                    dscp = DscpValue.CS1;
                    break;
                case 0:
                default:
                    dscp = DscpValue.CS0;
                    break;
            }
        }

        public static bool apply_socket_dscp(Socket socket, TrafficClass tc) {
            DscpValue dscp = traffic_class_to_dscp(tc);
            uint8 tos = make_tos_byte(dscp);

            try {
                // IP_TOS is level IPPROTO_IP (0), optname 1 on most POSIX/BSD/Darwin systems
                socket.set_option(0, 1, (int) tos);
                return true;
            } catch (GLib.Error e) {
                // If permission denied or unsupported by OS, gracefully fall back
                return false;
            }
        }
    }
}
