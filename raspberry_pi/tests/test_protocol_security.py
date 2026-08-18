from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor

import pytest

from ai_blind_pi.models import now_iso
from ai_blind_pi.persistence import StateStore
from ai_blind_pi.protocol import Envelope, ProtocolError
from ai_blind_pi.security import (
    PairingManager,
    ReplayGuard,
    authentication_proof,
    derive_auth_key,
)


def test_envelope_is_strict_and_hmac_is_nonce_bound() -> None:
    key = derive_auth_key("AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")
    envelope = Envelope.create(
        "update_settings",
        {"speechEnabled": True, "confidenceThreshold": 0.45},
        sequence=7,
        message_id="12345678abcdef00",
        timestamp="2026-08-09T12:34:56.123456Z",
    )
    signed = envelope.signed(key, session_nonce="server-nonce")
    decoded = Envelope.decode(signed.encode())
    decoded.verify_authentication_tag(key, session_nonce="server-nonce")
    with pytest.raises(ProtocolError, match="authentication tag"):
        decoded.verify_authentication_tag(key, session_nonce="different-nonce")

    malformed = json.loads(signed.encode())
    malformed["unknown"] = True
    with pytest.raises(ProtocolError, match="missing or unknown"):
        Envelope.decode(json.dumps(malformed))


def test_pair_authenticate_replay_and_revoke(tmp_path) -> None:
    store = StateStore(tmp_path / "state.json")
    pairing = PairingManager(store)
    code, _ = pairing.create_code(60)
    credential_id, secret = pairing.consume_code(
        code, client_id="phone-client", display_name="Test phone"
    )
    key = derive_auth_key(secret)
    timestamp = now_iso()
    message_id = "authentication-message-0001"
    payload = {
        "clientId": "phone-client",
        "credentialId": credential_id,
        "nonce": "fresh-server-nonce",
        "clientTimestamp": timestamp,
        "tag": authentication_proof(
            key,
            nonce="fresh-server-nonce",
            client_id="phone-client",
            credential_id=credential_id,
            timestamp=timestamp,
            message_id=message_id,
        ),
    }
    envelope = Envelope.create(
        "authentication",
        payload,
        sequence=2,
        message_id=message_id,
        timestamp=timestamp,
    ).signed(key, session_nonce="fresh-server-nonce")
    guard = ReplayGuard()
    authenticated_id, verifier = pairing.authenticate(
        envelope, expected_nonce="fresh-server-nonce", replay_guard=guard
    )
    assert authenticated_id == credential_id
    assert verifier == key
    envelope.verify_authentication_tag(verifier, session_nonce="fresh-server-nonce")
    with pytest.raises(ProtocolError, match="already been used"):
        pairing.authenticate(envelope, expected_nonce="fresh-server-nonce", replay_guard=guard)
    assert pairing.revoke(credential_id)
    assert store.load()["credentials"][credential_id]["revoked"] is True


def test_pairing_code_failure_and_expiry(tmp_path, monkeypatch) -> None:
    store = StateStore(tmp_path / "state.json")
    pairing = PairingManager(store)
    code, expires_at = pairing.create_code(60)
    with pytest.raises(ProtocolError, match="invalid"):
        pairing.consume_code("22222222", client_id="phone-client", display_name="Test phone")
    monkeypatch.setattr("ai_blind_pi.security.now_ms", lambda: expires_at + 1)
    with pytest.raises(ProtocolError, match="expired"):
        pairing.consume_code(code, client_id="phone-client", display_name="Test phone")


def test_pairing_code_is_consumed_atomically_once(tmp_path) -> None:
    pairing = PairingManager(StateStore(tmp_path / "state.json"))
    code, _ = pairing.create_code(60)

    def consume(client_id: str):
        try:
            return pairing.consume_code(code, client_id=client_id, display_name=client_id)
        except ProtocolError as error:
            return error.code

    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(consume, ["phone-one", "phone-two"]))
    assert sum(isinstance(result, tuple) for result in results) == 1
    assert sum(result == "PAIRING_UNAVAILABLE" for result in results) == 1
