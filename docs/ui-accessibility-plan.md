# UI Accessibility Plan

Last reviewed: 2026-08-06

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

Manual TalkBack tests remain blocked because no physical Android phone is
connected. Emulator runtime is available but is not sufficient final TalkBack
evidence for the target user workflow.

## Automated Accessibility Tests

Current automated coverage:

- `WT-ACC-001` verifies important native controls expose semantic labels.
- `WT-ACC-002` verifies a representative native screen handles 2.0 text scale without crashing.
- `UT-THEME-003` verifies minimum touch-target-related constants.
- `WT-UI-001` through `WT-UI-007` cover migrated routes, dynamic states,
  settings, deferred Pi behavior, help, and 2.0 text scale.
- Current full suite: 128 tests passed; analyzer clean on 2026-08-06.
