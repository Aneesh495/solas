/**
 * Solas TypeScript SDK - Browser Integration Example
 */

import { SolasRoom, RemoteParticipant } from './solas-sdk';

async function startConference() {
  const room = new SolasRoom({
    wsUrl: 'ws://localhost:8080/ws',
    roomId: 'alpha-room',
    peerId: 'web-user-' + Math.floor(Math.random() * 1000),
    displayName: 'Web Developer',
  });

  room.onParticipantJoined = (p: RemoteParticipant) => {
    console.log(`[Solas] Participant joined: ${p.displayName} (${p.peerId})`);
  };

  room.onParticipantLeft = (peerId: string) => {
    console.log(`[Solas] Participant left: ${peerId}`);
  };

  room.onActiveSpeakerChanged = (peerId: string, level: number) => {
    console.log(`[Solas] Dominant speaker changed: ${peerId} (level: ${level} dBov)`);
  };

  room.onTrackSubscribed = (track: MediaStreamTrack, peer: RemoteParticipant) => {
    console.log(`[Solas] Remote track received: ${track.kind} from ${peer.displayName}`);
    const mediaEl = document.createElement(track.kind === 'video' ? 'video' : 'audio') as HTMLMediaElement;
    mediaEl.srcObject = new MediaStream([track]);
    mediaEl.autoplay = true;
    document.body.appendChild(mediaEl);
  };

  console.log('[Solas] Connecting to room...');
  await room.connect();
  console.log('[Solas] Connected and joined room.');

  if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
    try {
      const localStream = await navigator.mediaDevices.getUserMedia({
        video: { width: 1280, height: 720 },
        audio: true,
      });
      console.log('[Solas] Publishing local camera and microphone with simulcast...');
      await room.publish(localStream);
      console.log('[Solas] Stream published successfully.');
    } catch (err) {
      console.warn('[Solas] Could not capture media device in headless environment:', err);
    }
  }
}

export { startConference };
