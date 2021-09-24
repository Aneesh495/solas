/*
 * Unit tests for Solas.Engine.Jitter
 */
using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Protocol.Rtcp;
using Solas.Engine.Jitter;

void test_packet_buffer_reordering() {
    var pb = new PacketBuffer(100);

    var p1 = new RtpPacket(); p1.sequence_number = 1;
    var p2 = new RtpPacket(); p2.sequence_number = 2;
    var p3 = new RtpPacket(); p3.sequence_number = 3;

    /* Insert out of order: 3, 1, 2 */
    assert(pb.insert(3, 3000, p3));
    assert(pb.insert(1, 1000, p1));
    assert(pb.insert(2, 2000, p2));

    /* Duplicate insert rejected */
    assert(!pb.insert(2, 2500, p2));
    assert(pb.size == 3);

    /* Must pop in order: 1, 2, 3 */
    var out1 = pb.pop();
    assert(out1 != null && out1.unwrapped_seq == 1);
    var out2 = pb.pop();
    assert(out2 != null && out2.unwrapped_seq == 2);
    var out3 = pb.pop();
    assert(out3 != null && out3.unwrapped_seq == 3);
    assert(pb.is_empty);
}

void test_nack_controller_loss_detection() {
    var nack_ctrl = new NackController(0x1111, 0x2222, 50.0);

    int64 t0 = 1000000;
    nack_ctrl.on_packet_received(10, t0);
    assert(nack_ctrl.pending_count == 0);

    /* Gap: packet 13 arrives (11 and 12 missing) */
    nack_ctrl.on_packet_received(13, t0 + 10000);
    assert(nack_ctrl.pending_count == 2);

    /* Generate NACK feedback */
    var fb = nack_ctrl.get_nack_feedback(t0 + 10000);
    assert(fb != null);
    var lost = fb.get_lost_sequence_numbers();
    assert(lost.size == 2);
    assert(lost.get(0) == 11);
    assert(lost.get(1) == 12);

    /* Immediate second query should be rate-limited by RTT (50ms = 50,000us) */
    var fb_immediate = nack_ctrl.get_nack_feedback(t0 + 15000);
    assert(fb_immediate == null);

    /* Late packet 11 arrives */
    nack_ctrl.on_packet_received(11, t0 + 30000);
    assert(nack_ctrl.pending_count == 1);

    /* After RTT backoff (e.g. 70ms later), query should only return 12 */
    var fb_retry = nack_ctrl.get_nack_feedback(t0 + 80000);
    assert(fb_retry != null);
    var lost2 = fb_retry.get_lost_sequence_numbers();
    assert(lost2.size == 1);
    assert(lost2.get(0) == 12);
}

void test_frame_assembler() {
    var fa = new FrameAssembler();

    var p1 = new RtpPacket(); p1.sequence_number = 100; p1.timestamp = 5000; p1.marker = false; p1.payload = "Chunk1".data;
    var p2 = new RtpPacket(); p2.sequence_number = 101; p2.timestamp = 5000; p2.marker = false; p2.payload = "Chunk2".data;
    var p3 = new RtpPacket(); p3.sequence_number = 102; p3.timestamp = 5000; p3.marker = true;  p3.payload = "Chunk3".data;

    /* Push p1, then p3 (gap at 101) */
    fa.push_packet(100, 1000, p1);
    fa.push_packet(102, 1200, p3);

    /* Cannot assemble because 101 is missing */
    assert(fa.poll_complete_frame() == null);

    /* Push retransmitted p2 */
    fa.push_packet(101, 1500, p2);

    /* Now frame is complete */
    var frame = fa.poll_complete_frame();
    assert(frame != null);
    assert(frame.timestamp == 5000);
    assert(frame.packets.size == 3);
    assert(frame.total_payload_bytes == "Chunk1".length + "Chunk2".length + "Chunk3".length);

    /* Subsequent poll is empty */
    assert(fa.poll_complete_frame() == null);
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/jitter/packet_buffer_reordering", test_packet_buffer_reordering);
    Test.add_func("/solas/jitter/nack_controller_loss_detection", test_nack_controller_loss_detection);
    Test.add_func("/solas/jitter/frame_assembler", test_frame_assembler);
    Test.run();
}
