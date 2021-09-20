/*
 * Solas: Real-Time WebRTC Media Engine
 * Media Depacketizer Base Interface
 */

using Solas.Core;
using Solas.Protocol.Rtp;

namespace Solas.Media {

    public abstract class MediaDepacketizer : Object {
        public CodecId codec_id { get; construct; }

        public abstract bool is_keyframe(RtpPacket packet);
        public abstract uint8[] extract_payload(RtpPacket packet);
    }
}
