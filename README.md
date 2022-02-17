# Solas

[![CI](https://github.com/Aneesh495/solas/actions/workflows/ci.yml/badge.svg)](https://github.com/Aneesh495/solas/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Language](https://img.shields.io/badge/Language-Vala_%2F_C-purple.svg)](https://wiki.gnome.org/Projects/Vala)
[![Architecture](https://img.shields.io/badge/Architecture-WebRTC_SFU-green.svg)](docs/ARCHITECTURE.md)

**Solas** is an ultra-low-latency, zero-copy WebRTC Selective Forwarding Unit (SFU) and real-time media distribution engine engineered in **Vala** and compiled directly to native C via the GObject type system. Solas delivers sub-millisecond audio and video packet routing, seamless simulcast layer switching, scalable video coding (SVC), end-to-end encryption (E2EE), and multi-region cascade clustering for mission-critical real-time communications.

---

## Architecture Overview

```
                                  +-----------------------------------------------+
                                  |                 Client Layer                  |
                                  |  Web Browsers (WebRTC) / Mobile / OBS / CLI   |
                                  +-----------------------------------------------+
                                            |                         ^
                        Signaling (WSS)     |                         | Media (SRTP/UDP)
                        WHIP/WHEP (HTTP)    v                         v
                                  +-----------------------------------------------+
                                  |                Network Gateway                |
                                  |   Single-Port UDP Multiplexer (RFC 7983)      |
                                  |   HTTP/1.1 REST API & WebSocket Signaling     |
                                  +-----------------------------------------------+
                                            |                         |
                                            v                         v
                       +----------------------------+   +----------------------------+
                       |      Security & ICE        |   |    RTP / RTCP Core Engine  |
                       | - RFC 8489 STUN Integrity  |   | - 64-bit SeqNum Unwrapper  |
                       | - RFC 8445 ICE Checklist   |   | - Header Extensions (TWCC) |
                       | - RFC 5764 DTLS-SRTP Keys  |   | - Compound RTCP Demuxer    |
                       | - RFC 9605 SFrame E2EE     |   | - RFC 3611 XR VoIP Blocks  |
                       +----------------------------+   +----------------------------+
                                            \                         /
                                             \                       /
                                              v                     v
                                  +-----------------------------------------------+
                                  |             Jitter & Feedback Engine          |
                                  | - Adaptive Playout Delay Estimator            |
                                  | - State-Space Kalman Playout Smoothing        |
                                  | - Dynamic NACK Queue (RTT-Aware Backoff)      |
                                  | - RFC 8627 FlexFEC XOR Parity Recovery        |
                                  +-----------------------------------------------+
                                                         |
                                                         v
                                  +-----------------------------------------------+
                                  |         Bandwidth & Congestion Control        |
                                  | - Google Congestion Control (GCC Trendline)   |
                                  | - Loss-Based AIMD Rate Reconciler             |
                                  | - Bandwidth Probing Cluster Controller        |
                                  | - Priority Leaky-Bucket Packet Pacer          |
                                  +-----------------------------------------------+
                                                         |
                                                         v
                                  +-----------------------------------------------+
                                  |            Selective Forwarding Unit          |
                                  | - Room & Participant Topology Graph           |
                                  | - Simulcast Spatial Layer Switcher            |
                                  | - Active Speaker Energy Follower (dBov)       |
                                  | - N-1 Multi-Participant Audio Linear Mixer    |
                                  | - SCTP Data Channel Multiplexer (RFC 8832)    |
                                  +-----------------------------------------------+
                                            |                         |
                                            v                         v
                       +----------------------------+   +----------------------------+
                       | Distribution & Clustering  |   |    Telemetry & Metrics     |
                       | - LL-HLS Fragmented MP4    |   | - OpenMetrics / Prometheus |
                       | - Continuous MP4 Recorder  |   | - Latency Histograms       |
                       | - WHIP Ingest / WHEP Egress|   | - Packet Loss & RTT Gauges |
                       | - Inter-SFU Cascade Mesh   |   | - Zero-Copy Slab Allocator |
                       +----------------------------+   +----------------------------+
```

---

## Key Features

- **Native C Performance with Modern OOP**: Engineered in Vala, combining concise object-oriented safety with zero garbage collection overhead and direct OpenSSL / POSIX C integration.
- **RFC 7983 Unified Single-Port Multiplexing**: Distinguishes STUN, DTLS, SRTP, and SRTCP packets on a single UDP socket in O(1) time.
- **Hardware-Accelerated Cryptography**: Native C engine for AES-128/256-CTR, HMAC-SHA1/256, and hardware CRC32 checksums.
- **RFC 9605 Secure Frame (SFrame) E2EE**: Native frame encryption support for end-to-end encrypted group calls.
- **Full Video Scalability**:
  - **Simulcast**: Dynamic keyframe-gated layer switching (Low 180p, Medium 360p, High 720p/1080p) with sequence number and timestamp translation.
  - **Scalable Video Coding (SVC)**: In-place temporal and spatial layer filtering for VP9 Flexible Mode and AV1 OBU streams.
- **State-Space Kalman Filter Playout Delay**: Real-time network jitter smoothing via two-dimensional Kalman delay state estimation.
- **Google Congestion Control (GCC)**: Trendline delay-gradient estimator and loss-based AIMD controller coupled with priority leaky-bucket pacing.
- **RFC 8627 FlexFEC XOR Parity**: Proactive forward error correction for instantaneous packet loss recovery without NACK RTT latency.
- **RFC 9724 WHIP & WHEP Ingest/Egress**: Standardized HTTP media endpoints for hardware encoders, OBS Studio, and mobile broadcasters.
- **Inter-SFU Cascade Mesh**: Geo-distributed multi-node mesh forwarding supporting over 1.4 million routed packets per second.
- **Zero-Copy Slab Allocator**: Pre-allocated contiguous memory pools eliminating heap fragmentation under multi-gigabit workloads.
- **Dual Client SDKs**: First-class async Python client SDK (`sdk/python`) and typed browser TypeScript SDK (`sdk/ts`).

---

## IETF RFC Standards Compliance

| RFC Standard | Description | Subsystem |
| :--- | :--- | :--- |
| **RFC 3550** | Real-Time Transport Protocol (RTP) & RTCP | `src/protocol/rtp`, `src/protocol/rtcp` |
| **RFC 3611** | RTCP Extended Reports (XR) VoIP Metrics Blocks | `src/protocol/rtcp/feedback_xr.vala` |
| **RFC 3711** | Secure Real-time Transport Protocol (SRTP / SRTCP) | `src/protocol/srtp` |
| **RFC 4566 / 8866** | Session Description Protocol (SDP) & BUNDLE | `src/protocol/sdp` |
| **RFC 4960** | Stream Control Transmission Protocol (SCTP) | `src/protocol/sctp` |
| **RFC 5389 / 8489** | Session Traversal Utilities for NAT (STUN) | `src/protocol/stun` |
| **RFC 5764** | DTLS Extension to Establish Keys for SRTP | `src/protocol/dtls` |
| **RFC 5766** | Traversal Using Relays around NAT (TURN) | `src/protocol/turn` |
| **RFC 6184** | RTP Payload Format for H.264 Video (STAP-A / FU-A) | `src/media/depacketizer_h264.vala` |
| **RFC 7587** | RTP Payload Format for Opus Audio | `src/media/depacketizer_opus.vala` |
| **RFC 7741** | RTP Payload Format for VP8 Video | `src/media/depacketizer_vp8.vala` |
| **RFC 7983** | Multiplexing Scheme for STUN, DTLS, and RTP | `src/network/protocol_demuxer.vala` |
| **RFC 8445** | Interactive Connectivity Establishment (ICE Full) | `src/protocol/ice` |
| **RFC 8627** | Flexible Forward Error Correction (FlexFEC) | `src/engine/fec` |
| **RFC 8832** | WebRTC Data Channel Establishment Protocol (DCEP) | `src/protocol/sctp/datachannel_session.vala` |
| **RFC 8837** | DiffServ Differentiated Services Code Point (DSCP) | `src/network/qos_controller.vala` |
| **RFC 8888** | Transport-Wide Congestion Control (TWCC) | `src/protocol/rtcp/feedback_twcc.vala` |
| **RFC 9053 / AV1** | RTP Payload Format for AV1 Video (OBU) | `src/media/depacketizer_av1.vala` |
| **RFC 9605** | Secure Frame (SFrame) Media Encryption | `src/crypto/sframe_cipher.vala` |
| **RFC 9724** | WebRTC HTTP Ingestion Protocol (WHIP) | `src/network/whip_endpoint.vala` |

---

## Performance Benchmarks

Measured on Apple Silicon (M-series, ARM64) and Linux x86_64:

```
Routing Latency Percentiles (Single Core):
  p50:    18 us
  p90:    34 us
  p95:    52 us
  p99:   112 us
  p99.9: 245 us

Cluster Forwarding Throughput:
  Cascade Mesh (16 Nodes): 1,438,900 forwards/sec (42% CPU on 1 core)
  Simulcast 720p:          1,125,000 pkts/sec across 250 publishers
```

---

## Getting Started

### Prerequisites

#### macOS (Homebrew)
```bash
brew install vala meson ninja pkg-config glib libgee json-glib openssl@3
```

#### Ubuntu / Debian
```bash
sudo apt-get update && sudo apt-get install -y \
    valac meson ninja-build pkg-config \
    libglib2.0-dev libgee-0.8-dev libjson-glib-dev libssl-dev
```

### Build & Run Test Suites

```bash
# Clone the repository
git clone https://github.com/Aneesh495/solas.git
cd solas

# Setup and compile with Meson and Ninja
meson setup build --buildtype=debugoptimized
ninja -C build

# Execute the 35+ automated test suites
ninja -C build test
```

### Launch Solas Server

```bash
./build/solas-server --config config/solas.json
```

The server initializes:
- **HTTP REST & WHIP/WHEP API**: `http://localhost:8080`
- **Embedded Web Console**: `http://localhost:8080/`
- **Prometheus Telemetry**: `http://localhost:8080/metrics`
- **WebSocket Signaling**: `ws://localhost:8080/ws`
- **UDP Media Multiplexer**: `0.0.0.0:50000`

### Interactive Administration CLI

Inspect rooms, peers, and forwarding metrics in real time:

```bash
./build/solas-cli --server http://localhost:8080 stats
./build/solas-cli --server http://localhost:8080 rooms
```

### Synthetic Load Benchmarking

Simulate high-density conference traffic under network impairment:

```bash
./build/solas-bench --rooms 10 --publishers 50 --subscribers 200 --loss 5.0
```

---

## Docker Deployment

Run a multi-node cluster with Prometheus monitoring via Docker Compose:

```bash
docker compose up -d
```

---

## Repository Structure

```
solas/
├── config/              # Default daemon and Prometheus scrape configurations
├── docs/                # Architecture, API specifications, and guides
│   ├── ARCHITECTURE.md
│   ├── API_SPEC.md
│   ├── BENCHMARKS.md
│   ├── CONTRIBUTING.md
│   ├── DEPLOYMENT_GUIDE.md
│   ├── RFC_INDEX.md
│   └── SIMULCAST_SVC_GUIDE.md
├── scripts/             # Quality enforcement and benchmark scripts
├── sdk/                 # Client software development kits
│   ├── python/          # Async Python client SDK and conference examples
│   └── ts/              # Typed browser TypeScript SDK with simulcast
├── src/                 # Vala & C native source tree
│   ├── bench/           # Synthetic traffic generator & impairment simulator
│   ├── cli/             # Interactive terminal administration tool
│   ├── cluster/         # Inter-SFU cascade mesh router & edge topology
│   ├── core/            # Zero-copy ByteBuffer, clock, stats, and slab allocator
│   ├── crypto/          # Native C engine, AES-CTR, CRC32, and SFrame
│   ├── distribution/    # ISO-BMFF fMP4 segmenter, LL-HLS, and MP4 recorder
│   ├── engine/          # Audio mixer, jitter buffers, GCC congestion, SFU
│   ├── media/           # Codec depacketizers (AV1, VP9 SVC, VP8, H.264, Opus)
│   ├── network/         # Demuxer, HTTP, WebSocket, WHIP, WHEP, DSCP QoS
│   ├── protocol/        # STUN, SDP, RTP, RTCP, SRTP, DTLS, TURN, SCTP
│   └── server/          # Signaling session, ICE agent, and server daemon
├── tests/               # 35+ comprehensive unit, fuzz, and integration suites
└── web/                 # Real-time dashboard web monitoring console
```

---

## License

Solas is released under the [Apache 2.0 License](LICENSE).
