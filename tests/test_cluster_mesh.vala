/*
 * Solas: Real-Time WebRTC Media Engine
 * Inter-SFU Cascade Mesh and Edge Routing Test Suite
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Cluster;

public class TestClusterMesh : Object {

    public static void test_node_liveness() {
        var node = new CascadeNode("sfu-eu-1", "eu-central-1", "10.0.1.5", 7000);
        assert(node.is_alive);
        assert(node.rtt_ms == 10);

        node.record_heartbeat(35);
        assert(node.rtt_ms == 35);
        assert(node.check_liveness(1000));

        /* Simulate stale node */
        node.last_heartbeat_time_ms -= 6000;
        assert(!node.check_liveness(5000));
    }

    public static void test_selective_cascade_routing() {
        var router = new CascadeRouter("sfu-us-east");

        var eu_node = new CascadeNode("sfu-eu-1", "eu-central-1", "10.0.2.1", 7000);
        var ap_node = new CascadeNode("sfu-ap-1", "ap-northeast-1", "10.0.3.1", 7000);

        router.register_node(eu_node);
        router.register_node(ap_node);

        /* Initial state: no room subscriptions */
        assert(router.get_targets("room-general").size == 0);

        /* EU and AP nodes subscribe to room-general */
        router.subscribe_node("room-general", "sfu-eu-1");
        router.subscribe_node("room-general", "sfu-ap-1");

        assert(router.should_forward("room-general", "sfu-eu-1"));
        assert(router.should_forward("room-general", "sfu-ap-1"));
        assert(!router.should_forward("room-general", "sfu-unknown"));

        var targets = router.get_targets("room-general");
        assert(targets.size == 2);

        /* Route a test packet */
        int forwarded_count = 0;
        router.packet_forwarded.connect((room, target_id, seq) => {
            forwarded_count++;
        });

        var pkt = new RtpPacket();
        pkt.sequence_number = 777;
        int sent_nodes = router.route_packet("room-general", pkt);
        assert(sent_nodes == 2);
        assert(forwarded_count == 2);

        /* EU node unsubscribes when all its subscribers leave */
        router.unsubscribe_node("room-general", "sfu-eu-1");
        assert(!router.should_forward("room-general", "sfu-eu-1"));
        assert(router.get_targets("room-general").size == 1);

        /* Unregistering AP node cleans up */
        router.unregister_node("sfu-ap-1");
        assert(router.get_targets("room-general").size == 0);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/cluster/node_liveness", test_node_liveness);
        Test.add_func("/cluster/selective_routing", test_selective_cascade_routing);

        return Test.run();
    }
}
