# Solas Signaling & Control API Specification

This document provides the formal wire protocol specification for Solas WebRTC Selective Forwarding Unit (SFU) interfaces, including HTTP REST endpoints, RFC 9724 WHIP ingestion, WHEP egress, WebSocket JSON-RPC 2.0 signaling, and OpenMetrics telemetry.

---

## 1. HTTP REST Endpoints

### 1.1 Service Health Check
- **Route**: `GET /health`
- **Response**: `200 OK`
- **Body**: Plaintext `OK`

### 1.2 System Status and Capabilities
- **Route**: `GET /api/v1/status`
- **Response**: `200 OK`
- **Content-Type**: `application/json`
- **Example Response**:
```json
{
  "service": "solas",
  "version": "1.0.0",
  "uptime_seconds": 3600,
  "active_rooms": 12,
  "active_peers": 48,
  "active_tracks": 96,
  "codecs_supported": [
    { "name": "VP8", "clock_rate": 90000, "payload_type": 96 },
    { "name": "VP9", "clock_rate": 90000, "payload_type": 98 },
    { "name": "AV1", "clock_rate": 90000, "payload_type": 35 },
    { "name": "H264", "clock_rate": 90000, "payload_type": 100 },
    { "name": "opus", "clock_rate": 48000, "payload_type": 111 }
  ]
}
```

### 1.3 OpenMetrics Prometheus Telemetry
- **Route**: `GET /metrics`
- **Response**: `200 OK`
- **Content-Type**: `text/plain; version=0.0.4`
- **Metrics Exported**:
  - `solas_rtp_packets_received_total`: Total inbound RTP media packets across all interfaces.
  - `solas_rtp_bytes_received_total`: Total inbound RTP octets.
  - `solas_rtp_packets_sent_total`: Total outbound forwarded RTP packets.
  - `solas_rtp_bytes_sent_total`: Total outbound forwarded RTP octets.
  - `solas_rtt_seconds`: Instantaneous round trip time measured via RTCP SR/RR and STUN.
  - `solas_packet_loss_ratio`: Instantaneous fraction lost reported by receivers.
  - `solas_forwarding_latency_seconds_bucket`: High resolution histogram of packet routing latency.

---

## 2. Media Ingest and Egress Protocols

### 2.1 RFC 9724 WebRTC HTTP Ingestion Protocol (WHIP)
Allows hardware broadcasters, OBS Studio, and mobile encoders to publish media via standard HTTP.

#### Session Creation
- **Route**: `POST /api/v1/whip`
- **Headers**:
  - `Content-Type: application/sdp`
  - `Authorization: Bearer <token>` (optional)
- **Body**: Publisher SDP Offer.
- **Response**: `201 Created`
  - `Location: /api/v1/whip/sessions/{session_id}`
  - `Content-Type: application/sdp`
  - Body: Answer SDP negotiated by Solas SFU.

#### Session Termination
- **Route**: `DELETE /api/v1/whip/sessions/{session_id}`
- **Response**: `200 OK`

---

### 2.2 WebRTC HTTP Egress Protocol (WHEP)
Enables passive consumption of live WebRTC streams via HTTP.

#### Egress Subscription
- **Route**: `POST /api/v1/whep`
- **Headers**:
  - `Content-Type: application/sdp`
- **Body**: Subscriber SDP Offer.
- **Response**: `201 Created`
  - `Location: /api/v1/whep/sessions/{session_id}`
  - `Content-Type: application/sdp`
  - Body: Answer SDP routing requested tracks.

---

### 2.3 Low-Latency HLS (LL-HLS) Live Distribution
Solas slices live incoming video and audio tracks into fragmented MP4 (fMP4) ISO-BMFF segments.

- **Master Playlist**: `GET /live/{stream_id}/master.m3u8`
- **Media Playlist**: `GET /live/{stream_id}/media.m3u8`
- **Initialization Segment**: `GET /live/{stream_id}/init.mp4`
- **Media Segments**: `GET /live/{stream_id}/seg_{seq_num}.m4s`

---

## 3. WebSocket JSON-RPC 2.0 Signaling Protocol

Clients connect to `ws://host:port/ws` (or `wss://host:port/ws` over TLS) to establish a full-duplex control session.

### 3.1 Client to Server RPC Requests

#### Join Room
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "join",
  "params": {
    "room_id": "alpha-conference",
    "peer_id": "usr-882",
    "display_name": "Alice Developer"
  }
}
```
**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "joined": true,
    "room_id": "alpha-conference",
    "ice_servers": [
      { "urls": "stun:stun.solas.io:3478" }
    ],
    "existing_peers": [
      {
        "peer_id": "usr-104",
        "display_name": "Bob",
        "tracks": [
          { "track_id": "trk-bob-v", "kind": "video", "ssrc": 5001 },
          { "track_id": "trk-bob-a", "kind": "audio", "ssrc": 5002 }
        ]
      }
    ]
  }
}
```

#### Publish Media Track
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "publish",
  "params": {
    "sdp_offer": "v=0\r\no=- 42 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96\r\n...",
    "simulcast": true,
    "layers": ["low", "medium", "high"]
  }
}
```
**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "sdp_answer": "v=0\r\no=- 42 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96\r\n...",
    "published_ssrcs": [1001, 1002, 1003]
  }
}
```

#### Trickle ICE Candidate Exchange
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "candidate",
  "params": {
    "candidate": "candidate:1 1 UDP 2130706431 192.168.1.100 50000 typ host",
    "sdp_mid": "0",
    "sdp_mline_index": 0
  }
}
```

#### Simulcast Spatial Layer Selection
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "layer_select",
  "params": {
    "track_id": "trk-bob-v",
    "target_layer": "high"
  }
}
```

---

### 3.2 Server to Client Asynchronous Notifications

#### Peer Joined
```json
{
  "jsonrpc": "2.0",
  "method": "peer_joined",
  "params": {
    "peer_id": "usr-309",
    "display_name": "Charlie"
  }
}
```

#### Track Published
```json
{
  "jsonrpc": "2.0",
  "method": "track_published",
  "params": {
    "peer_id": "usr-309",
    "track_id": "trk-charlie-screen",
    "kind": "video",
    "ssrc": 9001,
    "simulcast": false
  }
}
```

#### Dominant Speaker Changed
```json
{
  "jsonrpc": "2.0",
  "method": "active_speaker_changed",
  "params": {
    "dominant_peer_id": "usr-882",
    "audio_level_dbov": 12
  }
}
```

#### Peer Left
```json
{
  "jsonrpc": "2.0",
  "method": "peer_left",
  "params": {
    "peer_id": "usr-104",
    "reason": "disconnected"
  }
}
```
