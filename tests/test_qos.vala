/*
 * Solas: Real-Time WebRTC Media Engine
 * Test Suite: RFC 8837 DiffServ DSCP QoS Classification and Marking
 */

using Solas.Core;
using Solas.Network;

class Solas.TestQos {

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/network/qos/traffic_class_mapping", () => {
            assert(QosClassifier.traffic_class_to_dscp(TrafficClass.AUDIO_INTERACTIVE) == DscpValue.EF);
            assert(QosClassifier.traffic_class_to_dscp(TrafficClass.VIDEO_INTERACTIVE_HIGH) == DscpValue.AF41);
            assert(QosClassifier.traffic_class_to_dscp(TrafficClass.VIDEO_INTERACTIVE_MEDIUM) == DscpValue.AF42);
            assert(QosClassifier.traffic_class_to_dscp(TrafficClass.VIDEO_BACKGROUND) == DscpValue.AF43);
            assert(QosClassifier.traffic_class_to_dscp(TrafficClass.DATA_CHANNEL_CRITICAL) == DscpValue.AF11);
            assert(QosClassifier.traffic_class_to_dscp(TrafficClass.DATA_CHANNEL_LOW) == DscpValue.CS1);
            assert(QosClassifier.traffic_class_to_dscp(TrafficClass.SIGNALING_BEST_EFFORT) == DscpValue.CS0);
        });

        Test.add_func("/network/qos/tos_byte_roundtrip", () => {
            // Audio EF (46) with ECN CE (3)
            uint8 tos = QosClassifier.make_tos_byte(DscpValue.EF, EcnMarking.CE);
            // EF is 46 = 0x2E. 0x2E << 2 = 0xB8. 0xB8 | 3 = 0xBB = 187
            assert(tos == 0xBB);

            DscpValue parsed_dscp;
            EcnMarking parsed_ecn;
            QosClassifier.parse_tos_byte(tos, out parsed_dscp, out parsed_ecn);
            assert(parsed_dscp == DscpValue.EF);
            assert(parsed_ecn == EcnMarking.CE);

            // Video AF41 (34) with ECT_0 (2)
            uint8 video_tos = QosClassifier.make_tos_byte(DscpValue.AF41, EcnMarking.ECT_0);
            // 34 << 2 = 136 (0x88). 0x88 | 2 = 0x8A = 138
            assert(video_tos == 0x8A);

            QosClassifier.parse_tos_byte(video_tos, out parsed_dscp, out parsed_ecn);
            assert(parsed_dscp == DscpValue.AF41);
            assert(parsed_ecn == EcnMarking.ECT_0);
        });

        Test.add_func("/network/qos/best_effort_default", () => {
            uint8 default_tos = QosClassifier.make_tos_byte(DscpValue.CS0, EcnMarking.NOT_ECT);
            assert(default_tos == 0x00);

            DscpValue parsed_dscp;
            EcnMarking parsed_ecn;
            QosClassifier.parse_tos_byte(default_tos, out parsed_dscp, out parsed_ecn);
            assert(parsed_dscp == DscpValue.CS0);
            assert(parsed_ecn == EcnMarking.NOT_ECT);
        });

        return Test.run();
    }
}
