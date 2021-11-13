/*
 * Solas: Real-Time WebRTC Media Engine
 * TURN Protocol RFC 5766 Verification Suite
 */

using Solas.Core;
using Solas.Protocol.Turn;

public class TestTurn : Object {

    public static void test_channel_data_framing() {
        uint8[] raw_data = { 0xAA, 0xBB, 0xCC };
        var ch_msg = new ChannelDataMessage(0x4001, raw_data);

        uint8[] serialized = ch_msg.serialize();
        /* Header: 2-byte channel, 2-byte length, 3-byte payload + 1-byte padding = 8 bytes */
        assert(serialized.length == 8);
        assert(serialized[0] == 0x40);
        assert(serialized[1] == 0x01);
        assert(serialized[2] == 0x00);
        assert(serialized[3] == 0x03);
        assert(serialized[4] == 0xAA);
        assert(serialized[7] == 0x00); /* Padding */

        /* Parsing */
        var parsed = ChannelDataMessage.parse(serialized);
        assert(parsed != null);
        assert(parsed.channel_number == 0x4001);
        assert(parsed.data.length == 3);
        assert(parsed.data[0] == 0xAA);
        assert(parsed.data[2] == 0xCC);

        /* Out of range channel numbers must be rejected */
        uint8[] invalid_ch = { 0x10, 0x00, 0x00, 0x01, 0xFF };
        assert(ChannelDataMessage.parse(invalid_ch) == null);
    }

    public static void test_turn_attributes() {
        var lifetime_attr = new LifetimeAttribute(1800);
        assert(lifetime_attr.lifetime_seconds == 1800);

        var writer = new ByteWriter(16);
        uint8[] tid = new uint8[12];
        lifetime_attr.serialize(writer, tid);

        var reader = new ByteReader(writer.to_array());
        try {
            uint16 type = reader.read_uint16_be();
            assert(type == (uint16) TurnAttributeType.LIFETIME);
            uint16 len = reader.read_uint16_be();
            assert(len == 4);
            var parsed_life = LifetimeAttribute.parse(reader);
            assert(parsed_life.lifetime_seconds == 1800);
        } catch (ReaderError e) {
            assert_not_reached();
        }

        var ch_attr = new ChannelNumberAttribute(0x4005);
        var writer2 = new ByteWriter(16);
        ch_attr.serialize(writer2, tid);

        var reader2 = new ByteReader(writer2.to_array());
        try {
            uint16 type = reader2.read_uint16_be();
            assert(type == (uint16) TurnAttributeType.CHANNEL_NUMBER);
            uint16 len = reader2.read_uint16_be();
            assert(len == 4);
            var parsed_ch = ChannelNumberAttribute.parse(reader2);
            assert(parsed_ch.channel_number == 0x4005);
        } catch (ReaderError e) {
            assert_not_reached();
        }
    }

    public static void test_turn_allocation_lifecycle() {
        var alloc = new TurnAllocation("alloc-1", "192.168.1.100:54321", "203.0.113.5", 34780, 600);
        assert(alloc.allocation_id == "alloc-1");
        assert(alloc.relayed_ip == "203.0.113.5");
        assert(alloc.relayed_port == 34780);
        assert(!alloc.is_expired);

        /* Permissions */
        assert(!alloc.has_permission("198.51.100.1"));
        alloc.add_permission("198.51.100.1");
        assert(alloc.has_permission("198.51.100.1"));

        /* Channel Binding */
        bool bound = alloc.bind_channel(0x4000, "198.51.100.1", 50000);
        assert(bound);
        assert(alloc.get_channel_for_peer("198.51.100.1", 50000) == 0x4000);

        var peer_addr = alloc.get_peer_for_channel(0x4000);
        assert(peer_addr != null);
        assert(peer_addr.ip == "198.51.100.1");
        assert(peer_addr.port == 50000);

        /* Refresh */
        alloc.refresh(1200);
        assert(alloc.lifetime_seconds == 1200);
        assert(!alloc.is_expired);

        /* Explicit Deallocation (Refresh with 0) */
        alloc.refresh(0);
        assert(alloc.is_expired);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/turn/channel_data_framing", test_channel_data_framing);
        Test.add_func("/turn/attributes", test_turn_attributes);
        Test.add_func("/turn/allocation_lifecycle", test_turn_allocation_lifecycle);

        return Test.run();
    }
}
