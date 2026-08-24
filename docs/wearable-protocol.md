# Wearable Protocol v1

Last reviewed: 2026-08-20

## Scope

This protocol connects one Flutter controller to the local Raspberry Pi
wearable service over a bidirectional WebSocket. It carries commands,
acknowledgements, compact detections, component state, and health data. It does
not carry camera frames in normal operation and does not require a cloud
service.

The service name is `_aiba-wearable._tcp`, the default WebSocket path is
`/wearable/v1`, and the protocol version is integer `1`. Host and port come
from mDNS, a saved trusted device, or validated manual entry; no address is the
sole supported address.

## Envelope

Every message is UTF-8 JSON no larger than 65,536 bytes:

```json
{
  "protocolVersion": 1,
  "type": "device_status",
  "messageId": "random-unique-id",
  "timestamp": "2026-08-07T12:00:00.000Z",
  "sequence": 42,
  "payload": {},
  "authenticationTag": "lowercase-hmac-sha256-hex"
}
```

- `messageId` is unique per sender and is used for replay rejection and
  idempotent command responses.
- `timestamp` is UTC ISO 8601. Authenticated commands outside the configured
  clock-skew window are rejected.
- `sequence` is monotonic per connection for ordered event handling.
- `authenticationTag` is omitted only for `hello`, `enrollment_request`,
  `enrollment_result`, and the legacy `pair_request` / `pair_result`. The
  `authentication` request and its acknowledgement are
  signed with the credential-derived key and the fresh hello nonce.
- Unknown envelope and payload fields are rejected in protocol v1. Missing,
  invalid, oversized, or unknown message types receive a
  structured error and do not crash the service.

## Negotiation, enrollment, and authentication

1. The Pi sends `hello` with its device identity, supported versions,
   capabilities, service version, a fresh random nonce, and whether the device
   already has an active trusted client.
2. On an explicitly configured, unclaimed Pi, the first phone sends
   `enrollment_request` with its random installation identity. The operation is
   accepted only from a private/loopback peer while no non-revoked credential
   exists. It is atomic, so simultaneous phones cannot both enroll.
3. `enrollment_result` returns one random revocable credential. Android stores
   it using a non-exportable Keystore AES-GCM key; the Pi stores only the
   protected credential verifier in its owner-readable state directory.
4. Later connections send `authentication` with the credential identifier and
   an HMAC-SHA256 proof bound to the server nonce and message ID. Both peers use
   `SHA-256(base64url-decoded credential secret)` as the HMAC key, allowing the
   Pi to retain only that derived verifier.
5. Successful authentication establishes the credential used to authenticate
   every later envelope. Invalid/expired codes, unknown/revoked credentials,
   bad tags, stale timestamps, duplicate message IDs, and replayed challenges
   are rejected.

`AIBA_ALLOW_FIRST_CLIENT_ENROLLMENT` defaults off in code and is enabled
explicitly by the reviewed production environment. Enrollment closes as soon
as one active credential exists. The owner must run local `revoke all` to
reopen it if a phone credential is lost. Legacy short-code messages remain for
protocol compatibility but are not exposed by the production Flutter UI.
Neither the Linux username nor password is sent, stored, or packaged.

### Canonical authentication data

The authentication proof signs UTF-8 length-prefixed fields in this exact
order:

```text
v1|len:nonce|len:clientId|len:credentialId|len:clientTimestamp|len:messageId
```

Authenticated envelopes sign this exact canonical string, where `payload` is
recursively key-sorted compact JSON:

```text
envelope-v1|len:sessionNonce|len:protocolVersion|len:type|len:messageId|len:timestamp|len:sequence|len:payload
```

`len` is the field's UTF-8 byte length. Tags are lowercase 64-character
HMAC-SHA256 hex. The shared key is
`SHA-256(base64url-decoded credentialSecret)`; the Pi stores this derived key,
not the returned secret.

## Message types

| Type | Direction | Purpose / required behavior |
|---|---|---|
| `hello` | Pi → phone | Version/capability negotiation and fresh authentication nonce. |
| `enrollment_request` | phone → Pi | First-phone identity; accepted only on an enabled, private-LAN, unclaimed Pi. |
| `enrollment_result` | Pi → phone | Exclusive enrollment result; returns a random credential once on success. |
| `pair_request` / `pair_result` | phone ↔ Pi | Legacy owner-code compatibility; unused by the production Flutter UI. |
| `revoke_credential` | phone → Pi | Revoke the authenticated client before local Forget Device cleanup. |
| `authentication` | phone ↔ Pi | Challenge proof and authenticated-session result. |
| `heartbeat` | either | Authenticated `ping`/`pong` liveness with optional `replyTo`. |
| `device_status` | Pi → phone | Assistance state, mode, settings revision, last update. |
| `start_assistance` | phone → Pi | Idempotently enter running state. |
| `pause_assistance` | phone → Pi | Idempotently pause capture/inference. |
| `resume_assistance` | phone → Pi | Idempotently resume a paused session. |
| `stop_assistance` | phone → Pi | Idempotently stop and release camera/inference resources. |
| `change_mode` | phone → Pi | Select a service-supported detection/assistance mode. |
| `update_settings` | phone → Pi | Validate, persist, and acknowledge a newer settings snapshot. |
| `request_current_settings` | phone → Pi | Request the Pi's accepted snapshot. |
| `synchronize_settings` | either | Exchange accepted version and validated setting values. |
| `detection_event` | Pi → phone | Compact class, confidence, normalized box, direction, time, sequence, and priority. |
| `priority_hazard_alert` | Pi → phone | Urgent relative visual warning; never a metric-distance claim. |
| `camera_status` / `camera_error` | Pi → phone | Camera readiness or bounded-recovery failure. |
| `model_status` / `model_error` | Pi → phone | NCNN/model readiness or validation/inference failure. |
| `device_health` | Pi → phone | Uptime, bounded resource metrics, temperature, throttling/power when available. |
| `acknowledgement` | either | `requestMessageId`, `applied`, and optional safe detail. |
| `error` | either | `requestMessageId`, stable error code, recoverable flag, and safe message. |
| `graceful_disconnect` | either | Graceful reason before the WebSocket closes. |

All control commands require `acknowledgement` or `error`. The Pi caches a
bounded number of command results by `messageId`; retrying the same important
command therefore returns the prior result instead of applying the operation
twice.

## Detection payload

```json
{
  "sourceDeviceId": "device-id",
  "frameSequence": 184,
  "classId": 104,
  "className": "Chair",
  "confidence": 0.81,
  "boundingBox": {"left": 0.1, "top": 0.2, "right": 0.7, "bottom": 0.9},
  "direction": "center",
  "capturedAt": "2026-08-07T12:00:00.000Z",
  "priority": 78,
  "alertCategory": "mobility_hazard",
  "relativeProximity": "very_close",
  "feedbackTarget": "phone",
  "piAnnounced": false
}
```

Coordinates are normalized to the captured frame. Direction is
`left`, `center`, or `right`. Priority is a documented visual heuristic based
on class, centrality, and apparent box area. It is not distance in metres.
Ordinary `detection_event` telemetry uses `feedbackTarget: "none"`. After the
Pi stability, cooldown, and rate gates choose one priority alert, the policy
uses `feedbackTarget: "phone"` only while an authenticated phone is connected.
Flutter then routes the signed/deduplicated event through its single voice/TTS
owner. When no authenticated phone is connected, the priority event uses
`feedbackTarget: "pi"` and Pi-local speech. `piAnnounced` prevents duplicate
speech. `relativeProximity`, when present, is explicitly an uncalibrated
box-area heuristic and never a physical-distance estimate.

## Settings ownership and conflicts

A snapshot includes `revision`, `updatedAt`, `source`, and `sourceId` plus
confidence, cooldown, speech, vibration, and mode. The Flutter user setting is
sent, validated, persisted on the Pi, and acknowledged. A higher revision wins;
identical versions are idempotent. When revisions tie, later UTC timestamp wins,
then the phone source wins as the deterministic final tie-break. A stale
snapshot never silently overwrites a newer accepted snapshot.

## Reliability limits

- One inference/camera session and one connection attempt are owned by their
  respective state machines; concurrent requests are coalesced or rejected.
- Heartbeats detect stale sessions. Retry uses bounded exponential backoff with
  jitter and a maximum attempt/cooldown policy, so there is no infinite
  battery-draining tight loop.
- Detection events are best-effort compact telemetry. Commands and settings
  have acknowledgements; the project does not claim zero event loss.
- The Pi keeps running if the phone backgrounds or disconnects. Phone lifecycle
  disconnect is not interpreted as a stop command; feedback ownership falls
  back from phone to Pi-local speech.

## Security boundary

Protocol v1 uses `ws://` plus application-level HMAC authentication, integrity,
fresh nonces, timestamps, sequence checks, and replay rejection. It does not
provide transport confidentiality: another device controlling the same LAN may
observe addresses, message sizes, and potentially message contents. Code-free
first enrollment is trust-on-first-use: another client on the same LAN could
claim an unclaimed Pi first. Perform it on an isolated owner-controlled
router/hotspot, verify the intended Pi endpoint, and do not leave an unclaimed
service exposed. The service must be bound to the intended private interface
and protected by the host firewall; it must not be port-forwarded or exposed
to the public internet.

No global TLS validation bypass is present. A future TLS upgrade must use a
properly validated or explicitly pinned device certificate and can preserve
the typed protocol unchanged.
