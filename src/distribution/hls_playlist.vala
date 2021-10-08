/*
 * Solas: Real-Time WebRTC Media Engine
 * HLS Master and Media Playlist Manager (RFC 8216)
 */

namespace Solas.Distribution {

    public class HlsPlaylistManager : Object {
        private Gee.ArrayList<MediaSegment> sliding_window;
        private size_t max_window_size;
        private double target_duration_secs;
        private uint32 media_sequence;

        public HlsPlaylistManager(size_t window_size = 5, double target_duration = 2.0) {
            this.sliding_window = new Gee.ArrayList<MediaSegment>();
            this.max_window_size = window_size;
            this.target_duration_secs = target_duration;
            this.media_sequence = 1;
        }

        public void add_segment(MediaSegment segment) {
            this.sliding_window.add(segment);
            while (this.sliding_window.size > this.max_window_size) {
                this.sliding_window.remove_at(0);
                this.media_sequence++;
            }
        }

        public string generate_media_playlist(string init_uri = "init.mp4") {
            var sb = new StringBuilder();
            sb.append("#EXTM3U\r\n");
            sb.append("#EXT-X-VERSION:7\r\n");
            sb.append_printf("#EXT-X-TARGETDURATION:%u\r\n", (uint) Math.ceil(this.target_duration_secs));
            sb.append_printf("#EXT-X-MEDIA-SEQUENCE:%u\r\n", this.media_sequence);
            sb.append_printf("#EXT-X-MAP:URI=\"%s\"\r\n", init_uri);

            foreach (var seg in this.sliding_window) {
                sb.append_printf("#EXTINF:%.3f,\r\n", seg.duration_seconds);
                sb.append_printf("segment_%u.m4s\r\n", seg.sequence_number);
            }

            return sb.str;
        }

        public string generate_master_playlist(string stream_name = "live") {
            var sb = new StringBuilder();
            sb.append("#EXTM3U\r\n");
            sb.append("#EXT-X-VERSION:7\r\n");
            sb.append("#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720,CODECS=\"avc1.42e01f,mp4a.40.2\"\r\n");
            sb.append_printf("%s_720p.m3u8\r\n", stream_name);
            sb.append("#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS=\"avc1.42e01f,mp4a.40.2\"\r\n");
            sb.append_printf("%s_360p.m3u8\r\n", stream_name);
            return sb.str;
        }

        public MediaSegment? get_segment(uint32 seq) {
            foreach (var seg in this.sliding_window) {
                if (seg.sequence_number == seq) {
                    return seg;
                }
            }
            return null;
        }
    }
}
