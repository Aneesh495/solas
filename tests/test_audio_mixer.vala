/*
 * Solas: Real-Time WebRTC Media Engine
 * Audio Resampler and Multi-Participant Mixer Test Suite
 */

using Solas.Core;
using Solas.Engine.Audio;

public class TestAudioMixer : Object {

    public static void test_resampler_identity() {
        var resampler = new AudioResampler(48000, 48000, 1);
        int16[] input = new int16[480];
        for (int i = 0; i < input.length; i++) {
            input[i] = (int16) (i * 10);
        }

        int16[] output = resampler.resample(input);
        assert(output.length == input.length);
        for (int i = 0; i < input.length; i++) {
            assert(output[i] == input[i]);
        }
    }

    public static void test_resampler_upsample() {
        /* 8kHz to 48kHz (ratio 1:6) */
        var resampler = new AudioResampler(8000, 48000, 1);
        int16[] input = new int16[160]; /* 20ms at 8kHz */
        for (int i = 0; i < input.length; i++) {
            input[i] = (int16) 1000;
        }

        int16[] output = resampler.resample(input);
        assert(output.length == 960); /* 20ms at 48kHz */
        assert(output[0] == 1000);
        assert(output[500] == 1000);
        assert(output[959] == 1000);
    }

    public static void test_resampler_downsample() {
        /* 48kHz to 16kHz (ratio 3:1) */
        var resampler = new AudioResampler(48000, 16000, 1);
        int16[] input = new int16[960]; /* 20ms at 48kHz */
        for (int i = 0; i < input.length; i++) {
            input[i] = (int16) (i * 2);
        }

        int16[] output = resampler.resample(input);
        assert(output.length == 320); /* 20ms at 16kHz */
        assert(output[0] == input[0]);
    }

    public static void test_audio_mixer_rms() {
        int16[] silence = new int16[960];
        double rms_silence = AudioMixer.calculate_rms_dbfs(silence);
        assert(rms_silence < -100.0);

        int16[] max_signal = new int16[960];
        for (int i = 0; i < 960; i++) {
            max_signal[i] = 32767;
        }
        double rms_max = AudioMixer.calculate_rms_dbfs(max_signal);
        assert(rms_max > -1.0 && rms_max <= 0.0);
    }

    public static void test_audio_mixer_n_minus_one() {
        var mixer = new AudioMixer();

        int16[] alice = new int16[960];
        int16[] bob = new int16[960];
        for (int i = 0; i < 960; i++) {
            alice[i] = 500;
            bob[i] = 1200;
        }

        mixer.put_audio_frame("alice", alice);
        mixer.put_audio_frame("bob", bob);

        /* Master mix should contain alice + bob */
        int16[] master = mixer.mix_master();
        assert(master.length == 960);
        assert(master[0] == 1700);

        /* Alice's N-1 mix must contain only Bob */
        int16[] alice_recv = mixer.mix_minus_one("alice");
        assert(alice_recv.length == 960);
        assert(alice_recv[0] == 1200);

        /* Bob's N-1 mix must contain only Alice */
        int16[] bob_recv = mixer.mix_minus_one("bob");
        assert(bob_recv.length == 960);
        assert(bob_recv[0] == 500);

        /* Charlie's N-1 mix receives both */
        int16[] charlie_recv = mixer.mix_minus_one("charlie");
        assert(charlie_recv[0] == 1700);

        mixer.clear();
        int16[] silent = mixer.mix_master();
        assert(silent[0] == 0);
    }

    public static void test_audio_mixer_soft_limiter() {
        var mixer = new AudioMixer();

        /* Two high volume signals that sum to 40000, exceeding 32767 */
        int16[] track1 = new int16[960];
        int16[] track2 = new int16[960];
        for (int i = 0; i < 960; i++) {
            track1[i] = 20000;
            track2[i] = 20000;
        }

        mixer.put_audio_frame("peer1", track1);
        mixer.put_audio_frame("peer2", track2);

        int16[] mixed = mixer.mix_master();
        /* Peak should be clamped at AudioMixer.CLIPPING_THRESHOLD (32000) */
        assert(mixed[0] == 32000);
        assert(mixed[959] == 32000);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/audio/resampler_identity", test_resampler_identity);
        Test.add_func("/audio/resampler_upsample", test_resampler_upsample);
        Test.add_func("/audio/resampler_downsample", test_resampler_downsample);
        Test.add_func("/audio/mixer_rms", test_audio_mixer_rms);
        Test.add_func("/audio/mixer_n_minus_one", test_audio_mixer_n_minus_one);
        Test.add_func("/audio/mixer_soft_limiter", test_audio_mixer_soft_limiter);

        return Test.run();
    }
}
