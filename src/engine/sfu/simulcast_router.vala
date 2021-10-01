/*
 * Solas: Real-Time WebRTC Media Engine
 * Simulcast Dynamic Layer Selection and Sequence Rewriting
 */

using Solas.Core;
using Solas.Protocol.Rtp;
using Solas.Media;

namespace Solas.Engine.Sfu {

    public enum SpatialLayer {
        LOW = 0,    /* 360p / low bitrate */
        MEDIUM = 1, /* 720p / med bitrate */
        HIGH = 2    /* 1080p / high bitrate */
    }

    public class SimulcastTrackGroup : Object {
        public MediaTrack? low_layer { get; set; }
        public MediaTrack? med_layer { get; set; }
        public MediaTrack? high_layer { get; set; }

        public MediaTrack? get_layer(SpatialLayer layer) {
            switch (layer) {
                case SpatialLayer.LOW: return this.low_layer;
                case SpatialLayer.MEDIUM: return (this.med_layer != null) ? this.med_layer : this.low_layer;
                case SpatialLayer.HIGH: return (this.high_layer != null) ? this.high_layer :
                                               ((this.med_layer != null) ? this.med_layer : this.low_layer);
                default: return this.low_layer;
            }
        }
    }

    public class SimulcastForwarder : Object {
        public string subscriber_id { get; set; }
        public SpatialLayer current_layer { get; private set; }
        public SpatialLayer target_layer { get; private set; }
        private bool waiting_for_keyframe;
        private uint16 seq_offset;
        private uint32 ts_offset;
        private uint16 last_out_seq;
        private uint32 last_out_ts;
        private bool initialized;
        private DepacketizerVp8 vp8_depack;

        public SimulcastForwarder(string sub_id, SpatialLayer initial_layer = SpatialLayer.HIGH) {
            this.subscriber_id = sub_id;
            this.current_layer = initial_layer;
            this.target_layer = initial_layer;
            this.waiting_for_keyframe = false;
            this.seq_offset = 0;
            this.ts_offset = 0;
            this.last_out_seq = 0;
            this.last_out_ts = 0;
            this.initialized = false;
            this.vp8_depack = new DepacketizerVp8();
        }

        public void request_layer_switch(SpatialLayer layer) {
            if (this.target_layer != layer) {
                this.target_layer = layer;
                this.waiting_for_keyframe = true;
            }
        }

        /**
         * Selects spatial layer based on subscriber downlink bandwidth estimate.
         */
        public void adapt_to_bandwidth(double downlink_kbps) {
            if (downlink_kbps < 400.0) {
                request_layer_switch(SpatialLayer.LOW);
            } else if (downlink_kbps < 1500.0) {
                request_layer_switch(SpatialLayer.MEDIUM);
            } else {
                request_layer_switch(SpatialLayer.HIGH);
            }
        }

        /**
         * Forwards packet from the active or candidate layer, performing seamless
         * layer switching on keyframe arrival.
         */
        public RtpPacket? process_packet(SpatialLayer packet_layer, RtpPacket packet) {
            if (this.waiting_for_keyframe && packet_layer == this.target_layer) {
                if (this.vp8_depack.is_keyframe(packet)) {
                    /* Keyframe arrived on target layer: execute seamless switch */
                    this.current_layer = this.target_layer;
                    this.waiting_for_keyframe = false;

                    if (this.initialized) {
                        /* Offset new sequence number right after last transmitted sequence number */
                        this.seq_offset = (uint16) (this.last_out_seq + 1 - packet.sequence_number);
                        this.ts_offset = (uint32) (this.last_out_ts + 3000 - packet.timestamp);
                    }
                }
            }

            if (packet_layer != this.current_layer) {
                /* Drop packets from inactive layers */
                return null;
            }

            /* Translate sequence numbers and timestamps to present a continuous stream */
            uint16 out_seq = (uint16) (packet.sequence_number + this.seq_offset);
            uint32 out_ts = (uint32) (packet.timestamp + this.ts_offset);

            this.last_out_seq = out_seq;
            this.last_out_ts = out_ts;
            this.initialized = true;

            /* Clone packet with rewritten sequence and timestamp */
            var fwd = new RtpPacket();
            fwd.version = packet.version;
            fwd.payload_type = packet.payload_type;
            fwd.sequence_number = out_seq;
            fwd.timestamp = out_ts;
            fwd.ssrc = packet.ssrc;
            fwd.marker = packet.marker;
            fwd.extension = packet.extension;
            fwd.payload = packet.payload;

            foreach (var ext in packet.extensions) {
                fwd.add_extension(ext);
            }

            return fwd;
        }

        public bool is_switching {
            get { return this.waiting_for_keyframe; }
        }
    }
}
