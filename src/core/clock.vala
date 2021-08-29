/*
 * Solas: Real-Time WebRTC Media Engine
 * High-Precision Monotonic Clocks and NTP Rollover Arithmetic
 */

namespace Solas.Core {

    public class Clock : Object {
        /* Difference between Unix epoch (1970) and NTP epoch (1900) in seconds */
        public const uint64 NTP_OFFSET_SECS = 2208988800ULL;

        /**
         * Returns current monotonic clock timestamp in microseconds.
         */
        public static int64 get_monotonic_time_us() {
            return GLib.get_monotonic_time();
        }

        /**
         * Returns current monotonic clock timestamp in milliseconds.
         */
        public static int64 get_monotonic_time_ms() {
            return GLib.get_monotonic_time() / 1000;
        }

        /**
         * Returns current wall-clock real time in microseconds since Unix epoch.
         */
        public static int64 get_real_time_us() {
            return GLib.get_real_time();
        }

        /**
         * Generates a 64-bit NTP timestamp (RFC 5905).
         * High 32 bits: Seconds since Jan 1, 1900.
         * Low 32 bits: Fractional seconds (scaled to 2^32).
         */
        public static uint64 get_ntp_timestamp_64() {
            int64 now_us = get_real_time_us();
            uint64 secs = (uint64) (now_us / 1000000) + NTP_OFFSET_SECS;
            uint64 frac_us = (uint64) (now_us % 1000000);
            /* frac = (frac_us * (1ULL << 32)) / 1000000 */
            uint64 frac = (frac_us << 32) / 1000000ULL;
            return (secs << 32) | (frac & 0xFFFFFFFFULL);
        }

        /**
         * Extracts the compact 32-bit middle NTP timestamp for RTCP Sender Reports.
         * Takes bits 16..47 of the 64-bit NTP timestamp (16 bits seconds + 16 bits fraction).
         */
        public static uint32 get_compact_ntp_32(uint64 ntp64) {
            return (uint32) ((ntp64 >> 16) & 0xFFFFFFFF);
        }

        /**
         * Determines if seq1 is strictly newer than seq2 under modulo 2^16 arithmetic.
         * Adheres to RFC 3550 sequence number comparison:
         * seq1 > seq2 if (seq1 - seq2) & 0x8000 == 0 and seq1 != seq2.
         */
        public static bool sequence_number_newer(uint16 seq1, uint16 seq2) {
            return (seq1 != seq2) && (((uint16) (seq1 - seq2) & 0x8000) == 0);
        }

        /**
         * Computes signed distance (seq1 - seq2) under modulo 2^16 arithmetic.
         */
        public static int32 sequence_number_delta(uint16 seq1, uint16 seq2) {
            return (int16) (seq1 - seq2);
        }

        /**
         * Computes signed distance (ts1 - ts2) under modulo 2^32 arithmetic.
         */
        public static int64 timestamp_delta_32(uint32 ts1, uint32 ts2) {
            return (int32) (ts1 - ts2);
        }
    }
}
