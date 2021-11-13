/*
 * Solas: Real-Time WebRTC Media Engine
 * Full ICE RFC 8445 Checklist and Pair Priority Verification Suite
 */

using Solas.Core;
using Solas.Protocol.Ice;

public class TestIceFull : Object {

    public static void test_candidate_priority_calculation() {
        /* RFC 8445 Section 5.1.2.1 formula:
         * priority = (2^24)*(type preference) + (2^8)*(local preference) + (2^0)*(256 - component) */
        uint32 prio_host = FullCandidate.calculate_priority(IceCandidateType.HOST, 65535, IceComponent.RTP);
        uint32 prio_srflx = FullCandidate.calculate_priority(IceCandidateType.SERVER_REFLEXIVE, 65535, IceComponent.RTP);
        uint32 prio_relay = FullCandidate.calculate_priority(IceCandidateType.RELAYED, 65535, IceComponent.RTP);

        assert(prio_host > prio_srflx);
        assert(prio_srflx > prio_relay);
        assert((prio_host & 0xFF) == 255); /* 256 - 1 */
    }

    public static void test_pair_priority_and_ordering() {
        /* Local host candidate */
        uint32 local_prio = FullCandidate.calculate_priority(IceCandidateType.HOST, 65535, IceComponent.RTP);
        var c_local = new FullCandidate("1", IceComponent.RTP, "UDP", local_prio, "192.168.1.50", 5004, IceCandidateType.HOST);

        /* Remote host candidate */
        uint32 remote_prio = FullCandidate.calculate_priority(IceCandidateType.HOST, 65535, IceComponent.RTP);
        var c_remote_host = new FullCandidate("2", IceComponent.RTP, "UDP", remote_prio, "192.168.1.60", 60000, IceCandidateType.HOST);

        /* Remote srflx candidate */
        uint32 remote_srflx_prio = FullCandidate.calculate_priority(IceCandidateType.SERVER_REFLEXIVE, 65535, IceComponent.RTP);
        var c_remote_srflx = new FullCandidate("3", IceComponent.RTP, "UDP", remote_srflx_prio, "203.0.113.1", 60000, IceCandidateType.SERVER_REFLEXIVE);

        uint64 pair_prio_host = CandidatePair.compute_pair_priority(local_prio, remote_prio, true);
        uint64 pair_prio_srflx = CandidatePair.compute_pair_priority(local_prio, remote_srflx_prio, true);

        assert(pair_prio_host > pair_prio_srflx);

        /* Checklist pair formation and sorting */
        var locals = new Gee.ArrayList<FullCandidate>();
        locals.add(c_local);

        var remotes = new Gee.ArrayList<FullCandidate>();
        remotes.add(c_remote_srflx);
        remotes.add(c_remote_host);

        var checklist = new IceChecklist(true);
        checklist.form_pairs(locals, remotes);

        assert(checklist.pairs.size == 2);
        /* Highest priority pair must be first (host-host) */
        assert(checklist.pairs.get(0).remote.candidate_type == IceCandidateType.HOST);
        /* First pair must be unfrozen to WAITING */
        assert(checklist.pairs.get(0).state == CandidatePairState.WAITING);
        /* Second pair must remain FROZEN */
        assert(checklist.pairs.get(1).state == CandidatePairState.FROZEN);

        /* Next waiting pair retrieval */
        var check_pair = checklist.get_next_waiting_pair();
        assert(check_pair != null);
        assert(check_pair.state == CandidatePairState.IN_PROGRESS);

        /* Mark success and nomination */
        checklist.mark_pair_succeeded(check_pair, true, 12500);
        assert(check_pair.state == CandidatePairState.SUCCEEDED);
        assert(check_pair.nominated == true);
        assert(check_pair.rtt_us == 12500);
        assert(checklist.state == CheckListState.COMPLETED);
        assert(checklist.nominated_pair == check_pair);
        assert(checklist.valid_list.size == 1);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/ice_full/priority_calculation", test_candidate_priority_calculation);
        Test.add_func("/ice_full/pair_priority_and_ordering", test_pair_priority_and_ordering);

        return Test.run();
    }
}
