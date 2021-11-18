/*
 * Solas: Real-Time WebRTC Media Engine
 * SCTP and WebRTC DataChannel Test Suite (RFC 8831 / RFC 8832)
 */

using Solas.Core;
using Solas.Protocol.Sctp;

public class TestDataChannel : Object {

    public static void test_sctp_chunk_framing() {
        uint8[] payload = { 0x01, 0x02, 0x03 }; /* 3 bytes payload, total chunk 7 bytes */
        var chunk = new SctpChunk(SctpChunkType.HEARTBEAT, 0x00, payload);

        /* 4 bytes header + 3 bytes payload = 7 bytes -> padded to 8 bytes */
        assert(chunk.get_wire_size() == 8);

        var writer = new ByteWriter(16);
        chunk.serialize(writer);
        uint8[] wire = writer.to_array();
        assert(wire.length == 8);
        assert(wire[0] == (uint8) SctpChunkType.HEARTBEAT);
        assert(wire[2] == 0x00 && wire[3] == 0x07); /* Length is unpadded = 7 */

        var reader = new ByteReader(wire);
        try {
            var parsed = SctpChunk.parse(reader);
            assert(parsed.chunk_type == SctpChunkType.HEARTBEAT);
            assert(parsed.payload.length == 3);
            assert(parsed.payload[0] == 0x01 && parsed.payload[2] == 0x03);
        } catch (SctpError e) {
            assert_not_reached();
        }
    }

    public static void test_sctp_packet_serialization() {
        var pkt = new SctpPacket(5000, 5000, (uint32) 0xCAFEBABE);
        uint8[] dummy = { 0xAA, 0xBB, 0xCC, 0xDD };
        pkt.add_chunk(new SctpChunk(SctpChunkType.HEARTBEAT, 0, dummy));

        uint8[] wire = pkt.serialize();
        assert(wire.length == 12 + 8); /* 12 common + 8 chunk */

        try {
            var parsed = SctpPacket.parse(wire);
            assert(parsed.src_port == 5000);
            assert(parsed.dst_port == 5000);
            assert(parsed.verification_tag == 0xCAFEBABE);
            assert(parsed.chunks.size == 1);
            assert(parsed.chunks[0].chunk_type == SctpChunkType.HEARTBEAT);
        } catch (SctpError e) {
            assert_not_reached();
        }
    }

    public static void test_dcep_open_serialization() {
        var open_msg = new DcepOpenMessage("solas-control", "json", DataChannelChannelType.RELIABLE, 10, 0);
        uint8[] wire = open_msg.serialize();

        try {
            var parsed = DcepOpenMessage.parse(wire);
            assert(parsed.label == "solas-control");
            assert(parsed.protocol == "json");
            assert(parsed.channel_type == DataChannelChannelType.RELIABLE);
            assert(parsed.priority == 10);
        } catch (SctpError e) {
            assert_not_reached();
        }
    }

    public static void test_datachannel_session_e2e() {
        var alice_session = new DataChannelSession(5000, 5000);
        var bob_session = new DataChannelSession(5000, 5000);

        /* 1. Alice opens channel 1 */
        var open_pkt = alice_session.create_open_packet(1, "chat", "text/plain");
        uint8[] wire1 = open_pkt.serialize();

        /* 2. Bob handles Alice's OPEN packet */
        try {
            var bob_parsed = SctpPacket.parse(wire1);
            var ack_pkt = bob_session.handle_packet(bob_parsed);
            assert(ack_pkt != null);

            var bob_channel = bob_session.get_channel(1);
            assert(bob_channel != null);
            assert(bob_channel.label == "chat");
            assert(bob_channel.is_open);

            /* 3. Alice handles Bob's ACK packet */
            uint8[] wire2 = ack_pkt.serialize();
            var alice_parsed = SctpPacket.parse(wire2);
            alice_session.handle_packet(alice_parsed);

            var alice_channel = alice_session.get_channel(1);
            assert(alice_channel != null);
            assert(alice_channel.is_open);

            /* 4. Alice sends text message to Bob */
            string received_text = "";
            bob_channel.text_message_received.connect((msg) => {
                received_text = msg;
            });

            var text_pkt = alice_session.send_text(1, "Solas WebRTC DataChannel Active");
            uint8[] wire3 = text_pkt.serialize();
            var bob_text_parsed = SctpPacket.parse(wire3);
            bob_session.handle_packet(bob_text_parsed);

            assert(received_text == "Solas WebRTC DataChannel Active");

            /* 5. Bob sends binary payload to Alice */
            uint8[] received_bytes = new uint8[0];
            alice_channel.binary_message_received.connect((data) => {
                received_bytes = data;
            });

            uint8[] bin_data = { 0xDE, 0xAD, 0xBE, 0xEF };
            var bin_pkt = bob_session.send_binary(1, bin_data);
            uint8[] wire4 = bin_pkt.serialize();
            var alice_bin_parsed = SctpPacket.parse(wire4);
            alice_session.handle_packet(alice_bin_parsed);

            assert(received_bytes.length == 4);
            assert(received_bytes[0] == 0xDE && received_bytes[3] == 0xEF);

        } catch (SctpError e) {
            assert_not_reached();
        }
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/datachannel/sctp_chunk_framing", test_sctp_chunk_framing);
        Test.add_func("/datachannel/sctp_packet_serialization", test_sctp_packet_serialization);
        Test.add_func("/datachannel/dcep_open_serialization", test_dcep_open_serialization);
        Test.add_func("/datachannel/session_e2e", test_datachannel_session_e2e);

        return Test.run();
    }
}
