/*
 * Unit tests for Solas.Distribution
 */
using Solas.Core;
using Solas.Distribution;

void test_fmp4_boxes() {
    uint8[] ftyp = Fmp4Box.create_ftyp();
    assert(ftyp.length >= 8);
    /* First 4 bytes: size (32), next 4 bytes: "ftyp" */
    var reader = new ByteReader(ftyp);
    try {
        uint32 size = reader.read_uint32_be();
        string fourcc = reader.read_string(4);
        assert(size == ftyp.length);
        assert(fourcc == "ftyp");
    } catch (GLib.Error e) {
        assert_not_reached();
    }

    uint8[] moov = Fmp4Box.create_moov_init(1, 90000, true);
    assert(moov.length >= 8);
    var moov_reader = new ByteReader(moov);
    try {
        uint32 size = moov_reader.read_uint32_be();
        string fourcc = moov_reader.read_string(4);
        assert(size == moov.length);
        assert(fourcc == "moov");
    } catch (GLib.Error e) {
        assert_not_reached();
    }
}

void test_live_segmenter_and_playlist() {
    var segmenter = new LiveSegmenter(1, 90000, true, 1.0); /* 1.0s target duration */
    var playlist_mgr = new HlsPlaylistManager(3, 1.0);

    uint8[] init_seg = segmenter.get_initialization_segment();
    assert(init_seg.length > 0);

    int segments_emitted = 0;
    segmenter.segment_ready.connect((seg) => {
        segments_emitted++;
        playlist_mgr.add_segment(seg);
    });

    int64 t0 = Clock.get_monotonic_time_us();

    /* Push sample 1 */
    segmenter.push_sample("FrameSample1".data, true, 3000, t0);

    /* Push sample 2 after 1.1s (with keyframe = true, triggering segment boundary) */
    segmenter.push_sample("FrameSample2".data, true, 3000, t0 + 1100000);
    assert(segments_emitted == 1);

    /* Push sample 3 after 2.2s */
    segmenter.push_sample("FrameSample3".data, true, 3000, t0 + 2200000);
    assert(segments_emitted == 2);

    /* Verify Media Playlist */
    string m3u8 = playlist_mgr.generate_media_playlist("init.mp4");
    assert(m3u8.contains("#EXTM3U"));
    assert(m3u8.contains("#EXT-X-TARGETDURATION:1"));
    assert(m3u8.contains("#EXT-X-MAP:URI=\"init.mp4\""));
    assert(m3u8.contains("segment_1.m4s"));

    /* Verify Master Playlist */
    string master = playlist_mgr.generate_master_playlist("solas_stream");
    assert(master.contains("solas_stream_720p.m3u8"));
    assert(master.contains("solas_stream_360p.m3u8"));
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/hls/fmp4_boxes", test_fmp4_boxes);
    Test.add_func("/solas/hls/live_segmenter_and_playlist", test_live_segmenter_and_playlist);
    Test.run();
}
