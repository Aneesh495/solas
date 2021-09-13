/*
 * Unit tests for Solas.Protocol.Rtcp
 */
using Solas.Core;
using Solas.Protocol.Rtcp;

void test_sender_report_and_blocks() {
    var sr = new SenderReport(0x11223344U);
    sr.ntp_timestamp = Clock.get_ntp_timestamp_64();
    sr.rtp_timestamp = 90000;
    sr.packet_count = 150;
    sr.octet_count = 180000;

    var rb = new ReceptionReportBlock(0x55667788U);
    rb.fraction_lost = 5;
    rb.cumulative_lost = 12;
    rb.highest_seq_received = 1000;
    rb.interarrival_jitter = 250;
    sr.report_blocks.add(rb);

    var writer = new ByteWriter();
    sr.serialize(writer);
    uint8[] wire = writer.to_array();
    assert(wire.length > 28);

    try {
        var parsed = SenderReport.parse(wire);
        assert(parsed.ssrc == 0x11223344U);
        assert(parsed.rtp_timestamp == 90000);
        assert(parsed.packet_count == 150);
        assert(parsed.octet_count == 180000);
        assert(parsed.report_blocks.size == 1);

        var prb = parsed.report_blocks.get(0);
        assert(prb.ssrc == 0x55667788U);
        assert(prb.fraction_lost == 5);
        assert(prb.cumulative_lost == 12);
        assert(prb.highest_seq_received == 1000);
        assert(prb.interarrival_jitter == 250);
    } catch (GLib.Error e) {
        assert_not_reached();
    }
}

void test_nack_feedback() {
    var nack = new GenericNack(0x1000, 0x2000);
    /* Lost seq 100, 101, 103 */
    nack.add_lost_sequence(100);
    nack.add_lost_sequence(101);
    nack.add_lost_sequence(103);

    var writer = new ByteWriter();
    nack.serialize(writer);
    uint8[] wire = writer.to_array();

    try {
        var parsed = GenericNack.parse(wire);
        assert(parsed.sender_ssrc == 0x1000);
        assert(parsed.media_ssrc == 0x2000);

        var lost = parsed.get_lost_sequence_numbers();
        assert(lost.size == 3);
        assert(lost.get(0) == 100);
        assert(lost.get(1) == 101);
        assert(lost.get(2) == 103);
    } catch (GLib.Error e) {
        assert_not_reached();
    }
}

void test_remb_and_pli() {
    var pli = new PictureLossIndication(0x1234, 0x5678);
    var writer = new ByteWriter();
    pli.serialize(writer);
    try {
        var parsed_pli = PictureLossIndication.parse(writer.to_array());
        assert(parsed_pli.sender_ssrc == 0x1234);
        assert(parsed_pli.media_ssrc == 0x5678);
    } catch (GLib.Error e) {
        assert_not_reached();
    }

    /* REMB 2.5 Mbps = 2,500,000 bps */
    var remb = new RembFeedback(0x9999, 2500000ULL);
    remb.add_ssrc(0x5678);
    var remb_writer = new ByteWriter();
    remb.serialize(remb_writer);
    try {
        var parsed_remb = RembFeedback.parse(remb_writer.to_array());
        assert(parsed_remb.sender_ssrc == 0x9999);
        assert(parsed_remb.ssrc_feedback.size == 1);
        assert(parsed_remb.ssrc_feedback.get(0) == 0x5678);
        /* Approximate match within mantissa precision */
        assert(parsed_remb.bitrate_bps >= 2400000ULL && parsed_remb.bitrate_bps <= 2600000ULL);
    } catch (GLib.Error e) {
        assert_not_reached();
    }
}

void test_rtcp_compound_packet() {
    var compound = new RtcpCompoundPacket();

    var sr = new SenderReport(0xAABB);
    sr.rtp_timestamp = 12345;
    compound.add_packet(sr);

    var pli = new PictureLossIndication(0xAABB, 0xCCDD);
    compound.add_packet(pli);

    uint8[] wire = compound.serialize();
    try {
        var parsed_compound = RtcpCompoundPacket.parse(wire);
        assert(parsed_compound.packets.size == 2);
        assert(parsed_compound.packets.get(0) is SenderReport);
        assert(parsed_compound.packets.get(1) is PictureLossIndication);
    } catch (GLib.Error e) {
        assert_not_reached();
    }
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/rtcp/sender_report_and_blocks", test_sender_report_and_blocks);
    Test.add_func("/solas/rtcp/nack_feedback", test_nack_feedback);
    Test.add_func("/solas/rtcp/remb_and_pli", test_remb_and_pli);
    Test.add_func("/solas/rtcp/compound_packet", test_rtcp_compound_packet);
    Test.run();
}
