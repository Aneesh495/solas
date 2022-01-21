# Simulcast & Scalable Video Coding (SVC) Engineering Guide

This guide details the mathematical and protocol foundations of adaptive video streaming in Solas, explaining how the engine reconciles dynamic downlink bandwidth estimates with multi-layer video streams without inducing decoder freezes or video artifacts.

---

## 1. Fundamentals of Multi-Layer WebRTC Video

Real-time video distribution across heterogeneous network links requires dynamic rate adaptation. Solas supports two primary architectural paradigms:

1. **Multi-Stream Simulcast**: The publisher encodes and transmits $N$ distinct video bitstreams concurrently (typically 3 spatial layers: Low 180p, Medium 360p, High 720p/1080p), each with a unique Synchronization Source (SSRC) identifier.
2. **Single-Stream Scalable Video Coding (SVC)**: The publisher transmits a single bitstream structured in hierarchical dependency layers (e.g. VP9 or AV1 OBU). The SFU selectively discards upper layers without requiring intra-coded keyframe synchronizations.

| Property | Simulcast (VP8 / H.264) | Scalable Video Coding (VP9 / AV1) |
| :--- | :--- | :--- |
| **Publisher CPU Load** | High (3 parallel codec instances) | Moderate (single hierarchical encoder) |
| **Uplink Bandwidth** | $\sum_{i=1}^N R_i$ (approx 1.5x of top layer) | Approx 1.1x of top layer |
| **Layer Switch Latency** | Bound by Keyframe Arrival (100ms to 1s) | Immediate at next temporal layer unit |
| **SFU Forwarding Logic** | Sequence and Timestamp Rewriting Required | In-place OBU / Layer discarding |

---

## 2. Simulcast Layer Switching Mechanics

When a subscriber's estimated available downlink bandwidth shifts, the Solas `LayerSwitcher` transitions the active forwarding stream. To preserve decoder continuity, the switch must satisfy two invariant properties:

### 2.1 Monotonic Sequence Unwrapping and Rewriting
Each publisher layer possesses an independent RTP sequence number sequence $S_i(t)$. If an SFU switched raw packets from Layer 1 ($S_1=1050$) directly to Layer 2 ($S_2=4200$), the subscriber's RTP jitter buffer would interpret the 3150-packet delta as a massive packet loss burst, flooding the network with spurious NACK requests.

Solas eliminates this by rewriting both sequence numbers and RTP timestamps through a monotonic projection function:

$$S_{\text{out}}(t) = S_{\text{out}}(t-1) + 1$$

$$T_{\text{out}}(t) = T_{\text{out}}(t-1) + \Delta T_{\text{frame}}$$

where $\Delta T_{\text{frame}} = \frac{90000}{\text{fps}}$ (e.g. 3000 clock ticks at 30 fps).

### 2.2 Keyframe Gating and Atomic Transition State Machine
A subscriber cannot decode predictive delta frames from a new spatial layer without first receiving an intra-coded keyframe (IDR frame in H.264, or Keyframe OBU in AV1).

```
[ Current Layer: HIGH ] --------------------> [ Normal Delta Forwarding ]
         |
         | (Bandwidth drops below 800 kbps)
         v
[ State: SWITCHING_TO_LOW ]
         |
         |---> 1. Send RTCP PLI / FIR to Publisher for LOW SSRC
         |---> 2. Continue forwarding HIGH Delta frames (graceful degradation)
         |---> 3. Inspect incoming LOW packets for Keyframe Header bit
         |
         v (LOW Keyframe Detected)
[ State: ATOMIC_TRANSITION ]
         |
         |---> 1. Terminate HIGH forwarding
         |---> 2. Synchronize output sequence offset: offset = S_out - S_low_in
         |---> 3. Emit rewritten LOW Keyframe
         v
[ Current Layer: LOW ] ---------------------> [ Steady State Resumed ]
```

---

## 3. Scalable Video Coding (SVC) Forwarding

For VP9 and AV1, Solas inspects codec payload descriptors directly:

### 3.1 VP9 Flexible Mode
The VP9 payload descriptor exposes:
- **I (Inter-picture predicted)**: 0 indicates a keyframe.
- **P (Picture ID present)**: 7-bit or 15-bit monotonic picture index.
- **L (Layer indices present)**: Specifies Spatial Layer ID (SLID) and Temporal Layer ID (TLID).

When throttling downstream bandwidth, the Solas forwarder applies an O(1) bitwise filter:

```
if (packet.spatial_layer_id <= target_spatial_layer &&
    packet.temporal_layer_id <= target_temporal_layer) {
    forward_packet(packet);
} else {
    drop_packet(packet);
}
```

Because reference picture buffers are preserved across lower layers, dropping upper temporal or spatial units never corrupts the base video stream.

---

## 4. Anti-Flapping Hysteresis Controller

A common failure mode in video forwarding is layer flapping: oscillating rapidly between high and medium layers due to transient jitter bursts.

Solas incorporates an asymmetric hysteresis filter:
1. **Upswitch Delay**: Bandwidth must remain above the upgrade threshold ($R_{\text{up}}$) for at least 3,000ms continuously before an upswitch is scheduled.
2. **Downswitch Speed**: If loss exceeds 10% or delay gradients indicate impending congestion, the downswitch triggers immediately (within 20ms) to avoid packet drops in network buffers.
3. **Threshold Margin**: The upgrade threshold requires a 20% headroom margin over the target layer bitrate:

$$R_{\text{target\_high}} = 2500 \text{ kbps} \implies R_{\text{trigger}} = 3000 \text{ kbps}$$
