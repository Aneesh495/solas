/*
 * Solas: Real-Time WebRTC Media Engine
 * Multi-Participant Linear Audio Mixer and Soft Saturation Limiter
 */

using Solas.Core;

namespace Solas.Engine.Audio {

    public class AudioFrame : Object {
        public int16[] samples;

        public AudioFrame(int16[] pcm) {
            this.samples = pcm;
        }
    }

    public class AudioMixer : Object {
        public const size_t SAMPLES_PER_FRAME = 960; /* 20ms at 48kHz */
        public const double CLIPPING_THRESHOLD = 32000.0;

        private Gee.HashMap<string, AudioFrame> active_buffers;

        public AudioMixer() {
            this.active_buffers = new Gee.HashMap<string, AudioFrame>();
        }

        public void put_audio_frame(string peer_id, int16[] samples) {
            this.active_buffers.set(peer_id, new AudioFrame(samples));
        }

        public void clear() {
            this.active_buffers.clear();
        }

        /**
         * Mixes all participant audio into a single conference composite.
         */
        public int16[] mix_master() {
            return this.mix_streams(null);
        }

        /**
         * Computes an N-1 mix for a specific participant (all participants except peer_id).
         * Eliminates self-echo in multi-party audio conferences.
         */
        public int16[] mix_minus_one(string excluded_peer_id) {
            return this.mix_streams(excluded_peer_id);
        }

        private int16[] mix_streams(string? excluded_peer) {
            double[] accum = new double[SAMPLES_PER_FRAME];
            int count = 0;

            foreach (var entry in this.active_buffers.entries) {
                if (excluded_peer != null && entry.key == excluded_peer) {
                    continue;
                }

                int16[] pcm = entry.value.samples;
                size_t n = (pcm.length < SAMPLES_PER_FRAME) ? pcm.length : SAMPLES_PER_FRAME;
                for (size_t i = 0; i < n; i++) {
                    accum[i] += (double) pcm[i];
                }
                count++;
            }

            if (count == 0) {
                return new int16[SAMPLES_PER_FRAME];
            }

            /* Peak detection and soft limiter */
            double peak = 0.0;
            for (size_t i = 0; i < SAMPLES_PER_FRAME; i++) {
                double abs_val = Math.fabs(accum[i]);
                if (abs_val > peak) peak = abs_val;
            }

            double gain = 1.0;
            if (peak > CLIPPING_THRESHOLD) {
                gain = CLIPPING_THRESHOLD / peak;
            }

            int16[] result = new int16[SAMPLES_PER_FRAME];
            for (size_t i = 0; i < SAMPLES_PER_FRAME; i++) {
                double v = accum[i] * gain;
                if (v > 32767.0) v = 32767.0;
                else if (v < -32768.0) v = -32768.0;
                result[i] = (int16) v;
            }

            return result;
        }

        /**
         * Calculates Root Mean Square (RMS) energy in dBFS.
         */
        public static double calculate_rms_dbfs(int16[] pcm) {
            if (pcm.length == 0) return -127.0;

            double sum_sq = 0.0;
            for (size_t i = 0; i < pcm.length; i++) {
                double sample = (double) pcm[i] / 32768.0;
                sum_sq += sample * sample;
            }

            double rms = Math.sqrt(sum_sq / (double) pcm.length);
            if (rms < 0.00001) return -127.0;

            return 20.0 * Math.log10(rms);
        }
    }
}
