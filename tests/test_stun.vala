/*
 * Unit tests for Solas.Protocol.Stun
 */
using Solas.Core;
using Solas.Crypto;
using Solas.Protocol.Stun;

void test_stun_binding_request_roundtrip() {
    var req = StunMessage.create_binding_request();
    req.add_attribute(new UsernameAttribute("solas_user:test_client"));
    req.add_attribute(new PriorityAttribute(2130706431U));
    req.add_attribute(new UseCandidateAttribute());

    uint8[] key = "secret_ice_key".data;
    try {
        uint8[] wire = req.serialize(key, true);
        assert(wire.length > 20);

        var parsed = StunMessage.parse(wire);
        assert(parsed.message_type == MessageType.BINDING_REQUEST);

        var user = parsed.get_attribute<UsernameAttribute>();
        assert(user != null);
        assert(user.username == "solas_user:test_client");

        var prio = parsed.get_attribute<PriorityAttribute>();
        assert(prio != null);
        assert(prio.priority == 2130706431U);

        var uc = parsed.get_attribute<UseCandidateAttribute>();
        assert(uc != null);

        var mi = parsed.get_attribute<MessageIntegrityAttribute>();
        assert(mi != null);
        assert(mi.hmac.length == 20);

        var fp = parsed.get_attribute<FingerprintAttribute>();
        assert(fp != null);
    } catch (GLib.Error e) {
        assert_not_reached();
    }
}

void test_stun_binding_response_xor_mapped() {
    var req = StunMessage.create_binding_request();
    var resp = StunMessage.create_binding_response(req, "192.0.2.1", 32768);

    try {
        uint8[] wire = resp.serialize(null, true);
        var parsed = StunMessage.parse(wire);
        assert(parsed.message_type == MessageType.BINDING_SUCCESS_RESPONSE);

        var xor_attr = parsed.get_attribute<XorMappedAddressAttribute>();
        assert(xor_attr != null);
        assert(xor_attr.address == "192.0.2.1");
        assert(xor_attr.port == 32768);
    } catch (GLib.Error e) {
        assert_not_reached();
    }
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/stun/binding_request_roundtrip", test_stun_binding_request_roundtrip);
    Test.add_func("/solas/stun/binding_response_xor_mapped", test_stun_binding_response_xor_mapped);
    Test.run();
}
