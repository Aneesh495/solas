/*
 * Solas: Real-Time WebRTC Media Engine
 * High-Throughput Structured Diagnostic Logger
 */

namespace Solas.Core {

    public enum LogLevel {
        TRACE = 0,
        DEBUG = 1,
        INFO = 2,
        WARN = 3,
        ERROR = 4
    }

    public class Logger : Object {
        private static LogLevel global_level = LogLevel.INFO;
        private static Mutex log_mutex;

        public static void set_level(LogLevel level) {
            global_level = level;
        }

        public static bool is_enabled(LogLevel level) {
            return level >= global_level;
        }

        public static void trace(string module_name, string format, ...) {
            if (is_enabled(LogLevel.TRACE)) {
                var va = va_list();
                log_formatted(LogLevel.TRACE, module_name, format, va);
            }
        }

        public static void debug(string module_name, string format, ...) {
            if (is_enabled(LogLevel.DEBUG)) {
                var va = va_list();
                log_formatted(LogLevel.DEBUG, module_name, format, va);
            }
        }

        public static void info(string module_name, string format, ...) {
            if (is_enabled(LogLevel.INFO)) {
                var va = va_list();
                log_formatted(LogLevel.INFO, module_name, format, va);
            }
        }

        public static void warn(string module_name, string format, ...) {
            if (is_enabled(LogLevel.WARN)) {
                var va = va_list();
                log_formatted(LogLevel.WARN, module_name, format, va);
            }
        }

        public static void error(string module_name, string format, ...) {
            if (is_enabled(LogLevel.ERROR)) {
                var va = va_list();
                log_formatted(LogLevel.ERROR, module_name, format, va);
            }
        }

        private static void log_formatted(LogLevel level, string module_name, string format, va_list args) {
            int64 now_us = Clock.get_monotonic_time_us();
            long secs = (long) (now_us / 1000000);
            long us = (long) (now_us % 1000000);

            string level_str;
            string color_code;

            switch (level) {
                case LogLevel.TRACE:
                    level_str = "TRC";
                    color_code = "\033[90m";
                    break;
                case LogLevel.DEBUG:
                    level_str = "DBG";
                    color_code = "\033[36m";
                    break;
                case LogLevel.INFO:
                    level_str = "INF";
                    color_code = "\033[32m";
                    break;
                case LogLevel.WARN:
                    level_str = "WRN";
                    color_code = "\033[33m";
                    break;
                case LogLevel.ERROR:
                default:
                    level_str = "ERR";
                    color_code = "\033[31m";
                    break;
            }

            string msg = format.vprintf(args);

            log_mutex.lock();
            stdout.printf("%s[%ld.%06ld] [%s] [%s] %s\033[0m\n", color_code, secs, us, level_str, module_name, msg);
            stdout.flush();
            log_mutex.unlock();
        }
    }
}
