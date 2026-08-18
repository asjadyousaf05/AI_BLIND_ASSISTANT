# Alert Engine

Last reviewed: 2026-08-06

## Implemented Flow

```text
stable detections -> position/proximity/importance -> sorted alerts
-> highest useful alert -> saved feedback mode -> speech and/or bounded haptic
```

Only detections confirmed in two consecutive processed frames reach the risk
assessor. This stability gate reduces one-frame false alerts.

## Relative Risk Heuristic

Horizontal position is based on normalized box center:

| Center X | Internal position | Spoken direction |
|---:|---|---|
| below 0.15 | left | on the left |
| 0.15 to below 0.35 | center-left | on the left |
| 0.35 to below 0.65 | center | ahead |
| 0.65 to below 0.85 | center-right | on the right |
| 0.85 or above | right | on the right |

Visual proximity combines box area (40%), height (30%), and bottom-of-frame
location (30%). This is a heuristic, not depth or metric distance.

Relative importance combines:

- normalized box size: 45%;
- centrality: 35%;
- safety-relevant class weighting: 20%.

People and road vehicles receive the highest class weight. Common furniture
and carried obstacles receive an intermediate class weight. Risk is then based
on the documented position, visual proximity, and importance thresholds. Low
risk does not generate feedback.

## Spoken Output

`ObstacleAlert.spokenDescription` deliberately stays short:

- “Person ahead”
- “Chair on the left”
- “Bicycle on the right”
- “Car ahead”

“Very close” is added only for the strongest visual proximity category. The app
does not announce meters, exact distance, identity, or navigation guarantees.

## Suppression and Priority Rules

`FeedbackAlertOrchestrator` enforces:

- at most one, highest-priority alert per detection update;
- low-risk suppression;
- per-class cooldown, default three seconds and controlled by saved settings;
- duplicate suppression using class, direction, and risk signature;
- a global minimum interval of 1.2 seconds;
- critical risk-upgrade bypass of normal rate/cooldown suppression;
- speech interruption only when the new alert has higher risk;
- one feedback transaction at a time.

Cooldown state is recorded before awaiting a platform call, preventing a second
frame from racing through while TTS or vibration is starting.

## Saved Feedback Modes

| Mode | Behavior |
|---|---|
| Audio | local Android TTS only |
| Vibration | finite haptic pattern only |
| Audio and vibration | both selected outputs |

The app never requests microphone permission. TTS failures do not silently
disappear: if one of two selected outputs fails, the other remains active and a
warning is exposed; if every selected output fails, assistance enters a
feedback error state.

## Bounded Haptics

| Risk | Pattern |
|---|---|
| Critical | three 200 ms pulses separated by 100 ms |
| High | two 150 ms pulses separated by 100 ms |
| Moderate | one 100 ms pulse |
| Low | defined as one 50 ms pulse, but low-risk alerts are currently suppressed |

No pattern loops. Stop, pause, error cleanup, and disposal stop TTS and cancel
vibration.

## Remaining Device Checks

Automated tests cover cooldown, duplicate suppression, priority, feedback-mode
routing, finite patterns at the service boundary, and TTS failure fallback.
A physical phone is still required to verify installed offline voices,
intelligibility, actual vibration amplitudes, TalkBack interaction, and the
announcement cadence in real scenes.

