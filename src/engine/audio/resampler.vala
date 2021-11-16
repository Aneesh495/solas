/*
 * Solas: Real-Time WebRTC Media Engine
 * Linear Audio Sample Rate Resampler and Format Converter
 */

using Solas.Core;

namespace Solas.Engine.Audio {

    public class AudioResampler : Object {
        public uint32 input_rate { get; set; }
        public uint32 output_rate { get; set; }
        public int channels { get; set; }

        public AudioResampler(uint32 in_rate = 48000, uint32 out_rate = 48000, int channels = 1) {
            this.input_rate = in_rate;
            this.output_rate = out_rate;
            this.channels = channels;
        }

        /**
         * Resamples signed 16-bit PCM samples from input_rate to output_rate using linear interpolation.
         */
        public int16[] resample(int16[] input) {
            if (this.input_rate == this.output_rate || input.length == 0) {
                int16[] copy = new int16[input.length];
                for (size_t i = 0; i < input.length; i++) copy[i] = input[i];
                return copy;
            }

            double ratio = (double) this.input_rate / (double) this.output_rate;
            size_t out_samples = (size_t) ((double) input.length / ratio);
            int16[] output = new int16[out_samples];

            for (size_t i = 0; i < out_samples; i++) {
                double src_idx = (double) i * ratio;
                size_t idx0 = (size_t) src_idx;
                size_t idx1 = idx0 + 1;
                if (idx1 >= input.length) idx1 = input.length - 1;

                double frac = src_idx - (double) idx0;
                double val = (1.0 - frac) * (double) input[idx0] + frac * (double) input[idx1];

                /* Clamp to int16 range */
                if (val > 32767.0) val = 32767.0;
                else if (val < -32768.0) val = -32768.0;

                output[i] = (int16) val;
            }

            return output;
        }
    }
}
