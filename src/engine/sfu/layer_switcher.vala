/*
 * Solas: Real-Time WebRTC Media Engine
 * Advanced Simulcast Layer Switcher, BWE Rate Adapter, and Keyframe Synchronizer
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Media;

namespace Solas.Engine.Sfu {

    public class LayerSwitcher : Object {
        public string subscriber_id { get; construct; }
        public SpatialLayer current_layer { get; private set; }
        public SpatialLayer target_layer { get; private set; }
        public bool is_switching { get; private set; }

        public uint32 low_bitrate_kbps { get; set; default = 250; }
        public uint32 med_bitrate_kbps { get; set; default = 800; }
        public uint32 high_bitrate_kbps { get; set; default = 2500; }

        private uint16 out_seq;
        private uint32 out_timestamp;
        private uint32 last_in_ts;
        private int64 switch_start_time_us;
        private uint32 switch_count;
        private uint32 dropped_non_keyframes;

        public signal void keyframe_requested(SpatialLayer layer);
        public signal void layer_switched(SpatialLayer from_layer, SpatialLayer to_layer, int64 duration_us);

        public LayerSwitcher(string sub_id, SpatialLayer initial_layer = SpatialLayer.HIGH) {
            GLib.Object(subscriber_id: sub_id);
            this.current_layer = initial_layer;
            this.target_layer = initial_layer;
            this.is_switching = false;
            this.out_seq = 1000;
            this.out_timestamp = 10000;
            this.last_in_ts = 0;
            this.switch_start_time_us = 0;
            this.switch_count = 0;
            this.dropped_non_keyframes = 0;
        }

        public uint32 get_switch_count() {
            return this.switch_count;
        }

        public uint32 get_dropped_packets() {
            return this.dropped_non_keyframes;
        }

        /**
         * Reconciles target layer based on receiver available bandwidth estimate.
         */
        public void update_bandwidth(uint32 available_kbps) {
            SpatialLayer recommended;
            if (available_kbps >= this.high_bitrate_kbps) {
                recommended = SpatialLayer.HIGH;
            } else if (available_kbps >= this.med_bitrate_kbps) {
                recommended = SpatialLayer.MEDIUM;
            } else {
                recommended = SpatialLayer.LOW;
            }

            if (recommended != this.target_layer && recommended != this.current_layer) {
                this.request_layer_switch(recommended);
            }
        }

        public void request_layer_switch(SpatialLayer new_layer) {
            if (new_layer == this.current_layer && !this.is_switching) {
                return;
            }

            this.target_layer = new_layer;
            this.is_switching = true;
            this.switch_start_time_us = Clock.get_monotonic_time_us();
            this.keyframe_requested(new_layer);
        }

        /**
         * Processes an incoming RTP packet for a specific layer.
         * Returns a rewritten, sequence-continuous RTP packet if forwarded, or null if dropped.
         */
        public RtpPacket? process_packet(SpatialLayer layer, RtpPacket in_pkt, bool is_keyframe) {
            /* Case 1: Active switch in progress */
            if (this.is_switching) {
                if (layer == this.target_layer) {
                    if (is_keyframe) {
                        /* Keyframe arrived on target layer: execute atomic transition */
                        int64 duration_us = Clock.get_monotonic_time_us() - this.switch_start_time_us;
                        SpatialLayer old_layer = this.current_layer;
                        this.current_layer = this.target_layer;
                        this.is_switching = false;
                        this.switch_count++;

                        this.layer_switched(old_layer, this.current_layer, duration_us);

                        /* Advance timestamp monotonically */
                        this.out_timestamp += 3000; /* Standard 90kHz 30fps frame delta */
                        this.last_in_ts = in_pkt.timestamp;

                        return this.rewrite_packet(in_pkt);
                    } else {
                        /* Drop delta frames on target layer before keyframe arrives */
                        this.dropped_non_keyframes++;
                        return null;
                    }
                } else if (layer == this.current_layer) {
                    /* Continue forwarding current layer delta frames while waiting for keyframe */
                    return this.rewrite_packet(in_pkt);
                } else {
                    return null;
                }
            }

            /* Case 2: Steady state on current layer */
            if (layer == this.current_layer) {
                if (this.last_in_ts != 0 && in_pkt.timestamp != this.last_in_ts) {
                    uint32 delta = in_pkt.timestamp - this.last_in_ts;
                    this.out_timestamp += delta;
                }
                this.last_in_ts = in_pkt.timestamp;
                return this.rewrite_packet(in_pkt);
            }

            /* Non-matching layer */
            return null;
        }

        private RtpPacket rewrite_packet(RtpPacket in_pkt) {
            var out_pkt = new RtpPacket();
            out_pkt.version = in_pkt.version;
            out_pkt.padding = in_pkt.padding;
            out_pkt.extension = in_pkt.extension;
            out_pkt.marker = in_pkt.marker;
            out_pkt.payload_type = in_pkt.payload_type;
            out_pkt.ssrc = in_pkt.ssrc;

            /* Monotonically contiguous sequence number and seamless timestamp */
            out_pkt.sequence_number = this.out_seq++;
            out_pkt.timestamp = this.out_timestamp;

            if (in_pkt.payload != null && in_pkt.payload.length > 0) {
                uint8[] copy = new uint8[in_pkt.payload.length];
                Memory.copy(copy, in_pkt.payload, in_pkt.payload.length);
                out_pkt.payload = copy;
            }

            return out_pkt;
        }
    }
}
