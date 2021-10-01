/*
 * Unit tests for Solas.Engine.Sfu
 */
using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Protocol.Sdp;
using Solas.Engine.Sfu;

void test_room_and_subscription_topology() {
    var room = new Room("test-conference-room");
    assert(room.peer_count == 0);

    var alice = new Peer("alice", "Alice");
    var bob = new Peer("bob", "Bob");

    room.add_peer(alice);
    room.add_peer(bob);
    assert(room.peer_count == 2);

    /* Alice publishes a video track */
    var vcodec = new CodecCapability(96, "VP8", 90000);
    var alice_video = new MediaTrack("alice:video", MediaType.VIDEO, 0x1111, vcodec);
    room.publish_track(alice, alice_video);

    /* Bob must be automatically subscribed to Alice's video */
    assert(bob.subscribed_tracks.has_key("alice:video"));

    /* Charlie joins later */
    var charlie = new Peer("charlie", "Charlie");
    room.add_peer(charlie);
    assert(charlie.subscribed_tracks.has_key("alice:video"));

    /* Alice leaves room */
    room.remove_peer("alice");
    assert(room.peer_count == 2);
    assert(!bob.subscribed_tracks.has_key("alice:video"));
}

void test_packet_routing_and_active_speaker() {
    var room = new Room("audio-room");
    var alice = new Peer("alice");
    var bob = new Peer("bob");
    room.add_peer(alice);
    room.add_peer(bob);

    int bob_packets_received = 0;
    bob.on_packet_dispatch = (pkt) => {
        bob_packets_received++;
    };

    /* Alice sends audio packet with active voice level (dBov = 20) */
    var audio_pkt = new RtpPacket();
    audio_pkt.payload_type = 111;
    audio_pkt.sequence_number = 1;
    audio_pkt.add_extension(RtpHeaderExtension.create_audio_level(1, true, 20));

    room.route_rtp_packet("alice", audio_pkt);

    assert(bob_packets_received == 1);
    assert(room.speaker_detector.dominant_speaker == "alice");
}

void test_simulcast_layer_switching() {
    var forwarder = new SimulcastForwarder("subscriber-bob", SpatialLayer.HIGH);
    assert(forwarder.current_layer == SpatialLayer.HIGH);

    /* Send packet on HIGH layer */
    var p_high = new RtpPacket();
    p_high.sequence_number = 100;
    p_high.timestamp = 90000;
    p_high.payload = "1080p frame".data;

    var out1 = forwarder.process_packet(SpatialLayer.HIGH, p_high);
    assert(out1 != null);
    assert(out1.sequence_number == 100);

    /* Drop available bandwidth to 300 kbps: triggers adapt_to_bandwidth(300) -> LOW */
    forwarder.adapt_to_bandwidth(300.0);
    assert(forwarder.target_layer == SpatialLayer.LOW);
    assert(forwarder.is_switching);

    /* LOW delta frame arrives before keyframe: should NOT switch yet */
    var p_low_delta = new RtpPacket();
    p_low_delta.sequence_number = 500;
    p_low_delta.timestamp = 93000;
    p_low_delta.payload = { 0x90, 0x80, 0x01, 0x01 }; /* VP8 P=1 delta */

    var out_delta = forwarder.process_packet(SpatialLayer.LOW, p_low_delta);
    assert(out_delta == null); /* Dropped because not on active layer yet */

    /* LOW keyframe arrives: VP8 P=0 */
    var p_low_key = new RtpPacket();
    p_low_key.sequence_number = 501;
    p_low_key.timestamp = 96000;
    /* Synthesize valid VP8 keyframe */
    p_low_key.payload = {
        0x90, 0x80, 0x02,
        0x00, 0x00, 0x00,
        0x9D, 0x01, 0x2A,
        0x00, 0x05, 0xD0, 0x02
    };

    var out_key = forwarder.process_packet(SpatialLayer.LOW, p_low_key);
    assert(out_key != null);
    assert(forwarder.current_layer == SpatialLayer.LOW);
    assert(!forwarder.is_switching);

    /* Sequence number must follow seamlessly: 101 */
    assert(out_key.sequence_number == 101);
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/sfu/room_and_topology", test_room_and_subscription_topology);
    Test.add_func("/solas/sfu/packet_routing_and_speaker", test_packet_routing_and_active_speaker);
    Test.add_func("/solas/sfu/simulcast_switching", test_simulcast_layer_switching);
    Test.run();
}
