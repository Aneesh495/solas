/*
 * Unit tests for Solas.Media
 */
using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Media;

void test_vp8_depacketizer_keyframe() {
    var depack = new DepacketizerVp8();

    /* Synthesize VP8 Keyframe RTP Packet:
     * Byte 0: X=1, S=1, PartID=0 => 0x90
     * Byte 1: I=1, L=0, T=0, K=0 => 0x80
     * Byte 2: 7-bit PictureID 42 => 0x2A
     * Byte 3: Frame hdr 0: P=0 (keyframe) => 0x00
     * Byte 4..5: Version & show_frame => 0x00 0x00
     * Byte 6..8: Sync code 0x9D 0x01 0x2A
     * Byte 9..10: Width 1280 (0x0500) LE => 0x00 0x05
     * Byte 11..12: Height 720 (0x02D0) LE => 0xD0 0x02
     */
    uint8[] vp8_payload = {
        0x90, 0x80, 0x2A,
        0x00, 0x00, 0x00,
        0x9D, 0x01, 0x2A,
        0x00, 0x05,
        0xD0, 0x02,
        0xAA, 0xBB, 0xCC
    };

    var pkt = new RtpPacket();
    pkt.payload = vp8_payload;

    assert(depack.is_keyframe(pkt));
    var info = depack.parse_frame_info(pkt);
    assert(info != null);
    assert(info.frame_type == FrameType.KEYFRAME);
    assert(info.width == 1280);
    assert(info.height == 720);
    assert(info.picture_id == 42);

    /* Delta frame: P=1 in frame header */
    vp8_payload[3] = 0x01;
    pkt.payload = vp8_payload;
    assert(!depack.is_keyframe(pkt));
}

void test_h264_depacketizer() {
    var depack = new DepacketizerH264();

    /* 1. Single NALU IDR slice (type 5) */
    var pkt_idr = new RtpPacket();
    pkt_idr.payload = { 0x65, 0x01, 0x02, 0x03 }; /* 0x65 & 0x1F = 5 */
    assert(depack.is_keyframe(pkt_idr));

    /* 2. Single NALU non-IDR slice (type 1) */
    var pkt_slice = new RtpPacket();
    pkt_slice.payload = { 0x41, 0x01, 0x02, 0x03 }; /* 0x41 & 0x1F = 1 */
    assert(!depack.is_keyframe(pkt_slice));

    /* 3. STAP-A packet aggregating SPS (type 7) and PPS (type 8) */
    var pkt_stapa = new RtpPacket();
    pkt_stapa.payload = {
        0x78, /* STAP-A header: Type 24 */
        0x00, 0x03, 0x67, 0x42, 0x00, /* NAL size 3, SPS (0x67 & 0x1F = 7) */
        0x00, 0x02, 0x68, 0xCE         /* NAL size 2, PPS (0x68 & 0x1F = 8) */
    };
    assert(depack.is_keyframe(pkt_stapa));

    /* 4. FU-A packet starting IDR slice: FU header S=1, Type=5 */
    var pkt_fua = new RtpPacket();
    pkt_fua.payload = {
        0x7C,       /* FU indicator: Type 28 */
        0x85,       /* FU header: S=1, E=0, R=0, Type=5 */
        0x10, 0x20  /* Slice payload */
    };
    assert(depack.is_keyframe(pkt_fua));

    /* Extracted payload must reconstruct NAL header */
    uint8[] reconstructed = depack.extract_payload(pkt_fua);
    assert(reconstructed.length == 3);
    assert((reconstructed[0] & 0x1F) == 5);
}

void test_opus_depacketizer() {
    var depack = new DepacketizerOpus();
    var pkt = new RtpPacket();
    pkt.payload = { 0xF8, 0xFF, 0xFE, 0x01, 0x7F };
    assert(depack.is_keyframe(pkt));

    double energy = DepacketizerOpus.calculate_approximate_energy_db(pkt.payload);
    assert(energy <= 0.0 && energy >= -127.0);
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/media/vp8_depacketizer", test_vp8_depacketizer_keyframe);
    Test.add_func("/solas/media/h264_depacketizer", test_h264_depacketizer);
    Test.add_func("/solas/media/opus_depacketizer", test_opus_depacketizer);
    Test.run();
}
