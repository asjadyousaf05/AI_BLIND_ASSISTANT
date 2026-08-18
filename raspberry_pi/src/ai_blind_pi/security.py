"""Short-lived pairing and nonce-bound HMAC session authentication."""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import uuid
from collections import OrderedDict
from typing import Any

from .models import now_ms, parse_utc_timestamp
from .persistence import StateStore
from .protocol import MAX_CLOCK_SKEW_MS, Envelope, ProtocolError

PAIRING_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _b64decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def derive_auth_key(token: str) -> bytes:
    """Derive the verifier used by both peers; the Pi never stores the token."""
    try:
        decoded = _b64decode(token)
    except (ValueError, base64.binascii.Error) as error:
        raise ProtocolError(
            "AUTH_CREDENTIAL_INVALID", "credential secret is not valid base64url"
        ) from error
    if len(decoded) < 32:
        raise ProtocolError("AUTH_CREDENTIAL_INVALID", "credential secret is too short")
    return hashlib.sha256(decoded).digest()


def authentication_proof(
    auth_key: bytes,
    *,
    nonce: str,
    credential_id: str,
    client_id: str,
    timestamp: str,
    message_id: str,
) -> str:
    values = [nonce, client_id, credential_id, timestamp, message_id]
    canonical = "v1" + "".join(f"|{len(value.encode('utf-8'))}:{value}" for value in values)
    return hmac.new(auth_key, canonical.encode("utf-8"), hashlib.sha256).hexdigest()


class ReplayGuard:
    def __init__(self, *, max_entries: int = 4096, retention_ms: int = 120_000):
        self.max_entries = max_entries
        self.retention_ms = retention_ms
        self._seen: OrderedDict[str, int] = OrderedDict()

    def check_and_mark(
        self, message_id: str, timestamp: str, *, current_ms: int | None = None
    ) -> None:
        current = now_ms() if current_ms is None else current_ms
        timestamp_ms = int(parse_utc_timestamp(timestamp, "timestamp").timestamp() * 1000)
        if abs(current - timestamp_ms) > MAX_CLOCK_SKEW_MS:
            raise ProtocolError("STALE_MESSAGE", "message timestamp is outside the allowed window")
        cutoff = current - self.retention_ms
        while self._seen and next(iter(self._seen.values())) < cutoff:
            self._seen.popitem(last=False)
        if message_id in self._seen:
            raise ProtocolError("REPLAY_DETECTED", "message ID has already been used")
        self._seen[message_id] = current
        while len(self._seen) > self.max_entries:
            self._seen.popitem(last=False)


class PairingManager:
    def __init__(self, store: StateStore):
        self.store = store

    def create_code(self, ttl_seconds: int) -> tuple[str, int]:
        code = "".join(secrets.choice(PAIRING_ALPHABET) for _ in range(8))
        salt = secrets.token_bytes(16)
        expires_at = now_ms() + ttl_seconds * 1000
        digest = hashlib.scrypt(code.encode("ascii"), salt=salt, n=2**14, r=8, p=1, dklen=32)

        def mutate(state: dict[str, Any]) -> None:
            state["pairingChallenge"] = {
                "salt": _b64(salt),
                "digest": _b64(digest),
                "expiresAt": expires_at,
                "attemptsRemaining": 5,
            }

        self.store.update(mutate)
        return code, expires_at

    def consume_code(self, code: str, *, client_id: str, display_name: str) -> tuple[str, str]:
        credential_id = str(uuid.uuid4())
        token = _b64(secrets.token_bytes(32))
        verifier = derive_auth_key(token)
        outcome: dict[str, str] = {}

        def mutate(state_to_update: dict[str, Any]) -> None:
            challenge = state_to_update.get("pairingChallenge")
            if not isinstance(challenge, dict):
                outcome.update(code="PAIRING_UNAVAILABLE", message="no active pairing challenge")
                return
            if now_ms() > int(challenge.get("expiresAt", 0)):
                state_to_update["pairingChallenge"] = None
                outcome.update(code="PAIRING_EXPIRED", message="pairing challenge has expired")
                return
            attempts = int(challenge.get("attemptsRemaining", 0))
            if attempts <= 0:
                state_to_update["pairingChallenge"] = None
                outcome.update(code="PAIRING_LOCKED", message="pairing attempts exhausted")
                return
            try:
                salt = _b64decode(str(challenge["salt"]))
                expected = _b64decode(str(challenge["digest"]))
            except (KeyError, ValueError, base64.binascii.Error):
                state_to_update["pairingChallenge"] = None
                outcome.update(code="PAIRING_UNAVAILABLE", message="pairing state is invalid")
                return
            supplied = hashlib.scrypt(
                code.strip().upper().encode("ascii"),
                salt=salt,
                n=2**14,
                r=8,
                p=1,
                dklen=32,
            )
            if not hmac.compare_digest(expected, supplied):
                challenge["attemptsRemaining"] = max(0, attempts - 1)
                outcome.update(code="PAIRING_CODE_INVALID", message="pairing code is invalid")
                return
            credentials = state_to_update.setdefault("credentials", {})
            if len(credentials) >= 8:
                oldest = min(credentials, key=lambda key: credentials[key].get("createdAt", 0))
                del credentials[oldest]
            credentials[credential_id] = {
                "verifier": _b64(verifier),
                "clientId": client_id,
                "displayName": display_name[:80],
                "createdAt": now_ms(),
                "lastUsedAt": None,
                "revoked": False,
            }
            state_to_update["pairingChallenge"] = None
            outcome["paired"] = "true"

        self.store.update(mutate)
        if outcome.get("paired") != "true":
            raise ProtocolError(
                outcome.get("code", "PAIRING_UNAVAILABLE"),
                outcome.get("message", "pairing could not be completed"),
            )
        return credential_id, token

    def authenticate(
        self,
        envelope: Envelope,
        *,
        expected_nonce: str,
        replay_guard: ReplayGuard,
    ) -> tuple[str, bytes]:
        replay_guard.check_and_mark(envelope.message_id, envelope.timestamp)
        payload = envelope.payload
        required = {"credentialId", "clientId", "nonce", "clientTimestamp", "tag"}
        if set(payload) != required:
            raise ProtocolError("INVALID_PAYLOAD", "authentication payload fields are invalid")
        credential_id = str(payload["credentialId"])
        client_id = str(payload["clientId"])
        nonce = str(payload["nonce"])
        client_timestamp = str(payload["clientTimestamp"])
        proof = str(payload["tag"])
        if client_timestamp != envelope.timestamp:
            raise ProtocolError(
                "AUTH_TIMESTAMP_INVALID",
                "authentication timestamp does not match the envelope",
            )
        if not hmac.compare_digest(nonce, expected_nonce):
            raise ProtocolError("AUTH_CHALLENGE_INVALID", "authentication challenge is invalid")
        state = self.store.load()
        credential = state.get("credentials", {}).get(credential_id)
        if not isinstance(credential, dict) or credential.get("revoked"):
            raise ProtocolError("AUTH_CREDENTIAL_INVALID", "credential is unknown or revoked")
        if not hmac.compare_digest(str(credential.get("clientId", "")), client_id):
            raise ProtocolError("AUTH_CREDENTIAL_INVALID", "credential client does not match")
        try:
            verifier = _b64decode(str(credential["verifier"]))
        except (KeyError, ValueError) as error:
            raise ProtocolError("AUTH_CREDENTIAL_INVALID", "credential is corrupt") from error
        expected = authentication_proof(
            verifier,
            nonce=nonce,
            credential_id=credential_id,
            client_id=client_id,
            timestamp=client_timestamp,
            message_id=envelope.message_id,
        )
        if not hmac.compare_digest(expected, proof):
            raise ProtocolError("AUTH_PROOF_INVALID", "authentication proof is invalid")

        def mutate(updated: dict[str, Any]) -> None:
            existing = updated.get("credentials", {}).get(credential_id)
            if existing:
                existing["lastUsedAt"] = now_ms()

        self.store.update(mutate)
        return credential_id, verifier

    def credential_key(self, credential_id: str) -> bytes | None:
        """Return a stored verifier for authenticating a signed error reply.

        Revocation is intentionally checked by :meth:`authenticate`; retaining
        access here lets a previously paired phone receive a tamper-evident
        `AUTH_CREDENTIAL_INVALID` instead of an unsigned handshake failure.
        """
        credential = self.store.load().get("credentials", {}).get(credential_id)
        if not isinstance(credential, dict):
            return None
        try:
            return _b64decode(str(credential["verifier"]))
        except (KeyError, ValueError):
            return None

    def revoke(self, credential_id: str) -> bool:
        revoked = False

        def mutate(state: dict[str, Any]) -> None:
            nonlocal revoked
            credentials = state.get("credentials", {})
            if credential_id == "all":
                for credential in credentials.values():
                    credential["revoked"] = True
                    revoked = True
            elif credential_id in credentials:
                credentials[credential_id]["revoked"] = True
                revoked = True

        self.store.update(mutate)
        return revoked
