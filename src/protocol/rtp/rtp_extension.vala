/*
 * Solas: Real-Time WebRTC Media Engine
 * RTP Header Extensions (RFC 8285 / RFC 6464 / RFC 8888)
 */

using Solas.Core;

namespace Solas.Protocol.Rtp {

    public const uint16 RTP_EXTENSION_PROFILE_ONE_BYTE = 0xBEDE;
    public const uint16 RTP_EXTENSION_PROFILE_TWO_BYTE = 0x1000;

    public class RtpHeaderExtension : Object {
        public uint8 id { get; set; }
        public uint8[] data;

        public RtpHeaderExtension(uint8 id, uint8[] data) {
            this.id = id;
            this.data = data;
        }

        /**
         * Parses Audio Level Extension (RFC 6464).
         * Data: [V (1 bit) | Level (7 bits dBov: 0 to 127)]
         */
        public bool parse_audio_level(out bool vad_active, out uint8 level_dbov) {
            vad_active = false;
            level_dbov = 127;
            if (this.data.length < 1) return false;

            vad_active = ((this.data[0] & 0x80) != 0);
            level_dbov = (uint8) (this.data[0] & 0x7F);
            return true;
        }

        public static RtpHeaderExtension create_audio_level(uint8 id, bool vad_active, uint8 level_dbov) {
            uint8 b = (uint8) ((vad_active ? 0x80 : 0x00) | (level_dbov & 0x7F));
            uint8[] d = { b };
            return new RtpHeaderExtension(id, d);
        }

        /**
         * Parses Transport-Wide Sequence Number (RFC 8888 TWCC).
         * 16-bit sequence number in network byte order.
         */
        public bool parse_transport_sequence_number(out uint16 transport_seq) {
            transport_seq = 0;
            if (this.data.length < 2) return false;

            transport_seq = (uint16) (((uint16) this.data[0] << 8) | (uint16) this.data[1]);
            return true;
        }

        public static RtpHeaderExtension create_transport_sequence_number(uint8 id, uint16 seq) {
            uint8[] d = {
                (uint8) ((seq >> 8) & 0xFF),
                (uint8) (seq & 0xFF)
            };
            return new RtpHeaderExtension(id, d);
        }

        /**
         * Parses Absolute Send Time (abs-send-time: 24-bit 6.18 fixed point).
         */
        public bool parse_abs_send_time(out uint32 abs_time) {
            abs_time = 0;
            if (this.data.length < 3) return false;

            abs_time = (((uint32) this.data[0] << 16) | ((uint32) this.data[1] << 8) | (uint32) this.data[2]);
            return true;
        }

        public static RtpHeaderExtension create_abs_send_time(uint8 id, uint32 abs_time) {
            uint8[] d = {
                (uint8) ((abs_time >> 16) & 0xFF),
                (uint8) ((abs_time >> 8) & 0xFF),
                (uint8) (abs_time & 0xFF)
            };
            return new RtpHeaderExtension(id, d);
        }

        /**
         * Parses MID or RID string extension.
         */
        public string get_as_string() {
            var sb = new StringBuilder();
            for (int i = 0; i < this.data.length; i++) {
                sb.append_c((char) this.data[i]);
            }
            return sb.str;
        }

        public static RtpHeaderExtension create_string(uint8 id, string text) {
            unowned uint8[] raw = (uint8[]) text;
            uint8[] d = new uint8[text.length];
            Memory.copy(d, raw, text.length);
            return new RtpHeaderExtension(id, d);
        }
    }
}
