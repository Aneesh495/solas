/*
 * Solas: Real-Time WebRTC Media Engine
 * Session Recording Engine and ISO-BMFF Writer Test Suite
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Distribution;

public class TestRecording : Object {

    public static void test_mp4_writer_init_and_sample() {
        var writer = new Mp4Writer(1, 90000, true, 1280, 720);
        uint8[] init_seg = writer.generate_init_segment();

        /* Initialization segment must contain ftyp and moov boxes */
        assert(init_seg.length > 32);
        assert(init_seg[4] == 'f' && init_seg[5] == 't' && init_seg[6] == 'y' && init_seg[7] == 'p');

        /* Write a sample */
        uint8[] sample_data = new uint8[] { 0x00, 0x00, 0x01, 0x67, 0x42, 0x00 };
        uint8[] frag = writer.write_sample(sample_data, 3000, true);

        assert(frag.length > sample_data.length + 16);
        assert(frag[4] == 'm' && frag[5] == 'o' && frag[6] == 'o' && frag[7] == 'f');
    }

    public static void test_recording_session_lifecycle() {
        var session = new RecordingSession("rec-test-1", "conf-room-alpha");
        assert(!session.is_recording);
        assert(session.video_frame_count == 0);
        assert(session.audio_frame_count == 0);

        session.start();
        assert(session.is_recording);
        /* Session starts with video init + audio init */
        assert(session.get_segment_count() == 2);
        assert(session.total_bytes_recorded > 0);

        /* Record 3 video packets */
        for (int i = 0; i < 3; i++) {
            var vpkt = new RtpPacket();
            vpkt.sequence_number = (uint16) (100 + i);
            vpkt.timestamp = (uint32) (1000 + i * 3000);
            vpkt.payload = new uint8[500];
            session.record_video_packet(vpkt, i == 0);
        }

        /* Record 5 audio packets */
        for (int i = 0; i < 5; i++) {
            var apkt = new RtpPacket();
            apkt.sequence_number = (uint16) (200 + i);
            apkt.timestamp = (uint32) (1000 + i * 960);
            apkt.payload = new uint8[80];
            session.record_audio_packet(apkt);
        }

        session.stop();
        assert(!session.is_recording);
        assert(session.video_frame_count == 3);
        assert(session.audio_frame_count == 5);
        assert(session.get_segment_count() == 2 + 3 + 5); /* 10 total segments */
        assert(session.get_duration_ms() >= 0);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/recording/mp4_writer", test_mp4_writer_init_and_sample);
        Test.add_func("/recording/session_lifecycle", test_recording_session_lifecycle);

        return Test.run();
    }
}
