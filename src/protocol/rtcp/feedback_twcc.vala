/*
 * Solas: Real-Time WebRTC Media Engine
 * Transport-Wide Congestion Control Feedback (RFC 8888)
 */

using Solas.Core;

namespace Solas.Protocol.Rtcp {

    public class PacketArrivalInfo : Object {
        public uint16 sequence_number { get; set; }
        public int64 arrival_time_us { get; set; }
        public bool received { get; set; }

        public PacketArrivalInfo(uint16 seq, int64 arrival_us, bool rx = true) {
            this.sequence_number = seq;
            this.arrival_time_us = arrival_us;
            this.received = rx;
        }
    }

    public class TwccFeedback : RtcpPacket {
        public uint32 sender_ssrc { get; set; }
        public uint32 media_ssrc { get; set; }
        public uint16 base_sequence_number { get; set; }
        public uint8 feedback_packet_count { get; set; }
        public Gee.ArrayList<PacketArrivalInfo> packet_reports { get; private set; }

        public TwccFeedback(uint32 sender_ssrc = 0, uint32 media_ssrc = 0) {
            Object(packet_type: PacketType.TRANSPORT_FEEDBACK);
            this.count_or_format = (uint8) TransportFeedbackFormat.TWCC;
            this.sender_ssrc = sender_ssrc;
            this.media_ssrc = media_ssrc;
            this.base_sequence_number = 0;
            this.feedback_packet_count = 0;
            this.packet_reports = new Gee.ArrayList<PacketArrivalInfo>();
        }

        public void add_arrival(uint16 seq, int64 arrival_us) {
            this.packet_reports.add(new PacketArrivalInfo(seq, arrival_us, true));
        }

        public void add_lost(uint16 seq) {
            this.packet_reports.add(new PacketArrivalInfo(seq, 0, false));
        }

        public override void serialize(ByteWriter writer) {
            writer.write_uint8(0x80 | (uint8) TransportFeedbackFormat.TWCC);
            writer.write_uint8((uint8) PacketType.TRANSPORT_FEEDBACK);

            /* Build status chunks and delta array */
            var body_writer = new ByteWriter(512);
            body_writer.write_uint32_be(this.sender_ssrc);
            body_writer.write_uint32_be(this.media_ssrc);
            body_writer.write_uint16_be(this.base_sequence_number);
            body_writer.write_uint16_be((uint16) this.packet_reports.size);

            /* Reference time: 24 bits (in 64ms units) */
            int64 ref_us = (!this.packet_reports.is_empty) ? this.packet_reports.get(0).arrival_time_us : 0;
            uint32 ref_time = (uint32) ((ref_us / 64000) & 0x00FFFFFF);
            body_writer.write_uint24_be(ref_time);
            body_writer.write_uint8(this.feedback_packet_count);

            /* Run length chunk: 1 status symbol for all packets */
            /* 1 bit chunk type (0 = run length), 2 bits symbol, 13 bits run length */
            uint16 chunk = (uint16) ((1 << 13) | (this.packet_reports.size & 0x1FFF));
            body_writer.write_uint16_be(chunk);

            /* Delta bytes (small 1-byte delta in 250us units) */
            int64 last_time = ref_us;
            foreach (var p in this.packet_reports) {
                if (p.received) {
                    int64 delta_us = p.arrival_time_us - last_time;
                    uint8 delta_unit = (uint8) ((delta_us / 250) & 0xFF);
                    body_writer.write_uint8(delta_unit);
                    last_time = p.arrival_time_us;
                }
            }

            /* 4-byte padding */
            size_t pad = (4 - (body_writer.size % 4)) % 4;
            if (pad > 0) {
                body_writer.write_zero_padding(pad);
            }

            uint16 len_words = (uint16) (body_writer.size / 4);
            writer.write_uint16_be(len_words);
            writer.write_bytes(body_writer.to_array());
        }

        public static TwccFeedback parse(uint8[] data) throws RtcpError {
            if (data.length < 16) {
                throw new RtcpError.HEADER_UNDERFLOW("Data too short for TWCC feedback");
            }
            var reader = new ByteReader(data);
            try {
                reader.skip(4);
                var twcc = new TwccFeedback();
                twcc.sender_ssrc = reader.read_uint32_be();
                twcc.media_ssrc = reader.read_uint32_be();
                twcc.base_sequence_number = reader.read_uint16_be();
                uint16 count = reader.read_uint16_be();
                uint32 ref_time = reader.read_uint24_be();
                twcc.feedback_packet_count = reader.read_uint8();

                int64 current_time_us = (int64) ref_time * 64000;
                for (uint16 i = 0; i < count; i++) {
                    twcc.add_arrival((uint16) (twcc.base_sequence_number + i), current_time_us);
                    current_time_us += 5000; /* Increment 5ms delta */
                }

                return twcc;
            } catch (ReaderError e) {
                throw new RtcpError.HEADER_UNDERFLOW("Underflow reading TWCC feedback: %s".printf(e.message));
            }
        }
    }
}
