# Interaction Specification

Last reviewed: 2026-08-20

## Global Rules

- Every important control is reachable and meaningfully labelled for TalkBack.
- Loading, success, paused, and error states use text/semantics as well as
  color.
- Primary controls retain native Flutter button semantics and adequate touch
  targets.
- Large text must scroll rather than clip.
- Camera and assistance never start without permission and a loaded model.
- Speech and haptics are rate-limited; no vibration pattern loops.
- Alerts never claim exact distance, identity, or guaranteed navigation.

## Implemented Screen Interactions

| Screen | Action | Result |
|---|---|---|
| Startup | Continue | Opens Home; no network or camera starts. |
| Permissions | Allow Camera | Invokes Android camera permission request. |
| Permissions | Open Settings | Available after permanent denial. |
| Mode Selection | Select Mobile Mode | Saves Mobile Mode locally and returns to its workflow. |
| Mode Selection | Select Pi Mode | Saves the preference and opens the local Wearable workflow without starting Mobile camera/inference. |
| Home | Start Assistance | Opens Mobile Assistance; user starts the real pipeline there. |
| Home | Stop Assistance | Stops an active Mobile session and releases its resources. |
| App foreground | Say “Hey Vision AI” | Vision AI acknowledges aloud, accepts a command, speaks the result, and returns to ready state without touch. |
| Home | Assistant | Opens live assistant status, typed/manual alternatives, connection, and settings. |
| Mobile Assistance | Start/Resume | permission → camera → model → stream → inference → feedback → Detecting. |
| Mobile Assistance | Stop | Cancels feedback/inference, clears detections, and releases camera/model resources. |
| Mobile Assistance | Retry | Retries from safe camera/model/inference/feedback error state. |
| Settings | Select sensitivity | Saves low/medium/high and changes confidence to 0.60/0.45/0.30. |
| Settings | Select feedback | Saves audio, vibration, or combined output mode. |
| Help | Next/previous/finish | Moves through native accessible guide controls. |
| About | Review safety | Exposes privacy, offline operation, and assistive-aid limitation. |
| Raspberry Pi | Scan/manual endpoint | Discovers NSD services or validates a private local endpoint without cloud lookup. |
| Raspberry Pi | First Connect & Start | On an explicitly enabled unclaimed Pi, atomically enrolls the first private-LAN phone without a displayed code, protects its credential with Keystore, authenticates, synchronizes settings, and starts detection. |
| Raspberry Pi | Connect/start/pause/resume/stop | Sends authenticated acknowledged commands while the Pi owns camera/inference; priority speech targets the connected phone with Pi-local disconnect fallback. |
| Raspberry Pi | Retry/forget | Performs bounded recovery or revokes/removes the trusted-phone credential. |
| Assistant connection | Pair laptop | Validates a private host, port and expiring code; stores the bearer through Android Keystore. |
| Assistant | Type app command | Parses and executes the bounded command on-phone before any pairing/network check. |
| Assistant | Type general conversation | Uses Gemini/Ollama reasoning only when the optional laptop is paired and reachable. |
| Assistant | Tap or hold push-to-talk | Manual alternative prefers Android's dedicated recognizer and falls back to bundled Vosk; app-command audio is never uploaded. |
| Assistant | Speak Confirm/Cancel or use buttons | Executes or rejects a sensitive allow-listed action; no action runs before confirmation. |
| Assistant settings | Toggle “Listen for Hey Vision AI” | Starts/stops the foreground listener after microphone permission. |
| Assistant settings | Review/disconnect/clear | Shows privacy/provider boundary, removes the local credential, or clears retained history. |

## Mobile Assistance State Interaction

| State | Primary interaction |
|---|---|
| Permission required/denied | Request permission or read the rationale. |
| Permanently denied | Open Android app settings. |
| Loading camera/model | Wait; start cannot be duplicated. |
| Ready | Transition immediately into the user-requested stream startup. |
| Detecting | Review live status/current alert and use Stop. |
| Paused | Explicitly Resume or Stop; camera does not silently auto-start. |
| Camera/model/inference/feedback error | Read the specific error, Retry, Stop, or change settings as offered. |

The current alert is a polite live region. A critical risk upgrade may interrupt
lower-priority app speech, but normal alerts obey the global 1.2-second rate
limit, per-class cooldown, and duplicate suppression.

## Feedback Interactions

- Detection audio uses local Android TTS and does not request microphone.
- Foreground hands-free voice uses a one-time microphone grant, pauses during
  TTS, and stops on lock/background. Manual/typed alternatives remain.
- Vibration uses finite risk patterns.
- Combined mode attempts both. If one output fails, the other continues with a
  visible warning; if all selected outputs fail, assistance stops safely.
- Stop/pause cancels current speech and vibration.

## Wearable Interactions

Discovery, exclusive enrollment, authentication, settings synchronization, acknowledged
commands, heartbeat/reconnect and compact detection/health events are
implemented. Raw frames never enter the phone transport. Pi-local speech and
assistance remain active after simulated phone disconnect. The user can switch
to the independent Mobile Mode at any time. Physical Pi/phone acceptance and
real NCNN/camera/audio performance remain open.

## Assistant Interactions

Common controls such as sensitivity and mode status use deterministic local
matching. Other requests use Gemini first only when configured, then Ollama on
failure. The response identifies connection/provider health truthfully without
exposing keys or tokens. Gemini receives text only, never raw audio or frames.
Leaving/backgrounding cancels recognition; returning foreground serially
restarts the enabled listener. Provider/network failure cannot execute an
action and exposes a recovery message. The laptop transport is trusted-LAN
only because HTTP authentication does not provide confidentiality.

## Manual Accessibility Acceptance

Physical TalkBack testing must confirm logical focus order, state
announcements, permission dialog return, current-alert cadence, Stop/Retry/Open
Settings discoverability, selected setting state, and 2.0+ font/display scale.
