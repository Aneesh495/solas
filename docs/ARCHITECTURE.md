# Solas Architecture Specification

Solas is a high-performance WebRTC Selective Forwarding Unit (SFU) and real-time adaptive media distribution engine engineered in Vala. It compiles directly to native C via the GObject type system, leveraging non-blocking asynchronous event loops (GMainLoop and GIO) and zero-copy packet buffers to achieve sub-millisecond audio and video packet routing.

## 1. System Overview and Core Philosophy

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

## 2. Unified UDP Demultiplexing Pipeline (RFC 7983)

Solas operates on a unified UDP listener socket per worker core. Incoming datagrams are classified in O(1) time by examining the first byte:

1. Values 0 to 1: STUN packet (RFC 5389 and RFC 8489). Routed to the STUN message parser for connectivity checks, binding verification, and NAT traversal.
2. Values 20 to 63: DTLS handshake packet (RFC 6347). Forwarded to the TLS cryptographic state machine for session key agreement.
3. Values 128 to 191: RTP or RTCP packet (RFC 3550).
   - If the payload type byte is between 64 and 95 (or between 200 and 211), the datagram is demuxed as RTCP.
   - Otherwise, the datagram is demuxed as RTP media.

## 3. Cryptographic Security Subsystem

### Native Cryptographic Acceleration
Solas integrates OpenSSL cryptographic primitives through an optimized C bridge:
- Hardware-accelerated AES-128-CTR and AES-256-CTR keystream generation.
- SSE4.2 and ARM NEON CRC32 calculation for STUN FINGERPRINT attributes.
- HMAC-SHA1 and HMAC-SHA256 message authentication.

### RFC 3711 SRTP and SRTCP Key Derivation
Upon completion of the DTLS handshake (RFC 5764), key material is exported using the `EXTRACTOR-dtls_srtp` label. Solas derives session keys using AES-CTR pseudorandom functions:
- Master Key: 16 bytes.
- Master Salt: 14 bytes.
- Session Encryption Key, Authentication Key, and Session Salt are computed per packet index.
- Sliding Replay Window: A 64-bit bitmask window rejects duplicate or replayed packets.

### RFC 9605 Secure Frame (SFrame) End-to-End Encryption
For confidential group communications, Solas supports SFrame:
- Media frames are encrypted by the sender before RTP packetization.
- The SFU routes frames without accessing payload contents.
- Frames carry a variable-length Key ID (KID), monotonic counter (CTR), and truncated HMAC-SHA256 authentication tag.
- Replay protection enforces strictly advancing counter windows per Key ID.

## 4. Signaling Protocols

### WebSocket JSON-RPC 2.0 Signaling
The default signaling session implements bidirectional JSON-RPC 2.0 framing:
- `join`: Requests room admission and provides peer metadata.
- `publish`: Declares available audio/video tracks and SDP offers.
- `subscribe`: Requests downlink streams with preferred simulcast layers.
- `candidate`: Exchanges trickle ICE candidates asynchronously.

### RFC 9724 WebRTC HTTP Ingestion Protocol (WHIP)
Solas provides an RFC 9724 compliant WHIP endpoint at `/api/v1/whip`:
- Ingests standard WebRTC streams from hardware encoders, OBS Studio, and mobile broadcasting tools.
- Accepts `POST` with `Content-Type: application/sdp`.
- Returns `201 Created` with answer SDP and `Location` header representing the session resource.
- Supports `DELETE` to terminate publishing sessions.

### WebRTC HTTP Egress Protocol (WHEP)
For broadcast egress, Solas exposes `/api/v1/whep`:
- Delivers ultra-low latency streams to consumer clients via standard HTTP POST negotiation.
- Enables seamless playback fallback for environments where WebSocket connections are restricted.

## 5. Media Depacketization and Codec Support

### AV1 OBU Depacketization (RFC 9053)
- Handles Open Bitstream Units (OBU).
- Supports temporal layer indicators, sequence headers, and keyframe discovery.
- Aggregation mode permits efficient packing of multiple OBUs per RTP packet.

### VP9 Scalable Video Coding (SVC)
- Parses VP9 payload descriptors in both flexible and non-flexible modes.
- Extracts Picture ID, Spatial Layer ID (SLID), and Temporal Layer ID (TLID).
- Enables spatial layer drop without transcoding.

### VP8 Payload Processing (RFC 7741)
- Identifies start of partition (S-bit) and keyframe status.
- Maintains continuous 7-bit and 15-bit Picture ID sequences across layer switches.

### H.264 STAP-A and FU-A Defragmentation (RFC 6184)
- Reassembles fragmented NAL units (FU-A) across RTP boundaries.
- Depacketizes Single-Time Aggregation Packets (STAP-A) containing SPS/PPS parameter sets.

### Opus Audio (RFC 7587)
- Dynamic frame duration detection (2.5ms to 60ms).
- Integration with RFC 6464 client-to-mixer audio level extensions.

## 6. Audio Processing Subsystem

### Multi-Participant Linear Audio Mixer
- Sums 16-bit 48kHz linear PCM samples across concurrent talkers.
- Applies soft saturation limiting (tanh-style soft knee) above 32,000 to prevent digital clipping.

### N-1 Echo Cancellation Composite
- For each participant, computes a composite audio frame excluding their own microphone stream.
- Eliminates acoustic and network echo in group calls.

### Audio Resampling Engine
- Resamples incoming audio streams across 8kHz, 16kHz, 32kHz, 44.1kHz, and 48kHz.
- Linear and cubic interpolation modes maintain phase coherence.

### Active Speaker Detection
- Tracks per-peer audio energy levels in -dBov (0 dBov = loudest, 127 dBov = silence).
- Implements dual-pole envelope follower with fast attack (50ms) and slow decay (500ms).
- Enforces minimum 500ms dominant speaker hold time to eliminate rapid flip-flopping.

## 7. Real-Time Jitter and Playout Control

### Monotonic 64-bit Sequence Unwrapper
- Bridges 16-bit RTP sequence numbers to monotonic 64-bit space.
- Detects roll-over boundaries and accommodates out-of-order packets up to 32,768 positions behind.

### Kalman Filter Playout Delay Estimator
- Models inter-arrival delay variation using a state-space Kalman filter:
  - State vector represents current delay offset and network drift velocity.
  - Covariance matrix adapts dynamically based on measured packet inter-arrival times.
  - Mitigates jitter spikes while preventing unnecessary playout buffering.

### RTT-Aware NACK Controller
- Tracks missing sequence numbers in a priority skip-list queue.
- Computes retransmission intervals based on smoothed Round Trip Time (SRTT).
- Applies exponential backoff and caps maximum retries to avoid packet storms.

## 8. Congestion Control and Bandwidth Probing

### Google Congestion Control (GCC) Trendline Filter
- Processes Transport-Wide Congestion Control (TWCC, RFC 8888) feedback packets.
- Computes the delay gradient across packet arrival clusters.
- Threshold comparison classifies network state as Underuse, Normal, or Overuse.

### Loss-Based AIMD Rate Controller
- Evaluates RTCP Receiver Report loss ratios:
  - Loss < 2%: Additive increase ramps up available bandwidth.
  - Loss > 10%: Multiplicative decrease cuts bandwidth by 15% immediately.
  - Loss 2% to 10%: Bandwidth holds steady.

### Bandwidth Probing Controller
- Sends targeted bursts of padded RTP packets to measure channel capacity.
- Evaluates whether network can sustain an upgrade to a higher simulcast layer.

### Priority Leaky-Bucket Packet Pacer
- Buffers packets into distinct priority bands:
  1. High-priority interactive audio.
  2. Retransmission packets (NACK responses).
  3. Video keyframes.
  4. Video delta frames.
  5. Padding and probe packets.
- Smooths packet transmission over 5ms intervals to eliminate micro-burst buffer bloat.

## 9. Forward Error Correction (RFC 8627 FlexFEC)

- Generates XOR parity packets across non-contiguous packet frames.
- Enables single-packet and multi-packet recovery without incurring RTT delay of NACK roundtrips.
- Header masks specify protected sequence ranges.

## 10. Data Channels (RFC 8832 and RFC 4960)

- Implements SCTP chunk multiplexing over DTLS:
  - DATA chunks with monotonic TSN and stream identifiers.
  - SACK chunks for selective acknowledgement.
  - HEARTBEAT and HEARTBEAT-ACK chunks for liveness checking.
- Data Channel Establishment Protocol (DCEP):
  - Handles `DATA_CHANNEL_OPEN` and `DATA_CHANNEL_ACK`.
  - Configures reliable, partially reliable, and ordered delivery modes.

## 11. Low-Latency Distribution and Recording

### ISO-BMFF Fragmented MP4 (fMP4) Segmenter
- Slices live video and audio streams at keyframe boundaries into ISO-BMFF boxes:
  - `ftyp`, `moov`, `moof`, `traf`, `tfhd`, `tfdt`, `trun`, `mdat`.
- Base media decode time (`tfdt`) is accurately synchronized with RTP presentation timestamps.

### Sub-Second LL-HLS Engine
- Generates rolling HLS v7 playlists (`.m3u8`) with `#EXT-X-VERSION:7` and `#EXT-X-MAP`.
- Supports sub-second media segment slicing for CDN fanout to millions of passive viewers.

### Continuous Conference Session Recorder
- Synchronously records multi-participant audio and video tracks to disk.
- Generates self-contained MP4 containers with clean index tables on conference completion.

## 12. Edge Clustering and Cascade Mesh

- Hierarchical and full-mesh inter-SFU routing:
  - Origin nodes broadcast room media to edge nodes.
  - Selective broadcast trees ensure packets are forwarded only to nodes with active subscribers.
  - Periodic heartbeats detect node partitions and trigger dynamic failover.

## 13. Quality of Service (RFC 8837 DSCP)

- DiffServ code point tagging on outbound UDP sockets:
  - Audio: Expedited Forwarding (EF = DSCP 46, ToS 0xB8).
  - Interactive High Video: Assured Forwarding 41 (AF41 = DSCP 34, ToS 0x88).
  - Standard Video: Assured Forwarding 42 (AF42 = DSCP 36, ToS 0x90).
  - Background Video: Assured Forwarding 43 (AF43 = DSCP 38, ToS 0x98).
  - Data Channel: Assured Forwarding 11 (AF11 = DSCP 10, ToS 0x28).
  - Signaling: Best Effort (CS0 = DSCP 0, ToS 0x00).

## 14. Telemetry and Metrics

- Embedded OpenMetrics Prometheus exporter at `/metrics`.
- Prometheus metrics:
  - `solas_rtp_packets_received_total`: Monotonic counter.
  - `solas_rtp_bytes_received_total`: Monotonic counter.
  - `solas_rtt_ms`: Sliding gauge per peer.
  - `solas_packet_loss_ratio`: Fraction lost gauge.
  - `solas_forwarding_latency_seconds`: High-resolution bucket histogram.
