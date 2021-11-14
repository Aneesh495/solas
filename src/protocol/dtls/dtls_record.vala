/*
 * Solas: Real-Time WebRTC Media Engine
 * DTLS Record Layer Framing and Serialization (RFC 6347 Section 4.1)
 */

using Solas.Core;

namespace Solas.Protocol.Dtls {

    public const uint16 DTLS_VERSION_1_0 = 0xFEFF;
    public const uint16 DTLS_VERSION_1_2 = 0xFEFD;

    public class DtlsRecord : Object {
        public DtlsContentType content_type { get; set; }
        public uint16 version { get; set; }
        public uint16 epoch { get; set; }
        public uint64 sequence_number { get; set; }
        public uint8[] fragment;

        public DtlsRecord(DtlsContentType type, uint8[] fragment, uint16 epoch = 0, uint64 seq = 0, uint16 version = DTLS_VERSION_1_2) {
            this.content_type = type;
            this.version = version;
            this.epoch = epoch;
            this.sequence_number = seq;
            this.fragment = fragment;
        }

        public uint8[] serialize() {
            var writer = new ByteWriter(this.fragment.length + 13);
            writer.write_uint8((uint8) this.content_type);
            writer.write_uint16_be(this.version);
            writer.write_uint16_be(this.epoch);

            /* 48-bit Sequence Number */
            writer.write_uint16_be((uint16) ((this.sequence_number >> 32) & 0xFFFF));
            writer.write_uint32_be((uint32) (this.sequence_number & 0xFFFFFFFF));

            writer.write_uint16_be((uint16) this.fragment.length);
            writer.write_bytes(this.fragment);

            return writer.to_array();
        }

        public static DtlsRecord? parse(uint8[] packet) {
            if (packet.length < 13) return null;

            var reader = new ByteReader(packet);
            try {
                uint8 ct = reader.read_uint8();
                if (ct < 20 || ct > 23) return null;

                uint16 ver = reader.read_uint16_be();
                uint16 epoch = reader.read_uint16_be();

                uint16 seq_hi = reader.read_uint16_be();
                uint32 seq_lo = reader.read_uint32_be();
                uint64 seq = (((uint64) seq_hi) << 32) | (uint64) seq_lo;

                uint16 len = reader.read_uint16_be();
                if (reader.remaining < len) return null;

                uint8[] fragment = reader.read_bytes(len);
                return new DtlsRecord((DtlsContentType) ct, fragment, epoch, seq, ver);
            } catch (ReaderError e) {
                return null;
            }
        }
    }
}
