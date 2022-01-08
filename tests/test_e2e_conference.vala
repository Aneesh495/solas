/*
 * Solas: Real-Time WebRTC Media Engine
 * Test Suite: Multi-Party End-to-End Conference Integration Test
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Protocol.Rtcp;
using Solas.Protocol.Sdp;
using Solas.Engine.Sfu;
using Solas.Engine.Audio;
using Solas.Media;

class Solas.TestE2EConference {

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/e2e/conference/multi_party_flow", () => {
            // 1. Initialize Room Coordinator
            var room = new Room("room-alpha-1");
            assert(room.room_id == "room-alpha-1");
            assert(room.peers.size == 0);

            // 2. Peers Join Room
            var alice = new Peer("peer-alice", "Alice");
            var bob = new Peer("peer-bob", "Bob");
            var charlie = new Peer("peer-charlie", "Charlie");
            var david = new Peer("peer-david", "David");

            room.add_peer(alice);
            room.add_peer(bob);
            room.add_peer(charlie);
            room.add_peer(david);
            assert(room.peers.size == 4);

            // 3. Alice publishes Simulcast Video (SSRC 1001) and Audio (SSRC 2001)
            var codec_vp8 = new CodecCapability(96, "VP8", 90000);
            var codec_opus = new CodecCapability(111, "opus", 48000);

            var video_track = new MediaTrack("track-alice-video", MediaType.VIDEO, 1001, codec_vp8);
            alice.add_published_track(video_track);

            var audio_track = new MediaTrack("track-alice-audio", MediaType.AUDIO, 2001, codec_opus);
            alice.add_published_track(audio_track);

            assert(alice.published_tracks.size == 2);

            // 4. Simulcast Layer Switching and Rate Adaptation
            var switcher_bob = new LayerSwitcher("peer-bob", SpatialLayer.HIGH);
            var switcher_charlie = new LayerSwitcher("peer-charlie", SpatialLayer.LOW);

            // Bob has broadband bandwidth (3500 kbps) -> target HIGH
            switcher_bob.update_bandwidth(3500);
            assert(switcher_bob.target_layer == SpatialLayer.HIGH);

            // Charlie is on mobile connection (300 kbps) -> target LOW
            switcher_charlie.update_bandwidth(300);
            assert(switcher_charlie.target_layer == SpatialLayer.LOW);

            // Simulate incoming RTP packets from Alice on low and high layers
            var high_packet = new RtpPacket();
            high_packet.ssrc = 1001;
            high_packet.sequence_number = 500;
            high_packet.timestamp = 90000;
            high_packet.payload = new uint8[] { 0x10, 0x00, 0xFF }; // Mock keyframe

            var low_packet = new RtpPacket();
            low_packet.ssrc = 1003;
            low_packet.sequence_number = 100;
            low_packet.timestamp = 90000;
            low_packet.payload = new uint8[] { 0x10, 0x00, 0x77 };

            var forwarded_bob = switcher_bob.process_packet(SpatialLayer.HIGH, high_packet, true);
            assert(forwarded_bob != null);
            assert(forwarded_bob.ssrc == high_packet.ssrc);

            var forwarded_charlie = switcher_charlie.process_packet(SpatialLayer.LOW, low_packet, true);
            assert(forwarded_charlie != null);

            // 5. Multi-Participant Audio Mixing and Active Speaker Detection
            var active_detector = new ActiveSpeakerDetector();
            var mixer = new AudioMixer();

            // Alice speaks loudly: level = 10 dBov (near 0 dBov ceiling)
            active_detector.update_audio_level("peer-alice", 10, true);
            // Bob speaks softly: level = 90 dBov (near 127 dBov floor)
            active_detector.update_audio_level("peer-bob", 90, true);

            string current_speaker = active_detector.dominant_speaker;
            assert(current_speaker == "peer-alice");

            // Mix audio frames (960 samples = 20ms at 48kHz)
            int16[] alice_audio = new int16[AudioMixer.SAMPLES_PER_FRAME];
            int16[] bob_audio = new int16[AudioMixer.SAMPLES_PER_FRAME];
            for (int i = 0; i < AudioMixer.SAMPLES_PER_FRAME; i++) {
                alice_audio[i] = 1000;
                bob_audio[i] = 500;
            }

            mixer.put_audio_frame("peer-alice", alice_audio);
            mixer.put_audio_frame("peer-bob", bob_audio);

            // Get N-1 mix for Charlie (should receive Alice + Bob combined)
            int16[] charlie_mix = mixer.mix_minus_one("peer-charlie");
            assert(charlie_mix != null);
            assert(charlie_mix.length == AudioMixer.SAMPLES_PER_FRAME);
            // Linear mix: 1000 + 500 = 1500
            assert(charlie_mix[0] == 1500);

            // Get N-1 mix for Alice (should receive ONLY Bob's audio)
            int16[] alice_mix = mixer.mix_minus_one("peer-alice");
            assert(alice_mix != null);
            assert(alice_mix.length == AudioMixer.SAMPLES_PER_FRAME);
            assert(alice_mix[0] == 500);

            // 6. Peer Leave and Cleanup
            room.remove_peer("peer-alice");
            assert(room.peers.size == 3);
            assert(!room.peers.has_key("peer-alice"));
        });

        return Test.run();
    }
}
