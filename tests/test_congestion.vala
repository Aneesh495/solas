/*
 * Unit tests for Solas.Engine.Congestion
 */
using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Engine.Congestion;

void test_trendline_and_overuse_detection() {
    var estimator = new TrendlineEstimator(15);

    /* 1. Simulate constant network delay (normal state) */
    double send_t = 1000.0;
    double arr_t = 1050.0;
    for (int i = 0; i < 15; i++) {
        estimator.update(send_t, arr_t);
        send_t += 20.0;
        arr_t += 20.0;
    }
    assert(estimator.state == BandwidthUsageState.NORMAL);

    /* 2. Simulate growing queuing delay (overuse): arrival delay increases progressively */
    for (int i = 0; i < 20; i++) {
        send_t += 20.0;
        arr_t += 50.0; /* Growing queue: +30ms per frame */
        estimator.update(send_t, arr_t);
    }
    assert(estimator.state == BandwidthUsageState.OVERUSING);
}

void test_aimd_and_loss_controllers() {
    var aimd = new AimdRateController(2000000.0); /* 2.0 Mbps */
    assert(aimd.bitrate_bps == 2000000.0);

    /* Normal usage triggers additive increase */
    double r1 = aimd.update(BandwidthUsageState.NORMAL, 1000000);
    assert(r1 > 2000000.0);

    /* Overuse triggers multiplicative decrease (beta = 0.85) */
    double pre_drop = aimd.bitrate_bps;
    double r2 = aimd.update(BandwidthUsageState.OVERUSING, 2000000);
    assert(r2 < pre_drop);
    assert(Math.fabs(r2 - (pre_drop * 0.85)) < 1.0);

    /* Loss controller test */
    var loss_ctrl = new LossBasedController(2000000.0);
    /* 0% loss: increase */
    double lr1 = loss_ctrl.on_receiver_report(0);
    assert(lr1 > 2000000.0);

    /* 20% loss: fraction_lost = 51 / 256 ~= 0.20 => decrease */
    double lr2 = loss_ctrl.on_receiver_report(51);
    assert(lr2 < lr1);
}

void test_pacer_priority_and_budget() {
    var pacer = new Pacer(8000000.0); /* 8 Mbps */

    var audio_pkt = new RtpPacket(); audio_pkt.payload = "Audio".data;
    var delta_pkt = new RtpPacket(); delta_pkt.payload = "DeltaVideoFrame".data;
    var key_pkt = new RtpPacket();   key_pkt.payload = "KeyVideoFrame".data;

    /* Enqueue in reverse priority: delta, key, then audio */
    int64 t0 = Clock.get_monotonic_time_us();
    pacer.enqueue(PacketPriority.VIDEO_DELTA, delta_pkt, t0);
    pacer.enqueue(PacketPriority.VIDEO_KEYFRAME, key_pkt, t0);
    pacer.enqueue(PacketPriority.AUDIO, audio_pkt, t0);

    assert(pacer.queued_packets == 3);

    /* Audio must poll first due to highest priority */
    var p1 = pacer.poll_packet(t0);
    assert(p1 != null && (string) p1.payload == "Audio");

    /* Next must be Keyframe */
    var p2 = pacer.poll_packet(t0 + 5000);
    assert(p2 != null && (string) p2.payload == "KeyVideoFrame");

    /* Next must be Delta */
    var p3 = pacer.poll_packet(t0 + 10000);
    assert(p3 != null && (string) p3.payload == "DeltaVideoFrame");

    assert(pacer.queued_packets == 0);
}

void main(string[] args) {
    Test.init(ref args);
    Test.add_func("/solas/congestion/trendline_and_overuse", test_trendline_and_overuse_detection);
    Test.add_func("/solas/congestion/aimd_and_loss", test_aimd_and_loss_controllers);
    Test.add_func("/solas/congestion/pacer_priority", test_pacer_priority_and_budget);
    Test.run();
}
