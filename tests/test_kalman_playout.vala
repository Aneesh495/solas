/*
 * Solas: Real-Time WebRTC Media Engine
 * Kalman Filter Jitter Playout Estimator Test Suite
 */

using Solas.Core;
using Solas.Engine.Jitter;

public class TestKalmanPlayout : Object {

    public static void test_convergence_zero_jitter() {
        var kf = new KalmanPlayoutEstimator(0.001, 0.05, 2.0);

        int64 send_ms = 0;
        int64 recv_ms = 0;

        /* Feed 50 packets with perfectly constant 20ms inter-arrival times */
        for (int i = 0; i < 50; i++) {
            send_ms += 20;
            recv_ms += 20;
            kf.update(send_ms, recv_ms);
        }

        /* Jitter estimate should be near zero, bounded by min_playout_delay (20ms) */
        assert(kf.state_x < 2.0);
        assert(kf.error_cov_p < 0.1);
        double delay = kf.calculate_target_delay();
        assert(delay >= 20.0 && delay < 25.0);
    }

    public static void test_step_response_jitter() {
        var kf = new KalmanPlayoutEstimator(0.01, 0.1, 2.0);

        int64 send_ms = 0;
        int64 recv_ms = 0;

        /* Initial 20 packets: steady */
        for (int i = 0; i < 20; i++) {
            send_ms += 20;
            recv_ms += 20;
            kf.update(send_ms, recv_ms);
        }

        /* Next 30 packets: alternating 10ms and 70ms arrivals (jitter ~60ms) */
        for (int i = 0; i < 30; i++) {
            send_ms += 20;
            int64 delta = (i % 2 == 0) ? 10 : 70;
            recv_ms += delta;
            kf.update(send_ms, recv_ms);
        }

        /* Estimated jitter must adapt to the new regime */
        assert(kf.state_x > 20.0);
        assert(kf.calculate_target_delay() > 25.0);
    }

    public static void test_outlier_rejection() {
        var kf = new KalmanPlayoutEstimator(0.001, 0.05, 2.5);

        int64 send_ms = 0;
        int64 recv_ms = 0;

        /* Converge on 5ms jitter */
        for (int i = 0; i < 40; i++) {
            send_ms += 20;
            recv_ms += 25;
            kf.update(send_ms, recv_ms);
        }

        double stable_x = kf.state_x;

        /* Single isolated spike: 300ms delay */
        send_ms += 20;
        recv_ms += 300;
        kf.update(send_ms, recv_ms);

        /* Outlier rejection prevents state_x from jumping immediately to 300ms */
        assert(kf.state_x < 60.0);

        /* Immediately followed by normal packets */
        for (int i = 0; i < 5; i++) {
            send_ms += 20;
            recv_ms += 25;
            kf.update(send_ms, recv_ms);
        }

        assert(kf.state_x < stable_x + 10.0);
    }

    public static void test_filter_reset() {
        var kf = new KalmanPlayoutEstimator();
        kf.update(100, 200);
        kf.update(120, 250);
        assert(kf.state_x != 30.0 || kf.error_cov_p != 1.0);

        kf.reset();
        assert(kf.state_x == 30.0);
        assert(kf.error_cov_p == 1.0);
    }

    public static int main(string[] args) {
        Test.init(ref args);

        Test.add_func("/kalman/convergence_zero_jitter", test_convergence_zero_jitter);
        Test.add_func("/kalman/step_response", test_step_response_jitter);
        Test.add_func("/kalman/outlier_rejection", test_outlier_rejection);
        Test.add_func("/kalman/reset", test_filter_reset);

        return Test.run();
    }
}
