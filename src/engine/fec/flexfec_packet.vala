/*
 * Solas: Real-Time WebRTC Media Engine
 * FlexFEC Packet Framing and Bitmask Encoding (RFC 8627)
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Engine.Fec {

    public errordomain FecError {
        INVALID_PACKET,
        INSUFFICIENT_PACKETS,
        RECOVERY_FAILED
    }

    public class FlexFecPacket : Object {
        public uint8 payload_type { get; set; default = 126; }
        public uint16 length_recovery { get; set; }
        public uint32 timestamp_recovery { get; set; }
        public uint32 protected_ssrc { get; set; }
        public uint16 seq_base { get; set; }
        public uint16 mask { get; set; }
        public uint8[] parity_payload;

        public FlexFecPacket(uint32 ssrc = 0, uint16 seq_base = 0, uint16 mask = 0) {
            this.protected_ssrc = ssrc;
            this.seq_base = seq_base;
            this.mask = mask;
            this.parity_payload = new uint8[0];
            this.length_recovery = 0;
            this.timestamp_recovery = 0;
        }

        public uint8[] serialize() {
            /* FlexFEC Header: 16 bytes + parity payload */
            size_t total_size = 16 + this.parity_payload.length;
            var writer = new ByteWriter(total_size);

            /* Byte 0: 0_0_0_0_0_0_0_0 (R=0, F=0, P=0) */
            writer.write_uint8(0x00);
            writer.write_uint8(this.payload_type & 0x7F);
            writer.write_uint16_be(this.length_recovery);
            writer.write_uint32_be(this.timestamp_recovery);

            /* SSRC Count = 1 (Byte 8) */
            writer.write_uint8(1);
            writer.write_uint8(0); /* reserved */
            writer.write_uint16_be(0); /* reserved */

            writer.write_uint32_be(this.protected_ssrc);
            writer.write_uint16_be(this.seq_base);
            writer.write_uint16_be(this.mask);

            if (this.parity_payload.length > 0) {
                writer.write_bytes(this.parity_payload);
            }

            return writer.to_array();
        }

        public static FlexFecPacket parse(uint8[] data) throws FecError {
            if (data.length < 20) {
                throw new FecError.INVALID_PACKET("FlexFEC packet shorter than minimum header (20 bytes)");
            }

            var reader = new ByteReader(data);
            try {
                reader.read_uint8(); /* flags */
                uint8 pt = (uint8) (reader.read_uint8() & 0x7F);
                uint16 len_rec = reader.read_uint16_be();
                uint32 ts_rec = reader.read_uint32_be();

                uint8 ssrc_count = reader.read_uint8();
                if (ssrc_count != 1) {
                    throw new FecError.INVALID_PACKET("Only single SSRC FlexFEC supported");
                }
                reader.skip(3); /* reserved */

                uint32 ssrc = reader.read_uint32_be();
                uint16 seq_base = reader.read_uint16_be();
                uint16 mask = reader.read_uint16_be();

                size_t parity_len = reader.remaining;
                uint8[] parity = reader.read_bytes(parity_len);

                var pkt = new FlexFecPacket(ssrc, seq_base, mask);
                pkt.payload_type = pt;
                pkt.length_recovery = len_rec;
                pkt.timestamp_recovery = ts_rec;
                pkt.parity_payload = parity;

                return pkt;
            } catch (ReaderError e) {
                throw new FecError.INVALID_PACKET(e.message);
            }
        }
    }
}
