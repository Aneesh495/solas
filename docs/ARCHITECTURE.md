# Solas Architecture Specification

Solas is a high-performance WebRTC Selective Forwarding Unit (SFU) and real-time adaptive media distribution engine engineered in Vala. It compiles directly to native C via the GObject type system, leveraging non-blocking asynchronous event loops (GMainLoop / GIO) and zero-copy packet buffers to achieve sub-millisecond audio and video packet routing.

## 1. System Overview

```
                                  +-----------------------------------------------+
                                  |                 Client Layer                  |
                                  |  Web Browsers (WebRTC) / Mobile / OBS / CLI   |
                                  +-----------------------------------------------+
                                            |                         ^
                        Signaling (WSS)     |                         | Media (SRTP/UDP)
                                            v                         v
                                  +-----------------------------------------------+
                                  |                Network Gateway                |
                                  |   Single-Port UDP Multiplexer (STUN/DTLS/RTP) |
                                  |   HTTP/1.1 REST API & WebSocket Signaling     |
                                  +-----------------------------------------------+
                                            |                         |
                                            v                         v
                       +----------------------------+   +----------------------------+
                       |      Security & ICE        |   |    RTP / RTCP Core Engine  |
                       | - STUN Binding & Integrity |   | - 64-bit SeqNum Unwrapping |
                       | - DTLS-SRTP Key Exchanger  |   | - Header Extensions (TWCC) |
                       | - Replay Protection Window |   | - RTCP Compound Demuxer    |
                       +----------------------------+   +----------------------------+
                                            \                         /
                                             \                       /
                                              v                     v
                                  +-----------------------------------------------+
                                  |             Jitter & Feedback Engine          |
                                  | - Playout Delay Variance Estimator            |
                                  | - Dynamic NACK Queue (RTT-Aware Backoff)      |
                                  | - Video Keyframe & Dependency Tracking        |
                                  +-----------------------------------------------+
                                                         |
                                                         v
                                  +-----------------------------------------------+
                                  |         Bandwidth & Congestion Control        |
                                  | - Google Congestion Control (GCC Trendline)   |
                                  | - Loss-Based AIMD Rate Reconciler             |
                                  | - Leaky Bucket Pacer & Padding Prober         |
                                  +-----------------------------------------------+
                                                         |
                                                         v
                                  +-----------------------------------------------+
                                  |            Selective Forwarding Unit          |
                                  | - Room & Participant Topology Graph           |
                                  | - Simulcast Dynamic Spatial Layer Switcher    |
                                  | - Audio Energy Level Follower & Active Speaker|
                                  | - Packet Retransmission Cache (Per-SSRC Ring) |
                                  +-----------------------------------------------+
                                            |                         |
                                            v                         v
                       +----------------------------+   +----------------------------+
                       |    Low-Latency HLS         |   |    Telemetry & Metrics     |
                       | - Fragmented MP4 (fMP4)    |   | - OpenMetrics / Prometheus |
                       | - Dynamic M3U8 Playlist    |   | - Sliding Percentiles      |
                       | - Sub-Second Chunk Slicing |   | - Packet Loss & RTT Gauges |
                       +----------------------------+   +----------------------------+
```

## 2. Demultiplexing Pipeline

Solas operates on a unified UDP listener socket per worker core. Incoming datagrams are classified in O(1) time by examining the first byte:

1. Values 0 to 1: STUN packet (RFC 5389 / RFC 8489). Routed to the STUN message parser for connectivity checks and NAT traversal.
2. Values 20 to 63: DTLS handshake packet (RFC 6347). Forwarded to the TLS cryptographic state machine for session key agreement.
3. Values 128 to 191: RTP or RTCP packet (RFC 3550).
   - If payload type is between 64 and 95 (or between 200 and 211), the datagram is demuxed as RTCP.
   - Otherwise, the datagram is demuxed as RTP media.

## 3. Memory Model and Zero-Copy Slicing

All high-frequency packet processing employs the `Solas.Core.ByteBuffer` abstraction:
- Reference-counted contiguous memory allocations.
- Fixed 64-byte prepend headroom for encapsulation headers (SRTP auth tags, transport headers).
- Zero-copy buffer slicing via `ByteSlice`, preventing memory allocations during forwarding.
- Thread-local memory pools for recycling buffer allocations.

## 4. Congestion Control Mechanics

Bandwidth estimation combines delay-based and loss-based filters:
- Delay-based estimation: Computes inter-arrival delta versus inter-departure delta across packets reported via Transport-Wide Congestion Control (TWCC, RFC 8888). A sliding Trendline filter calculates the delay gradient and detects network queue buildup before packet loss occurs.
- Loss-based estimation: Evaluates RTCP Receiver Report fraction lost. If loss exceeds 10%, multiplicative decrease is triggered; if loss is below 2%, additive increase ramps up bitrate.
- Packet Pacing: Packets are enqueued in a priority leaky-bucket pacer (Audio > Retransmissions > Video Keyframes > Video Deltas) to smooth transmission bursts.

## 5. Simulcast Routing and Smooth Layer Switching

When a publisher streams multiple spatial resolutions (e.g. 1080p, 720p, 360p):
- The subscriber's downlink bandwidth estimator continuously determines target layer suitability.
- Layer switches occur cleanly at video keyframe boundaries (or upon explicit Picture Loss Indication PLI requests).
- RTP sequence numbers and timestamps are translated continuously to ensure decoders receive an uninterrupted sequence.
