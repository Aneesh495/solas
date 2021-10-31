/*
 * Solas WebRTC SFU Console Client
 */

const throughputData = [];
const maxDataPoints = 30;

function appendLog(msg) {
  const log = document.getElementById("telemetry-log");
  if (!log) return;
  const line = document.createElement("div");
  line.className = "log-line";
  const now = new Date().toISOString().substring(11, 19);
  line.textContent = `[${now}] ${msg}`;
  log.appendChild(line);
  log.scrollTop = log.scrollHeight;
}

async function fetchMetrics() {
  try {
    const res = await fetch("/metrics");
    if (!res.ok) return;
    const text = await res.text();

    const lines = text.split("\n");
    let rooms = 0;
    let peers = 0;
    let packets = 0;
    let bitrate = 0.0;
    let uptime = 0;

    for (const l of lines) {
      if (l.startsWith("solas_active_rooms ")) rooms = parseInt(l.split(" ")[1]);
      if (l.startsWith("solas_active_peers ")) peers = parseInt(l.split(" ")[1]);
      if (l.startsWith("solas_rtp_packets_received_total ")) packets = parseInt(l.split(" ")[1]);
      if (l.startsWith("solas_current_bitrate_kbps ")) bitrate = parseFloat(l.split(" ")[1]);
      if (l.startsWith("solas_uptime_seconds ")) uptime = parseInt(l.split(" ")[1]);
    }

    document.getElementById("val-rooms").textContent = rooms;
    document.getElementById("val-peers").textContent = peers;
    document.getElementById("val-packets").textContent = packets.toLocaleString();
    document.getElementById("val-bitrate").innerHTML = `${bitrate.toFixed(2)} <span class="unit">kbps</span>`;
    document.getElementById("uptime-badge").textContent = `Uptime: ${uptime}s`;

    document.getElementById("server-status").textContent = "Operational";

    throughputData.push(bitrate);
    if (throughputData.length > maxDataPoints) throughputData.shift();
    drawChart();
  } catch (err) {
    document.getElementById("server-status").textContent = "Offline";
  }
}

async function refreshRooms() {
  try {
    const res = await fetch("/api/v1/rooms");
    if (!res.ok) return;
    const data = await res.json();
    const container = document.getElementById("rooms-container");
    container.innerHTML = "";

    if (!data.rooms || data.rooms.length === 0) {
      container.innerHTML = '<div class="empty-state">No active rooms found. Connect peers via WebRTC signaling.</div>';
      return;
    }

    data.rooms.forEach(r => {
      const card = document.createElement("div");
      card.className = "room-card";
      card.innerHTML = `
        <div class="room-title">${escapeHtml(r.id)}</div>
        <div class="room-meta">
          <span>Peers: <strong>${r.peers}</strong></span> |
          <span>Dominant Speaker: <strong>${r.dominant_speaker || "None"}</strong></span>
        </div>
      `;
      container.appendChild(card);
    });
  } catch (err) {
    appendLog("Error refreshing rooms: " + err);
  }
}

function drawChart() {
  const canvas = document.getElementById("throughput-chart");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  const w = canvas.width;
  const h = canvas.height;

  ctx.clearRect(0, 0, w, h);

  /* Draw grid lines */
  ctx.strokeStyle = "rgba(255, 255, 255, 0.05)";
  ctx.lineWidth = 1;
  for (let y = 0; y < h; y += 40) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }

  if (throughputData.length < 2) return;

  const maxVal = Math.max(...throughputData, 100);

  /* Draw throughput line */
  ctx.beginPath();
  ctx.strokeStyle = "#00e5ff";
  ctx.lineWidth = 2;

  for (let i = 0; i < throughputData.length; i++) {
    const x = (i / (maxDataPoints - 1)) * w;
    const y = h - (throughputData[i] / maxVal) * (h - 20) - 10;
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.stroke();
}

function escapeHtml(str) {
  return str.replace(/[&<>'"]/g, tag => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
  }[tag] || tag));
}

document.addEventListener("DOMContentLoaded", () => {
  appendLog("Dashboard connected to Solas SFU engine.");
  fetchMetrics();
  refreshRooms();
  setInterval(fetchMetrics, 2000);
  setInterval(refreshRooms, 5000);
});
