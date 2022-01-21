# Solas Production Deployment & Edge Clustering Guide

This guide covers production deployment architectures, Linux kernel performance tuning, container orchestration, firewall NAT traversal, and multi-region cascade mesh topology for the Solas WebRTC Selective Forwarding Unit.

---

## 1. Operating System & Kernel Network Tuning

For high-density media forwarding (10,000+ concurrent audio/video streams per server instance), configure the host kernel network parameters via `/etc/sysctl.d/99-solas.conf`:

```ini
# Maximum socket receive and send buffer sizes across all protocols (64 MB)
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 33554432
net.core.wmem_default = 33554432

# Increase network device backlog queue to prevent packet drops during micro-bursts
net.core.netdev_max_backlog = 100000

# UDP buffer limits (min, default, max in pages)
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# File descriptors and memory map allocations
fs.file-max = 2097152
vm.max_map_count = 262144

# BBR Congestion Control for signaling and HTTP egress
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

Apply immediately with:
```bash
sudo sysctl --system
```

Increase process file descriptor and real-time scheduling limits in `/etc/security/limits.d/99-solas.conf`:
```ini
solas    soft    nofile    1048576
solas    hard    nofile    1048576
solas    soft    rtprio    99
solas    hard    rtprio    99
```

---

## 2. Network & Firewall Port Allocation

Solas features an RFC 7983 unified UDP demultiplexer that allows STUN, DTLS, and SRTP traffic to share a single port, drastically simplifying firewall configurations:

| Port | Protocol | Purpose | Direction |
| :--- | :--- | :--- | :--- |
| **8080 / 8443** | TCP | WebSocket Signaling & HTTP REST API (WHIP/WHEP) | Inbound |
| **50000** | UDP | Unified Media Gateway (STUN, DTLS, SRTP, SCTP) | Inbound / Outbound |
| **3478** | UDP/TCP | TURN Relay & STUN Connectivity Checks | Inbound |
| **7000** | UDP | Inter-SFU Cascade Mesh Interconnect | Inbound (Private VPC) |
| **9090** | TCP | OpenMetrics Prometheus Telemetry Endpoint | Inbound (Internal Monitoring) |

---

## 3. Systemd Service Configuration

Create `/etc/systemd/system/solas.service`:

```ini
[Unit]
Description=Solas Real-Time WebRTC Media Engine
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=solas
Group=solas
WorkingDirectory=/var/lib/solas
ExecStart=/usr/local/bin/solas-server --config /etc/solas/config.json
Restart=always
RestartSec=3s

# Resource Constraints & Hardening
LimitNOFILE=1048576
LimitNPROC=524288
CPUSchedulingPolicy=rr
CPUSchedulingPriority=50
MemoryMax=16G
StandardOutput=journal
StandardError=journal
SyslogIdentifier=solas

# Sandboxing
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

---

## 4. Multi-Region Cascade Mesh Architecture

For global multi-party conferences with low latency, Solas deploys a geo-distributed cascade topology:

```
                          [ Origin SFU: us-east ]
                         /           |           \
                        /            |            \
                       v             v             v
       [ Edge SFU: eu-west ]   [ Edge SFU: us-west ]   [ Edge SFU: ap-east ]
             |                        |                        |
       [ EU Clients ]           [ US Clients ]           [ Asia Clients ]
```

### Routing Rules
1. **Local Forwarding First**: If publisher and subscriber reside in the same geographic region, packets are forwarded locally within the edge SFU with 0ms inter-region latency.
2. **Selective Forwarding Tree**: The origin node only mirrors media packets across inter-region links if at least one subscriber in that target region is active in the room.
3. **Partition Resilience**: Edge nodes exchange continuous 1000ms heartbeats over port 7000. If an origin node becomes unreachable, edge nodes elect a new regional coordinator automatically.
