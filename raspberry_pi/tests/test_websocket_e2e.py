from __future__ import annotations

import asyncio
from dataclasses import replace

import pytest
from websockets.asyncio.client import connect

from ai_blind_pi.adapters.simulated import NullSpeech, SimulatedCamera, SimulatedDetector
from ai_blind_pi.config import ServiceConfig
from ai_blind_pi.feedback import FeedbackPolicy
from ai_blind_pi.models import AssistanceState, now_iso
from ai_blind_pi.persistence import StateStore
from ai_blind_pi.protocol import Envelope
from ai_blind_pi.security import PairingManager, authentication_proof, derive_auth_key
from ai_blind_pi.service import AssistanceEngine
from ai_blind_pi.websocket_server import WearableWebSocketServer


async def receive_type(socket, kind: str, *, key=None, nonce=None) -> Envelope:
    while True:
        message = Envelope.decode(await asyncio.wait_for(socket.recv(), timeout=3))
        if key is not None:
            message.verify_authentication_tag(key, session_nonce=nonce)
        if message.type == kind:
            return message


@pytest.mark.asyncio
async def test_enroll_control_disconnect_and_reconnect(tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("AIBA_BIND_HOST", "127.0.0.1")
    monkeypatch.setenv("AIBA_PORT", "0")
    monkeypatch.setenv("AIBA_ENABLE_MDNS", "false")
    monkeypatch.setenv("AIBA_ALLOW_FIRST_CLIENT_ENROLLMENT", "true")
    monkeypatch.setenv("AIBA_STATE_DIR", str(tmp_path / "state"))
    monkeypatch.setenv("AIBA_LOG_DIR", str(tmp_path / "logs"))
    config = replace(
        ServiceConfig.from_env(simulate=True),
        device_id="pi-e2e-device",
        device_name="Simulated wearable",
    )
    config.prepare_directories()
    store = StateStore(config.state_file)
    pairing = PairingManager(store)
    engine = AssistanceEngine(
        device_id=config.device_id,
        camera=SimulatedCamera(interval_seconds=0.005),
        detector=SimulatedDetector(),
        feedback=FeedbackPolicy(NullSpeech()),
        store=store,
        frame_stride=1,
    )
    server = WearableWebSocketServer(config=config, engine=engine, pairing=pairing)
    await engine.initialize()
    await server.start()
    endpoint = f"ws://127.0.0.1:{server.bound_port}/wearable/v1"
    try:
        async with connect(endpoint, ping_interval=None) as socket:
            hello = await receive_type(socket, "hello")
            assert hello.payload["deviceId"] == config.device_id
            assert "exclusive_first_client_enrollment" in hello.payload["capabilities"]
            enrollment_request = Envelope.create(
                "enrollment_request",
                {
                    "clientId": "phone-e2e",
                    "clientName": "Flutter test",
                },
                sequence=0,
            )
            await socket.send(enrollment_request.encode())
            enrollment_result = await receive_type(socket, "enrollment_result")
            assert enrollment_result.payload["enrolled"] is True
            credential_id = enrollment_result.payload["credentialId"]
            secret = enrollment_result.payload["credentialSecret"]

        async with connect(endpoint, ping_interval=None) as socket:
            hello = await receive_type(socket, "hello")
            assert hello.payload["paired"] is True
            assert "exclusive_first_client_enrollment" not in hello.payload["capabilities"]
            second_enrollment = Envelope.create(
                "enrollment_request",
                {"clientId": "phone-other", "clientName": "Other phone"},
                sequence=0,
            )
            await socket.send(second_enrollment.encode())
            result = await receive_type(socket, "enrollment_result")
            assert result.payload == {
                "requestMessageId": second_enrollment.message_id,
                "enrolled": False,
                "errorCode": "enrollment_closed",
            }

        key = derive_auth_key(secret)
        sequence = 1
        async with connect(endpoint, ping_interval=None) as socket:
            hello = await receive_type(socket, "hello")
            nonce = hello.payload["nonce"]
            timestamp = now_iso()
            message_id = "authentication-e2e-0001"
            authentication = Envelope.create(
                "authentication",
                {
                    "clientId": "phone-e2e",
                    "credentialId": credential_id,
                    "nonce": nonce,
                    "clientTimestamp": timestamp,
                    "tag": authentication_proof(
                        key,
                        nonce=nonce,
                        client_id="phone-e2e",
                        credential_id=credential_id,
                        timestamp=timestamp,
                        message_id=message_id,
                    ),
                },
                sequence=sequence,
                message_id=message_id,
                timestamp=timestamp,
            ).signed(key, session_nonce=nonce)
            await socket.send(authentication.encode())
            ack = await receive_type(socket, "acknowledgement", key=key, nonce=nonce)
            assert ack.payload["requestMessageId"] == message_id

            sequence += 1
            start = Envelope.create("start_assistance", sequence=sequence).signed(
                key, session_nonce=nonce
            )
            await socket.send(start.encode())
            await receive_type(socket, "acknowledgement", key=key, nonce=nonce)
            assert engine.state == AssistanceState.RUNNING
            # Important commands are idempotent: a transport retry receives the
            # cached acknowledgement without executing the command twice.
            await socket.send(start.encode())
            duplicate_ack = await receive_type(socket, "acknowledgement", key=key, nonce=nonce)
            assert duplicate_ack.payload["requestMessageId"] == start.message_id
            assert engine.state == AssistanceState.RUNNING

        await asyncio.sleep(0.03)
        assert engine.state == AssistanceState.RUNNING

        async with connect(endpoint, ping_interval=None) as socket:
            hello = await receive_type(socket, "hello")
            nonce = hello.payload["nonce"]
            timestamp = now_iso()
            message_id = "authentication-e2e-0002"
            sequence += 1
            authentication = Envelope.create(
                "authentication",
                {
                    "clientId": "phone-e2e",
                    "credentialId": credential_id,
                    "nonce": nonce,
                    "clientTimestamp": timestamp,
                    "tag": authentication_proof(
                        key,
                        nonce=nonce,
                        client_id="phone-e2e",
                        credential_id=credential_id,
                        timestamp=timestamp,
                        message_id=message_id,
                    ),
                },
                sequence=sequence,
                message_id=message_id,
                timestamp=timestamp,
            ).signed(key, session_nonce=nonce)
            await socket.send(authentication.encode())
            await receive_type(socket, "acknowledgement", key=key, nonce=nonce)
            sequence += 1
            stop = Envelope.create("stop_assistance", sequence=sequence).signed(
                key, session_nonce=nonce
            )
            await socket.send(stop.encode())
            await receive_type(socket, "acknowledgement", key=key, nonce=nonce)
            assert engine.state == AssistanceState.IDLE
    finally:
        await server.close()
        await engine.close()
