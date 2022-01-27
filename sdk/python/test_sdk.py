"""
Solas Python SDK - Unit Test Suite
"""

import unittest
import json
from solas_client import SolasClient, TrackInfo, SolasError


class TestSolasPythonSDK(unittest.TestCase):

    def setUp(self):
        self.client = SolasClient(base_url="http://127.0.0.1:8080")

    def test_create_rpc_request_structure(self):
        req_str = self.client.create_rpc_request("join", {"room_id": "room-101", "peer_id": "usr-1"})
        data = json.loads(req_str)
        self.assertEqual(data["jsonrpc"], "2.0")
        self.assertEqual(data["id"], 1)
        self.assertEqual(data["method"], "join")
        self.assertEqual(data["params"]["room_id"], "room-101")
        self.assertEqual(data["params"]["peer_id"], "usr-1")

    def test_event_dispatching(self):
        received_events = []

        def handle_peer_joined(params):
            received_events.append(params)

        self.client.on("peer_joined", handle_peer_joined)

        event_payload = json.dumps({
            "jsonrpc": "2.0",
            "method": "peer_joined",
            "params": {"peer_id": "usr-99", "display_name": "Test User"}
        })

        self.client.handle_incoming_message(event_payload)
        self.assertEqual(len(received_events), 1)
        self.assertEqual(received_events[0]["peer_id"], "usr-99")
        self.assertEqual(received_events[0]["display_name"], "Test User")

    def test_track_info_model(self):
        track = TrackInfo("trk-01", "video", 555001, simulcast=True)
        self.assertEqual(track.track_id, "trk-01")
        self.assertEqual(track.kind, "video")
        self.assertEqual(track.ssrc, 555001)
        self.assertTrue(track.simulcast)

        d = track.to_dict()
        self.assertEqual(d["track_id"], "trk-01")
        self.assertEqual(d["kind"], "video")
        self.assertEqual(d["ssrc"], 555001)


if __name__ == "__main__":
    unittest.main()
