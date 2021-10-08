/*
 * Solas: Real-Time WebRTC Media Engine
 * WebSocket Handshake and Framing Engine (RFC 6455)
 */

using Solas.Core;
using Solas.Crypto;

namespace Solas.Network {

    public enum WebSocketOpcode {
        CONTINUATION = 0x0,
        TEXT = 0x1,
        BINARY = 0x2,
        CLOSE = 0x8,
        PING = 0x9,
        PONG = 0xA
    }

    public class WebSocketFrame : Object {
        public bool fin { get; set; }
        public WebSocketOpcode opcode { get; set; }
        public uint8[] payload;

        public WebSocketFrame(WebSocketOpcode opcode, uint8[] payload, bool fin = true) {
            this.fin = fin;
            this.opcode = opcode;
            this.payload = payload;
        }

        public string get_text() {
            var sb = new StringBuilder();
            for (size_t i = 0; i < this.payload.length; i++) {
                sb.append_c((char) this.payload[i]);
            }
            return sb.str;
        }

        public static WebSocketFrame text(string text) {
            unowned uint8[] raw = (uint8[]) text;
            uint8[] d = new uint8[text.length];
            Memory.copy(d, raw, text.length);
            return new WebSocketFrame(WebSocketOpcode.TEXT, d, true);
        }
    }

    public class WebSocketFraming : Object {
        public const string WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

        /**
         * Computes Sec-WebSocket-Accept token for client handshake.
         * accept = Base64(SHA1(client_key + WS_GUID))
         */
        public static string compute_accept_key(string client_key) throws CryptoError {
            string combined = client_key.strip() + WS_GUID;
            uint8[] raw = new uint8[combined.length];
            Memory.copy(raw, (uint8[]) combined, combined.length);
            uint8[] sha = Solas.Crypto.Engine.sha1(raw);
            return GLib.Base64.encode(sha);
        }

        /**
         * Encodes a server-to-client frame (unmasked as per RFC 6455 Section 5.1).
         */
        public static uint8[] encode_frame(WebSocketFrame frame) {
            var writer = new ByteWriter(frame.payload.length + 10);

            /* Byte 0: FIN(1) | RSV(3) | Opcode(4) */
            uint8 b0 = (uint8) ((frame.fin ? 0x80 : 0x00) | ((uint8) frame.opcode & 0x0F));
            writer.write_uint8(b0);

            /* Server frames are unmasked (Mask bit = 0) */
            size_t len = frame.payload.length;
            if (len <= 125) {
                writer.write_uint8((uint8) len);
            } else if (len <= 65535) {
                writer.write_uint8(126);
                writer.write_uint16_be((uint16) len);
            } else {
                writer.write_uint8(127);
                writer.write_uint64_be((uint64) len);
            }

            writer.write_bytes(frame.payload);
            return writer.to_array();
        }

        /**
         * Decodes a client-to-server frame (masked as per RFC 6455).
         */
        public static WebSocketFrame? decode_frame(uint8[] data) {
            if (data.length < 2) return null;

            var reader = new ByteReader(data);
            try {
                uint8 b0 = reader.read_uint8();
                uint8 b1 = reader.read_uint8();

                bool fin = ((b0 & 0x80) != 0);
                WebSocketOpcode op = (WebSocketOpcode) (b0 & 0x0F);
                bool masked = ((b1 & 0x80) != 0);
                uint64 payload_len = (uint64) (b1 & 0x7F);

                if (payload_len == 126) {
                    payload_len = (uint64) reader.read_uint16_be();
                } else if (payload_len == 127) {
                    payload_len = reader.read_uint64_be();
                }

                uint8[] mask_key = new uint8[4];
                if (masked) {
                    mask_key = reader.read_bytes(4);
                }

                if (reader.remaining < payload_len) {
                    return null; /* Incomplete frame */
                }

                uint8[] raw_payload = reader.read_bytes((size_t) payload_len);
                if (masked) {
                    for (size_t i = 0; i < raw_payload.length; i++) {
                        raw_payload[i] ^= mask_key[i % 4];
                    }
                }

                return new WebSocketFrame(op, raw_payload, fin);
            } catch (ReaderError e) {
                return null;
            }
        }
    }
}
