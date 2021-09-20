/*
 * Solas: Real-Time WebRTC Media Engine
 * Codec Data Types and Frame Classifications
 */

namespace Solas.Media {

    public enum CodecId {
        UNKNOWN = 0,
        OPUS = 1,
        VP8 = 2,
        VP9 = 3,
        H264 = 4,
        AV1 = 5
    }

    public enum FrameType {
        UNKNOWN = 0,
        KEYFRAME = 1,
        DELTAFRAME = 2,
        AUDIO_FRAME = 3
    }

    public class VideoFrameInfo : Object {
        public FrameType frame_type { get; set; }
        public uint32 width { get; set; }
        public uint32 height { get; set; }
        public int picture_id { get; set; }
        public bool is_partition_start { get; set; }

        public VideoFrameInfo() {
            this.frame_type = FrameType.UNKNOWN;
            this.width = 0;
            this.height = 0;
            this.picture_id = -1;
            this.is_partition_start = false;
        }
    }
}
