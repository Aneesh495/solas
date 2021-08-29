/*
 * Unit tests for Solas.Core
 */
using Solas.Core;

void test_byte_buffer() {
    var buf = new ByteBuffer(16, 64);
    assert(buf.size == 0);
    assert(buf.available_headroom == 64);

    buf.append_uint8(0xAA);
    buf.append_uint8(0xBB);
    assert(buf.size == 2);
    assert(buf.get_at(0) == 0xAA);
    assert(buf.get_at(1) == 0xBB);

    uint8[] extra = { 0x01, 0x02, 0x03 };
    buf.append_bytes(extra, extra.length);
    assert(buf.size == 5);
    assert(buf.get_at(4) == 0x03);

    /* Test prepend headroom */
    uint8[] hdr = { 0xFF, 0xEE };
    buf.prepend_bytes(hdr, hdr.length);
    assert(buf.size == 7);
    assert(buf.get_at(0) == 0xFF);
    assert(buf.get_at(1) == 0xEE);
    assert(buf.get_at(2) == 0xAA);

    /* Test slicing */
    var sl = buf.slice(2, 3);
    assert(sl.size == 3);
    assert(sl.get_at(0) == 0xAA);
    assert(sl.get_at(1) == 0xBB);
    assert(sl.get_at(2) == 0x01);
}

void test_reader_writer() {
    var writer = new ByteWriter(128);
    writer.write_uint8(0x42);
    writer.write_uint16_be(0x1234);
    writer.write_uint32_be(0xDEADBEEFU);
    writer.write_uint64_be(0x0123456789ABCDEFULL);
    writer.write_string("SOLAS");

    var reader = new ByteReader(writer.to_array());
    assert(reader.remaining == 1 + 2 + 4 + 8 + 5);
    try {
        assert(reader.read_uint8() == 0x42);
        assert(reader.read_uint16_be() == 0x1234);
        assert(reader.read_uint32_be() == 0xDEADBEEFU);
        assert(reader.read_uint64_be() == 0x0123456789ABCDEFULL);
        assert(reader.read_string(5) == "SOLAS");
        assert(!reader.has_remaining);
    } catch (ReaderError e) {
        assert_not_reached();
    }

    /* Bitstream test */
    var bwriter = new ByteWriter();
    bwriter.write_bits(0x5, 3); /* 101 */
    bwriter.write_bits(0x3, 2); /* 11  */
    bwriter.write_bits(0x7, 3); /* 111 => 10111111 = 0xBF */
    bwriter.flush_bits();

    var breader = new ByteReader(bwriter.to_array());
    try {
        assert(breader.read_bits(3) == 0x5);
        assert(breader.read_bits(2) == 0x3);
        assert(breader.read_bits(3) == 0x7);
    } catch (ReaderError e) {
        assert_not_reached();
    }
}

void test_clock_and_stats() {
    int64 t1 = Clock.get_monotonic_time_ms();
    assert(t1 > 0);

    uint64 ntp = Clock.get_ntp_timestamp_64();
    assert(ntp > 0);
    uint32 compact_ntp = Clock.get_compact_ntp_32(ntp);
    assert(compact_ntp > 0);

    /* Sequence number comparison with rollover */
    assert(Clock.sequence_number_newer(10, 5));
    assert(Clock.sequence_number_newer(0, 65535));
    assert(!Clock.sequence_number_newer(65535, 0));
    assert(Clock.sequence_number_delta(0, 65535) == 1);
    assert(Clock.sequence_number_delta(65535, 0) == -1);

    /* Jitter filter */
    var jf = new JitterFilter(90000);
    jf.update(1000, 100000);
    jf.update(2000, 111111);
    assert(jf.jitter_in_clock_units >= 0);

    /* Bitrate meter */
    var bm = new BitrateMeter(1000);
    bm.record(1000, 1000000);
    bm.record(2000, 1500000);
    assert(bm.get_bitrate_bps(1600000) > 0.0);
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/core/byte_buffer", test_byte_buffer);
    Test.add_func("/solas/core/reader_writer", test_reader_writer);
    Test.add_func("/solas/core/clock_and_stats", test_clock_and_stats);
    Test.run();
}
