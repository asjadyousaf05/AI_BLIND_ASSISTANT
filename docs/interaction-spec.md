# Interaction Specification

Last reviewed: 2026-08-06

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
| Mode Selection | Select Pi Mode | Opens a truthful deferred/disconnected UI shell; no networking starts. |
| Home | Start Assistance | Opens Mobile Assistance; user starts the real pipeline there. |
| Mobile Assistance | Start/Resume | permission → camera → model → stream → inference → feedback → Detecting. |
| Mobile Assistance | Stop | Cancels feedback/inference, clears detections, and releases camera/model resources. |
| Mobile Assistance | Retry | Retries from safe camera/model/inference/feedback error state. |
| Settings | Select sensitivity | Saves low/medium/high and changes confidence to 0.60/0.45/0.30. |
| Settings | Select feedback | Saves audio, vibration, or combined output mode. |
| Help | Next/previous/finish | Moves through native accessible guide controls. |
| About | Review safety | Exposes privacy, offline operation, and assistive-aid limitation. |

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

- Audio uses local Android TTS and does not request microphone permission.
- Vibration uses finite risk patterns.
- Combined mode attempts both. If one output fails, the other continues with a
  visible warning; if all selected outputs fail, assistance stops safely.
- Stop/pause cancels current speech and vibration.

## Deferred Pi Interactions

Pi Connect, Scan, Retry, discovery, pairing, networking, frame reception, and
inference remain unavailable. The user can switch back to Mobile Mode. No
internet troubleshooting copy or runtime Pi claim is permitted before the Pi
module is explicitly authorized.

## Manual Accessibility Acceptance

Physical TalkBack testing must confirm logical focus order, state
announcements, permission dialog return, current-alert cadence, Stop/Retry/Open
Settings discoverability, selected setting state, and 2.0+ font/display scale.

