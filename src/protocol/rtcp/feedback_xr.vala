/*
 * Solas: Real-Time WebRTC Media Engine
 * RTCP Extended Reports (XR) Implementation (RFC 3611)
 */

using Solas.Core;

namespace Solas.Protocol.Rtcp {

    public enum XrBlockType {
        UNKNOWN = 0,
        LOSS_RLE = 1,
        DUPLICATE_RLE = 2,
        PKT_RECEIPT_TIMES = 3,
        RCVR_REF_TIME = 4,
        DLRR = 5,
        STATS_SUMMARY = 6,
        VOIP_METRICS = 7
    }

    public abstract class XrReportBlock : Object {
        public XrBlockType block_type { get; construct; }
        public uint8 type_specific { get; set; default = 0; }

        public abstract size_t get_size_in_words(); /* in 32-bit words excluding 4-byte header */
        public abstract void serialize(ByteWriter writer);
    }

    /**
     * RFC 3611 Section 4.7 VoIP Metrics Report Block
     */
    public class XrVoipMetricsBlock : XrReportBlock {
        public uint32 ssrc { get; set; }
        public uint8 loss_rate { get; set; }       /* Fraction lost * 256 */
        public uint8 discard_rate { get; set; }    /* Fraction discarded * 256 */
        public uint8 burst_density { get; set; }
        public uint8 gap_density { get; set; }
        public uint16 burst_duration { get; set; }
        public uint16 gap_duration { get; set; }
        public uint16 round_trip_delay { get; set; }
        public uint16 end_system_delay { get; set; }
        public int8 signal_level { get; set; }
        public int8 noise_level { get; set; }
        public uint8 rerl { get; set; }
        public uint8 gmin { get; set; }
        public uint8 r_factor { get; set; }
        public uint8 ext_r_factor { get; set; }
        public uint8 mos_lq { get; set; }          /* MOS * 10 (e.g. 45 for 4.5) */
        public uint8 mos_cq { get; set; }

        public XrVoipMetricsBlock(uint32 ssrc = 0) {
            GLib.Object(block_type: XrBlockType.VOIP_METRICS);
            this.ssrc = ssrc;
            this.gmin = 16;
            this.mos_lq = 45;
            this.mos_cq = 45;
            this.r_factor = 94;
        }

        public override size_t get_size_in_words() {
            return 7; /* 28 bytes payload = 7 32-bit words */
        }

        public override void serialize(ByteWriter writer) {
            writer.write_uint8((uint8) this.block_type);
            writer.write_uint8(this.type_specific);
            writer.write_uint16_be((uint16) this.get_size_in_words());

            writer.write_uint32_be(this.ssrc);
            writer.write_uint8(this.loss_rate);
            writer.write_uint8(this.discard_rate);
            writer.write_uint8(this.burst_density);
            writer.write_uint8(this.gap_density);
            writer.write_uint16_be(this.burst_duration);
            writer.write_uint16_be(this.gap_duration);
            writer.write_uint16_be(this.round_trip_delay);
            writer.write_uint16_be(this.end_system_delay);
            writer.write_int8(this.signal_level);
            writer.write_int8(this.noise_level);
            writer.write_uint8(this.rerl);
            writer.write_uint8(this.gmin);
            writer.write_uint8(this.r_factor);
            writer.write_uint8(this.ext_r_factor);
            writer.write_uint8(this.mos_lq);
            writer.write_uint8(this.mos_cq);
            writer.write_uint8(0); /* rx_config */
            writer.write_uint8(0); /* reserved */
            writer.write_uint16_be(0); /* JB metrics placeholder */
        }

        public static XrVoipMetricsBlock parse(ByteReader reader, uint16 length_words) throws RtcpError {
            if (length_words < 7) {
                throw new RtcpError.INVALID_LENGTH("VoIP metrics block length less than 7 words");
            }

            try {
                uint32 ssrc = reader.read_uint32_be();
                var block = new XrVoipMetricsBlock(ssrc);
                block.loss_rate = reader.read_uint8();
                block.discard_rate = reader.read_uint8();
                block.burst_density = reader.read_uint8();
                block.gap_density = reader.read_uint8();
                block.burst_duration = reader.read_uint16_be();
                block.gap_duration = reader.read_uint16_be();
                block.round_trip_delay = reader.read_uint16_be();
                block.end_system_delay = reader.read_uint16_be();
                block.signal_level = reader.read_int8();
                block.noise_level = reader.read_int8();
                block.rerl = reader.read_uint8();
                block.gmin = reader.read_uint8();
                block.r_factor = reader.read_uint8();
                block.ext_r_factor = reader.read_uint8();
                block.mos_lq = reader.read_uint8();
                block.mos_cq = reader.read_uint8();

                /* Read remaining 4 bytes of block */
                reader.skip(4);

                return block;
            } catch (ReaderError e) {
                throw new RtcpError.MALFORMED_PACKET(e.message);
            }
        }
    }

    /**
     * RFC 3611 Section 4.1 Loss RLE Report Block
     */
    public class XrLossRleBlock : XrReportBlock {
        public uint32 ssrc { get; set; }
        public uint16 begin_seq { get; set; }
        public uint16 end_seq { get; set; }
        public Gee.ArrayList<uint16> chunks;

        public XrLossRleBlock(uint32 ssrc = 0, uint16 begin_seq = 0, uint16 end_seq = 0) {
            GLib.Object(block_type: XrBlockType.LOSS_RLE);
            this.ssrc = ssrc;
            this.begin_seq = begin_seq;
            this.end_seq = end_seq;
            this.chunks = new Gee.ArrayList<uint16>();
        }

        public void add_chunk(uint16 chunk) {
            this.chunks.add(chunk);
        }

        public override size_t get_size_in_words() {
            /* 2 words for SSRC (1) + seqs (1) + chunks */
            size_t chunk_words = (this.chunks.size + 1) / 2;
            return 2 + chunk_words;
        }

        public override void serialize(ByteWriter writer) {
            writer.write_uint8((uint8) this.block_type);
            writer.write_uint8(this.type_specific);
            writer.write_uint16_be((uint16) this.get_size_in_words());

            writer.write_uint32_be(this.ssrc);
            writer.write_uint16_be(this.begin_seq);
            writer.write_uint16_be(this.end_seq);

            for (int i = 0; i < this.chunks.size; i++) {
                writer.write_uint16_be(this.chunks[i]);
            }
            if (this.chunks.size % 2 != 0) {
                writer.write_uint16_be(0); /* Padding to 32-bit boundary */
            }
        }

        public static XrLossRleBlock parse(ByteReader reader, uint16 length_words) throws RtcpError {
            if (length_words < 2) {
                throw new RtcpError.INVALID_LENGTH("Loss RLE block length too short");
            }

            try {
                uint32 ssrc = reader.read_uint32_be();
                uint16 begin = reader.read_uint16_be();
                uint16 end = reader.read_uint16_be();

                var block = new XrLossRleBlock(ssrc, begin, end);
                size_t chunk_count = (length_words - 2) * 2;
                for (size_t i = 0; i < chunk_count && reader.remaining >= 2; i++) {
                    uint16 chunk = reader.read_uint16_be();
                    if (chunk != 0 || i < chunk_count - 1) {
                        block.add_chunk(chunk);
                    }
                }

                return block;
            } catch (ReaderError e) {
                throw new RtcpError.MALFORMED_PACKET(e.message);
            }
        }
    }

    /**
     * RTCP Extended Report (XR) Packet (PT = 207)
     */
    public class RtcpXrPacket : RtcpPacket {
        public const uint8 PAYLOAD_TYPE_XR = 207;

        public uint32 ssrc { get; set; }
        public Gee.ArrayList<XrReportBlock> blocks;

        public RtcpXrPacket(uint32 ssrc = 0) {
            GLib.Object(packet_type: PacketType.EXTENDED_REPORT);
            this.ssrc = ssrc;
            this.blocks = new Gee.ArrayList<XrReportBlock>();
        }

        public void add_block(XrReportBlock block) {
            this.blocks.add(block);
        }

        public override void serialize(ByteWriter writer) {
            var block_writer = new ByteWriter(512);
            block_writer.write_uint32_be(this.ssrc);

            foreach (var block in this.blocks) {
                block.serialize(block_writer);
            }

            uint8[] block_wire = block_writer.to_array();
            uint16 length_in_words = (uint16) (block_wire.length / 4);

            /* Write RTCP Common Header: V=2, P=0, RC=0, PT=207 */
            writer.write_uint8(0x80);
            writer.write_uint8(PAYLOAD_TYPE_XR);
            writer.write_uint16_be(length_in_words);
            writer.write_bytes(block_wire);
        }

        public uint8[] to_array() {
            var writer = new ByteWriter(512);
            this.serialize(writer);
            return writer.to_array();
        }

        public static RtcpXrPacket parse(uint8[] data) throws RtcpError {
            if (data.length < 8) {
                throw new RtcpError.HEADER_UNDERFLOW("XR packet smaller than minimum header");
            }

            var reader = new ByteReader(data);
            try {
                uint8 b0 = reader.read_uint8();
                uint8 pt = reader.read_uint8();
                if ((b0 >> 6) != 2 || pt != PAYLOAD_TYPE_XR) {
                    throw new RtcpError.MALFORMED_PACKET("Not a valid RTCP XR packet");
                }

                uint16 length_field = reader.read_uint16_be();
                size_t expected_bytes = ((size_t) length_field + 1) * 4;
                if (data.length < expected_bytes) {
                    throw new RtcpError.INVALID_LENGTH("XR packet data truncated");
                }

                uint32 ssrc = reader.read_uint32_be();
                var pkt = new RtcpXrPacket(ssrc);

                while (reader.remaining >= 4) {
                    uint8 bt = reader.read_uint8();
                    uint8 type_spec = reader.read_uint8();
                    uint16 block_len_words = reader.read_uint16_be();

                    if (bt == (uint8) XrBlockType.VOIP_METRICS) {
                        var voip = XrVoipMetricsBlock.parse(reader, block_len_words);
                        voip.type_specific = type_spec;
                        pkt.add_block(voip);
                    } else if (bt == (uint8) XrBlockType.LOSS_RLE) {
                        var rle = XrLossRleBlock.parse(reader, block_len_words);
                        rle.type_specific = type_spec;
                        pkt.add_block(rle);
                    } else {
                        /* Unknown or unhandled block type: skip payload */
                        size_t bytes_to_skip = (size_t) block_len_words * 4;
                        if (reader.remaining < bytes_to_skip) break;
                        reader.skip(bytes_to_skip);
                    }
                }

                return pkt;
            } catch (ReaderError e) {
                throw new RtcpError.MALFORMED_PACKET(e.message);
            }
        }
    }
}
