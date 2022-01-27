"""
Solas Python SDK - Multi-Bot Conference Automation Example
Demonstrates connecting simulated participants, publishing tracks, and handling events.
"""

import asyncio
import logging
from solas_client import SolasClient, TrackInfo

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("example")


def main():
    client = SolasClient(base_url="http://localhost:8080")

    # Set up event listeners
    @client.on("peer_joined")
    def on_peer_joined(data):
        logger.info(f"Peer joined: {data.get('peer_id')} ({data.get('display_name')})")

    @client.on("track_published")
    def on_track_published(data):
        logger.info(f"New track: {data.get('kind')} SSRC={data.get('ssrc')}")

    @client.on("active_speaker_changed")
    def on_speaker(data):
        logger.info(f"Dominant speaker: {data.get('dominant_peer_id')}")

    # Build simulated join request
    join_payload = client.create_rpc_request("join", {
        "room_id": "test-room-1",
        "peer_id": "bot-alice",
        "display_name": "Alice Automated"
    })
    logger.info(f"Generated Join RPC Payload:\n{join_payload}")

    # Simulate server response dispatch
    simulated_server_notification = '{"jsonrpc": "2.0", "method": "peer_joined", "params": {"peer_id": "bot-bob", "display_name": "Bob Automated"}}'
    client.handle_incoming_message(simulated_server_notification)

    # Simulate active speaker notification
    speaker_notification = '{"jsonrpc": "2.0", "method": "active_speaker_changed", "params": {"dominant_peer_id": "bot-bob", "audio_level_dbov": 15}}'
    client.handle_incoming_message(speaker_notification)

    logger.info("Example execution completed successfully.")


if __name__ == "__main__":
    main()
