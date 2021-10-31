/*
 * Solas: Real-Time WebRTC Media Engine
 * Embedded Static Web Console Assets
 */

namespace Solas.Network {

    public class StaticWebAssets : Object {

        public static HttpResponse? resolve_asset(string path) {
            if (path == "/" || path == "/index.html") {
                string html = get_index_html();
                return new HttpResponse(200, "text/html; charset=utf-8", html);
            } else if (path == "/style.css") {
                string css = get_style_css();
                return new HttpResponse(200, "text/css; charset=utf-8", css);
            } else if (path == "/app.js") {
                string js = get_app_js();
                return new HttpResponse(200, "application/javascript; charset=utf-8", js);
            }
            return null;
        }

        private static string get_index_html() {
            return "<!DOCTYPE html>\n" +
                   "<html lang=\"en\">\n" +
                   "<head>\n" +
                   "  <meta charset=\"UTF-8\">\n" +
                   "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n" +
                   "  <title>Solas WebRTC SFU Console</title>\n" +
                   "  <link rel=\"stylesheet\" href=\"/style.css\">\n" +
                   "</head>\n" +
                   "<body>\n" +
                   "  <header class=\"navbar\">\n" +
                   "    <div class=\"brand\">\n" +
                   "      <div class=\"logo-mark\">S</div>\n" +
                   "      <div>\n" +
                   "        <h1 class=\"logo-title\">Solas</h1>\n" +
                   "        <p class=\"logo-subtitle\">Real-Time WebRTC Media Engine</p>\n" +
                   "      </div>\n" +
                   "    </div>\n" +
                   "    <div class=\"nav-status\">\n" +
                   "      <span class=\"status-indicator\"></span>\n" +
                   "      <span id=\"server-status\">Connected</span>\n" +
                   "      <span class=\"badge\" id=\"uptime-badge\">Uptime: 0s</span>\n" +
                   "    </div>\n" +
                   "  </header>\n" +
                   "  <main class=\"container\">\n" +
                   "    <section class=\"metrics-grid\">\n" +
                   "      <div class=\"metric-card\">\n" +
                   "        <div class=\"metric-label\">Active Rooms</div>\n" +
                   "        <div class=\"metric-value\" id=\"val-rooms\">0</div>\n" +
                   "        <div class=\"metric-sub\">Multi-party topologies</div>\n" +
                   "      </div>\n" +
                   "      <div class=\"metric-card\">\n" +
                   "        <div class=\"metric-label\">Connected Peers</div>\n" +
                   "        <div class=\"metric-value\" id=\"val-peers\">0</div>\n" +
                   "        <div class=\"metric-sub\">Subscribers and publishers</div>\n" +
                   "      </div>\n" +
                   "      <div class=\"metric-card\">\n" +
                   "        <div class=\"metric-label\">Ingress Throughput</div>\n" +
                   "        <div class=\"metric-value\" id=\"val-bitrate\">0.00 <span class=\"unit\">kbps</span></div>\n" +
                   "        <div class=\"metric-sub\">Bandwidth utilization</div>\n" +
                   "      </div>\n" +
                   "      <div class=\"metric-card\">\n" +
                   "        <div class=\"metric-label\">Packets Routed</div>\n" +
                   "        <div class=\"metric-value\" id=\"val-packets\">0</div>\n" +
                   "        <div class=\"metric-sub\">Zero-copy forwarding</div>\n" +
                   "      </div>\n" +
                   "    </section>\n" +
                   "    <div class=\"content-split\">\n" +
                   "      <section class=\"panel main-panel\">\n" +
                   "        <div class=\"panel-header\">\n" +
                   "          <h2>Active Conference Rooms</h2>\n" +
                   "          <button class=\"btn btn-primary\" onclick=\"refreshRooms()\">Refresh</button>\n" +
                   "        </div>\n" +
                   "        <div id=\"rooms-container\" class=\"rooms-grid\">\n" +
                   "          <div class=\"empty-state\">No active rooms found. Connect peers via WebRTC signaling.</div>\n" +
                   "        </div>\n" +
                   "      </section>\n" +
                   "      <section class=\"panel side-panel\">\n" +
                   "        <div class=\"panel-header\">\n" +
                   "          <h2>Live Telemetry Monitor</h2>\n" +
                   "          <span class=\"badge badge-accent\">60 Hz</span>\n" +
                   "        </div>\n" +
                   "        <canvas id=\"throughput-chart\" width=\"400\" height=\"220\"></canvas>\n" +
                   "        <div class=\"telemetry-log\" id=\"telemetry-log\">\n" +
                   "          <div class=\"log-line\">[SYS] Solas telemetry engine initialized.</div>\n" +
                   "        </div>\n" +
                   "      </section>\n" +
                   "    </div>\n" +
                   "  </main>\n" +
                   "  <script src=\"/app.js\"></script>\n" +
                   "</body>\n" +
                   "</html>\n";
        }

        private static string get_style_css() {
            return ":root {\n" +
                   "  --bg-primary: #0a0d14;\n" +
                   "  --bg-secondary: #121722;\n" +
                   "  --bg-card: rgba(22, 29, 44, 0.7);\n" +
                   "  --border-color: rgba(255, 255, 255, 0.08);\n" +
                   "  --accent-cyan: #00e5ff;\n" +
                   "  --accent-emerald: #10b981;\n" +
                   "  --text-main: #f1f5f9;\n" +
                   "  --text-muted: #94a3b8;\n" +
                   "}\n" +
                   "body { background: var(--bg-primary); color: var(--text-main); font-family: -apple-system, sans-serif; margin: 0; }\n" +
                   ".navbar { display: flex; justify-content: space-between; align-items: center; padding: 1rem 2rem; background: var(--bg-secondary); border-bottom: 1px solid var(--border-color); }\n" +
                   ".brand { display: flex; align-items: center; gap: 1rem; }\n" +
                   ".logo-mark { width: 36px; height: 36px; background: #00e5ff; border-radius: 6px; display: flex; align-items: center; justify-content: center; font-weight: bold; color: #0a0d14; }\n" +
                   ".container { max-width: 1200px; margin: 2rem auto; padding: 0 1rem; }\n" +
                   ".metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1rem; margin-bottom: 2rem; }\n" +
                   ".metric-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; padding: 1.25rem; }\n" +
                   ".metric-value { font-size: 1.75rem; font-weight: 700; }\n" +
                   ".content-split { display: grid; grid-template-columns: 2fr 1fr; gap: 1rem; }\n" +
                   ".panel { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; padding: 1.25rem; }\n";
        }

        private static string get_app_js() {
            return "async function fetchMetrics() {\n" +
                   "  try {\n" +
                   "    const res = await fetch('/metrics');\n" +
                   "    const text = await res.text();\n" +
                   "    const lines = text.split('\\n');\n" +
                   "    for (const l of lines) {\n" +
                   "      if (l.startsWith('solas_active_rooms ')) document.getElementById('val-rooms').textContent = l.split(' ')[1];\n" +
                   "      if (l.startsWith('solas_active_peers ')) document.getElementById('val-peers').textContent = l.split(' ')[1];\n" +
                   "      if (l.startsWith('solas_rtp_packets_received_total ')) document.getElementById('val-packets').textContent = l.split(' ')[1];\n" +
                   "      if (l.startsWith('solas_current_bitrate_kbps ')) document.getElementById('val-bitrate').innerHTML = parseFloat(l.split(' ')[1]).toFixed(2) + ' <span class=\"unit\">kbps</span>';\n" +
                   "    }\n" +
                   "  } catch (e) {}\n" +
                   "}\n" +
                   "async function refreshRooms() {\n" +
                   "  try {\n" +
                   "    const res = await fetch('/api/v1/rooms');\n" +
                   "    const data = await res.json();\n" +
                   "    const el = document.getElementById('rooms-container');\n" +
                   "    if (!data.rooms || data.rooms.length === 0) {\n" +
                   "      el.innerHTML = '<div class=\"empty-state\">No active rooms.</div>';\n" +
                   "      return;\n" +
                   "    }\n" +
                   "    el.innerHTML = data.rooms.map(r => '<div class=\"room-card\"><h3>' + r.id + '</h3><p>Peers: ' + r.peers + '</p></div>').join('');\n" +
                   "  } catch (e) {}\n" +
                   "}\n" +
                   "document.addEventListener('DOMContentLoaded', () => {\n" +
                   "  fetchMetrics();\n" +
                   "  refreshRooms();\n" +
                   "  setInterval(fetchMetrics, 2000);\n" +
                   "  setInterval(refreshRooms, 5000);\n" +
                   "});\n";
        }
    }
}
