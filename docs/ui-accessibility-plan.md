# UI Accessibility Plan

## Module 65 wearable audio and cancellation

Wearable adds a native labeled Test Phone Audio button with the accessible name
“Play a test message through the phone speaker.” It works before pairing and
reports platform failures with recovery text. An explicit visible note explains
when object audio alerts are off. Disconnect remains operable during detection
startup/settings work. Widget tests activate these controls through their
accessible names; physical TalkBack/2× text acceptance remains open.

Last reviewed: 2026-10-03

## Module 63: Control Labeling Convention

Name each action once with familiar words. Prefer a verb and context when
the visible caption is short: “Read first line,” “Use audio alerts,” and
“Go back from Settings.” The screen reader supplies the button role and
selected/disabled/on/off state; do not repeat these in the label. Use a hint
only to explain a consequence. Decorative icons and repeated visual captions
do not become additional focus stops.

| Control | Accessible name or state behavior |
|---|---|
| Startup | Continue to home |
| Back | Go back from the current screen title |
| Mode choice | Select Mobile Mode / Select Raspberry Pi wearable mode; selected flag |
| Feedback choice | Use audio / vibration / audio and vibration alerts; selected flag |
| Sensitivity | Set low / medium / high detection sensitivity; selected flag |
| Cooldown slider | Announcement cooldown; value in seconds; increase/decrease actions |
| Scanner transport | Start Reading / Pause Reading / Resume Reading according to playback |
| Reader navigation | Read previous/next/first/last document line; Choose reading line |
| Reader tools | Repeat current line; Spell out current line letter by letter; Copy full document text to clipboard |
| Reading speed | Set study / normal / fast reading speed; selected flag |
| Camera | Scan document and read aloud; Turn flashlight on/off; Switch camera |
| Vision AI | Speak to Vision AI / Send spoken question or command / Stop assistant speech |
| Typed Send | Native tooltip: Send typed question or command |
| Ask AI | Review scanned document with Vision AI |
| Help | Previous help step / Next help step / Finish the user guide and return home |
| Navigation | Home, Modes, Wearable, Settings; native destination selection state |

Native editable fields use one InputDecoration label. Switches retain native
toggled semantics. Slider name/value/actions are merged into one node.
Custom button wrappers explicitly retain semantic activation when suppressing
duplicate descendant captions.

Module 63 verifies exact labels, selection/disabled flags, semantic taps,
navigation, slider units/adjustment actions, and changing reader transport
names. The full suite passes 351 tests with one environment skip; physical
TalkBack pronunciation, focus order and usefulness require the blind user's
review. No Android device was attached during this pass.

## Accessibility Goals

The final Flutter UI must work with TalkBack, large Android font sizes, and non-visual operation. Stitch provides visual intent only; accessibility must be implemented through native Flutter widgets, semantics, focus order, labels, and accessible state changes.

## Audit Findings From Stitch

| Issue | Affected screens | Impact | Flutter migration action |
|---|---|---|---|
| Missing HTML `<title>` | SCR-008, SCR-009, SCR-010 | Weak page identity in HTML reference. | Every Flutter route must expose a meaningful screen title. |
| Icon-only buttons without labels | SCR-004, SCR-006, SCR-008, SCR-009 and some status/nav icons | TalkBack users may hear only generic button/icon. | Add `Semantics` labels or use labeled native controls. |
| `data-alt` used on `div` backgrounds | SCR-002, SCR-003, SCR-006, SCR-010 | `data-alt` is not announced like real alt text. | Decorative images excluded from semantics; informative images get labels. |
| Hidden radio inputs styled as custom cards | SCR-008 | Visual selection may not map to native semantics if copied directly. | Use Flutter `SegmentedButton`, `Radio`, or equivalent semantic widgets. |
| Swipe-only carousel | SCR-009 | Swipe-only horizontal content can be hard for TalkBack users. | Add next/previous controls and announce step index. |
| Color-only status risk | SCR-004, SCR-005, SCR-006 | Status meaning may be lost without vision. | Pair color with text, icons, and semantic labels. |
| Pulse/animation for running/searching | SCR-002, SCR-005, SCR-006 | Motion is visual only and can distract. | Keep text state; reduce/disable animation where appropriate. |
| Fixed-height/overflow-hidden pages | All screens | Large text can clip controls. | Use scrollable, safe-area-aware Flutter layouts. |
| Small 40 px icon buttons | SCR-002, SCR-006 | Below preferred 48 px target. | Use at least 48 px touch target. |
| Conflicting safety/scope copy | SCR-002, SCR-003, SCR-005, SCR-007, SCR-010 | Misleading output for blind users. | Replace copy with finalized offline assistive scope. |

## Required Semantic Labels

| Screen ID | Required labels |
|---|---|
| SCR-001 | `AI Blind Assistant`, `Continue to home`, `Voice guidance enabled`, optional `Open menu` if retained. |
| SCR-002 | `Back`, `Allow camera access`, `Continue without camera`, `Camera permission illustration` if informative. |
| SCR-003 | `Mobile Mode, selected`, `Raspberry Pi Mode, unavailable until Mobile Mode is stable` or selected when enabled, `Confirm selection`, `Back to menu`. |
| SCR-004 | `Current mode: Mobile Mode`, `System status: Ready`, `Start assistance`, `Stop assistance`, navigation destinations. |
| SCR-005 | `Assistance active`, `Current risk`, `Audio alerts on/off`, `Stop assistance`, cooldown or confirmation state. |
| SCR-006 | `Raspberry Pi connection`, `Searching`, `Raspberry Cap v1`, `Signal strength`, `Connect now`, `Scan again`, navigation destinations. |
| SCR-007 | `Connection failed`, `Retry connection`, `Switch to Mobile Mode`, local error code if shown. |
| SCR-008 | `Feedback mode`, `Audio`, `Vibration`, `Both`, `Detection sensitivity`, `Low`, `Medium`, `High`, `Cancel`, `Save changes`. |
| SCR-009 | `User guide`, `Step 1 of 3`, `Step 2 of 3`, `Step 3 of 3`, `Next step`, `Previous step`, `Got it`. |
| SCR-010 | `About and Safety`, `Offline ready`, `Accessibility first`, `Home`, `About`; omit unsupported History or mark unavailable. |

## Focus Order

Default focus order should follow:

1. App bar title and leading/trailing actions.
2. Main heading.
3. Primary status or content area.
4. Interactive controls in visual order.
5. Persistent bottom navigation.
6. Safety/support links.

Running assistance screens may move the current alert before app bar controls when the alert changes, but announcements must be throttled to avoid overwhelming the user.

## TalkBack Testing Plan

| Test ID | Manual check | Acceptance criterion |
|---|---|---|
| MT-TALKBACK-001 | Startup to home navigation | TalkBack announces app identity and continue button. |
| MT-TALKBACK-002 | Permission flow | Permission rationale and actions are clear without misleading photo-sharing copy. |
| MT-TALKBACK-003 | Mode selection | Selected and unavailable states are announced. |
| MT-TALKBACK-004 | Assistance running | Current alert and stop control are reachable; announcements are not repetitive. |
| MT-TALKBACK-005 | Settings selectors | Feedback and sensitivity selectors announce selected state. |
| MT-TALKBACK-006 | Help carousel | Step number/title and navigation controls are accessible. |
| MT-TALKBACK-007 | About/Safety | Safety limitation is reachable and read clearly. |

An ARM64 Android phone is now available and the release install/direct-start
smoke passed, but no person performed the required TalkBack navigation or
sensory judgment. Automated/emulator evidence is not sufficient for the target
user workflow.

## Automated Accessibility Tests

Current automated coverage:

- `WT-ACC-001` verifies important native controls expose semantic labels.
- `WT-ACC-002` verifies a representative native screen handles 2.0 text scale without crashing.
- `WT-ACC-003` applies Flutter's Android tap-target, label, and contrast
  guidelines to the startup-to-Home primary flow at a 393 x 852 viewport.
- `UT-ACC-001`–`002` verify the saved large-text preference preserves the
  platform's nonlinear `TextScaler` behavior and remains bounded at 2.5.
- `UT-THEME-003` verifies minimum touch-target-related constants.
- `WT-UI-001` through `WT-UI-009` cover approved routes, dynamic states,
  settings, wearable behavior, help, route cleanup and 2.0 text scale.
- Route titles now use semantic heading level 1 and section headings use level
  2, following Flutter's current heading-level migration guidance.
- The live assistant has dedicated 393 x 852 at 2.0 text-scale coverage,
  meaningful push-to-talk state, typed input, and separately labelled
  Confirm/Cancel actions without a timeout.
- Current full suite: 351 passed and one environment-gated Pi test skipped on
  2026-10-03. Changed-file analysis is clean; two existing assistant-controller
  unused imports remain in full analysis.

Physical acceptance must verify TalkBack microphone permission return,
foreground “Hey Vision AI” status, manual hold/release, listening/processing
announcements, spoken/button confirmation focus,
spoken response/audio focus, provider errors, and repeated lifecycle cleanup.
