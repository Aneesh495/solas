/**
 * Solas Real-Time WebRTC Media Engine - Browser / TypeScript SDK
 * High-performance client library for WebRTC peer connections, simulcast management,
 * and adaptive real-time media streaming.
 */

export interface IceServerConfig {
  urls: string | string[];
  username?: string;
  credential?: string;
}

export interface RoomOptions {
  wsUrl: string;
  roomId: string;
  peerId: string;
  displayName: string;
  iceServers?: IceServerConfig[];
}

export interface RemoteParticipant {
  peerId: string;
  displayName: string;
  audioTrack?: MediaStreamTrack;
  videoTrack?: MediaStreamTrack;
}

export type SimulcastQuality = 'low' | 'medium' | 'high';

export class SolasRoom {
  public readonly options: RoomOptions;
  private ws: WebSocket | null = null;
  private pc: RTCPeerConnection | null = null;
  private isJoined: boolean = false;
  private rpcId: number = 1;
  private pendingRequests = new Map<number, { resolve: (res: any) => void; reject: (err: Error) => void }>();
  private participants = new Map<string, RemoteParticipant>();

  // Event handlers
  public onParticipantJoined?: (p: RemoteParticipant) => void;
  public onParticipantLeft?: (peerId: string) => void;
  public onTrackSubscribed?: (track: MediaStreamTrack, peer: RemoteParticipant) => void;
  public onActiveSpeakerChanged?: (peerId: string, levelDbov: number) => void;
  public onDisconnected?: (reason: string) => void;

  constructor(options: RoomOptions) {
    this.options = options;
  }

  /**
   * Connects to the Solas SFU WebSocket signaling server and joins the target room.
   */
  public async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.options.wsUrl);

      this.ws.onopen = async () => {
        try {
          await this.joinRoom();
          this.initPeerConnection();
          this.isJoined = true;
          resolve();
        } catch (err) {
          reject(err);
        }
      };

      this.ws.onmessage = (event) => {
        this.handleMessage(event.data);
      };

      this.ws.onerror = (err) => {
        if (!this.isJoined) {
          reject(new Error('WebSocket connection error'));
        }
      };

      this.ws.onclose = () => {
        this.isJoined = false;
        if (this.onDisconnected) {
          this.onDisconnected('Signaling socket closed');
        }
      };
    });
  }

  /**
   * Disconnects from the room and disposes all peer connection resources.
   */
  public disconnect(): void {
    if (this.pc) {
      this.pc.close();
      this.pc = null;
    }
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.participants.clear();
    this.isJoined = false;
  }

  /**
   * Publishes local media stream with standard 3-layer simulcast for video.
   */
  public async publish(stream: MediaStream): Promise<void> {
    if (!this.pc) throw new Error('PeerConnection not initialized');

    for (const track of stream.getTracks()) {
      if (track.kind === 'video') {
        const init: RTCRtpTransceiverInit = {
          direction: 'sendonly',
          sendEncodings: [
            { rid: 'low', maxBitrate: 200_000, scaleResolutionDownBy: 4.0 },
            { rid: 'mid', maxBitrate: 800_000, scaleResolutionDownBy: 2.0 },
            { rid: 'high', maxBitrate: 2_500_000, scaleResolutionDownBy: 1.0 },
          ],
        };
        this.pc.addTransceiver(track, init);
      } else {
        this.pc.addTransceiver(track, { direction: 'sendonly' });
      }
    }

    const offer = await this.pc.createOffer();
    await this.pc.setLocalDescription(offer);

    const res = await this.call('publish', {
      sdp_offer: offer.sdp,
      simulcast: true,
      layers: ['low', 'mid', 'high'],
    });

    if (res && res.sdp_answer) {
      await this.pc.setRemoteDescription({
        type: 'answer',
        sdp: res.sdp_answer,
      });
    }
  }

  /**
   * Selects downstream simulcast reception layer for a specific track.
   */
  public async setDownlinkLayer(trackId: string, layer: SimulcastQuality): Promise<void> {
    await this.call('layer_select', {
      track_id: trackId,
      target_layer: layer,
    });
  }

  private async joinRoom(): Promise<any> {
    return this.call('join', {
      room_id: this.options.roomId,
      peer_id: this.options.peerId,
      display_name: this.options.displayName,
    });
  }

  private initPeerConnection(): void {
    const config: RTCConfiguration = {
      iceServers: this.options.iceServers || [{ urls: 'stun:stun.l.google.com:19302' }],
    };
    this.pc = new RTCPeerConnection(config);

    this.pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.notify('candidate', {
          candidate: event.candidate.candidate,
          sdp_mid: event.candidate.sdpMid,
          sdp_mline_index: event.candidate.sdpMLineIndex,
        });
      }
    };

    this.pc.ontrack = (event) => {
      const track = event.track;
      // In Solas, mid maps to participant
      const peerId = event.transceiver.mid || 'unknown';
      let participant = this.participants.get(peerId);
      if (!participant) {
        participant = { peerId, displayName: peerId };
        this.participants.set(peerId, participant);
      }

      if (track.kind === 'audio') {
        participant.audioTrack = track;
      } else {
        participant.videoTrack = track;
      }

      if (this.onTrackSubscribed) {
        this.onTrackSubscribed(track, participant);
      }
    };
  }

  private handleMessage(raw: string): void {
    let msg: any;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }

    if (msg.id && this.pendingRequests.has(msg.id)) {
      const req = this.pendingRequests.get(msg.id)!;
      this.pendingRequests.delete(msg.id);
      if (msg.error) {
        req.reject(new Error(msg.error.message || 'RPC Failed'));
      } else {
        req.resolve(msg.result);
      }
      return;
    }

    if (msg.method) {
      this.handleNotification(msg.method, msg.params || {});
    }
  }

  private handleNotification(method: string, params: any): void {
    switch (method) {
      case 'peer_joined': {
        const p: RemoteParticipant = {
          peerId: params.peer_id,
          displayName: params.display_name || params.peer_id,
        };
        this.participants.set(p.peerId, p);
        if (this.onParticipantJoined) this.onParticipantJoined(p);
        break;
      }
      case 'peer_left': {
        const peerId = params.peer_id;
        this.participants.delete(peerId);
        if (this.onParticipantLeft) this.onParticipantLeft(peerId);
        break;
      }
      case 'active_speaker_changed': {
        if (this.onActiveSpeakerChanged) {
          this.onActiveSpeakerChanged(params.dominant_peer_id, params.audio_level_dbov || 0);
        }
        break;
      }
    }
  }

  private call(method: string, params: any): Promise<any> {
    return new Promise((resolve, reject) => {
      if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
        return reject(new Error('WebSocket not connected'));
      }
      const id = this.rpcId++;
      this.pendingRequests.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
    });
  }

  private notify(method: string, params: any): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;
    this.ws.send(JSON.stringify({ jsonrpc: '2.0', method, params }));
  }
}
