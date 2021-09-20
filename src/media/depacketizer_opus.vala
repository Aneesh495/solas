/*
 * Solas: Real-Time WebRTC Media Engine
 * Opus Audio Depacketizer and RMS Energy Follower (RFC 7587 / RFC 6716)
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Media {

    public class DepacketizerOpus : MediaDepacketizer {

        public DepacketizerOpus() {
            Object(codec_id: CodecId.OPUS);
        }

        public override bool is_keyframe(RtpPacket packet) {
            /* Audio frames are self-contained packets (always decodable) */
            return true;
        }

        public override uint8[] extract_payload(RtpPacket packet) {
            return packet.payload;
        }

        /**
         * Calculates approximate RMS audio energy from encoded Opus frame payload.
         * Used for active speaker detection when RFC 6464 extension is not negotiated.
         */
        public static double calculate_approximate_energy_db(uint8[] payload) {
            if (payload.length < 2) return -127.0;

            uint64 sum = 0;
            for (size_t i = 1; i < payload.length; i++) {
                int8 sample = (int8) payload[i];
                sum += (uint64) (sample * sample);
            }

            double mean_square = (double) sum / (double) (payload.length - 1);
            if (mean_square < 1.0) return -127.0;

            /* dB = 10 * log10(mean_square / max_square) */
            double db = 10.0 * Math.log10(mean_square / (128.0 * 128.0));
            if (db < -127.0) db = -127.0;
            if (db > 0.0) db = 0.0;
            return db;
        }
    }
}
