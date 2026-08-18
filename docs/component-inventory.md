# Component Inventory

Last reviewed: 2026-08-14

## Reusable Flutter Components Implemented In Module 4

| Component | Flutter widget | Source screens | Key props | States represented | Accessibility behavior |
|---|---|---|---|---|---|
| Screen scaffold | `AppScreenScaffold` | All migrated screens | title, children, app bar visibility, trailing action, bottom navigation, max width, padding | with/without app bar, with/without bottom navigation | Marks route names through `Semantics(namesRoute: true)`, safe-area-aware, scrollable. |
| Top app bar | `AccessibleTopBar` | SCR-002, SCR-003, SCR-005, SCR-006, SCR-007, SCR-008, SCR-009, SCR-010 | title, back visibility, leading label, trailing widget | back-enabled, back-hidden, trailing action | Native `AppBar` with heading-level-1 title and labeled back action. |
| Primary action button | `PrimaryActionButton` | SCR-001 through SCR-010 | label, icon, onPressed, semanticLabel, height | enabled, disabled | Native `FilledButton` with explicit button semantics and min 56 px height. |
| Secondary action button | `SecondaryActionButton` | SCR-002, SCR-003, SCR-004, SCR-005, SCR-006, SCR-007, SCR-008, SCR-009 | label, icon, onPressed, semanticLabel, height | enabled, disabled | Native button role, explicit enabled state, icon paired with text. |
| Bottom navigation | `AppBottomNavigation` | SCR-004, SCR-006, SCR-009, SCR-010 | selected route, item list | selected/unselected | Uses Flutter `NavigationBar` with route constants and destination tooltips where useful. |
| Brand icon badge | `BrandIconBadge` | SCR-001, SCR-002, SCR-004, SCR-006, SCR-007, SCR-010 | icon, label, size, square, filled | decorative, semantic, filled, outline | Excludes decorative badges from semantics unless a label is supplied. |
| Status pill | `StatusPill` | SCR-003, SCR-004, SCR-005, SCR-006, SCR-007 | label, icon, color | ready, inactive, disconnected, selected | Announces status text independent of color. |
| Status summary card | `StatusSummaryCard` | SCR-004, SCR-005 | label, value, icon, color | ready, inactive, warning | Announces label and value together. |
| Feature note card | `FeatureNoteCard` | SCR-001, SCR-002, SCR-003, SCR-006, SCR-007, SCR-008, SCR-010 | icon, title, description | default informational | Icon is decorative; text carries meaning. |
| Safety notice | `SafetyNotice` | SCR-004, SCR-005, SCR-010 | title, messages | compact warning | Dedicated semantic container for safety limitations. |
| Error notice | `ErrorNotice` | SCR-002, SCR-005, SCR-007 | title, message, icon | error/warning | Announces title and message together. |
| Selectable card | `SelectableInfoCard` | SCR-003 | title, description, icon, selected, enabled, status, semanticLabel | selected, unselected, disabled/deferred | Semantic container with button, selected, and enabled state. |
| Setting choice card | `SettingChoiceCard<T>` | SCR-008 | value, groupValue, title, icon, onChanged | selected, unselected | Semantic container with mutually exclusive group and selected state. |
| Assistant hands-free status | feature-local semantic card/switch | Assistant | wake readiness, lifecycle and permission state | preparing, ready, command window, paused, error | Live-region text names “Hey Vision AI”; status is not color-only. |
| Assistant push-to-talk | feature-local native button composition | Assistant | tap/hold callbacks, state, labels | idle, listening, processing, unavailable | Explicit semantic label/state; manual/typed alternative. |
| Assistant confirmation card | feature-local native controls | Assistant | prompt, confirm/cancel | awaiting, executing | Confirm and Cancel are separately labelled and never time-limited. |
| Assistant message list | feature-local native list | Assistant | role/content/status | user, assistant, error | Text remains readable/scrollable and spoken response uses local TTS. |

## Components Not Extracted as Shared Widgets

| Planned component | Source screens | Reason deferred | Future module notes |
|---|---|---|---|
| `ConnectionDeviceCard` | SCR-006 | Feature-local discovered/selected device widgets now cover the implemented Wearable flow. | Extract only if another feature needs the same contract. |
| `HelpStepCarousel` | SCR-009 | Module 4 implemented a simple accessible stepper instead of a gesture-heavy carousel. | Add only if it remains TalkBack-friendly. |
| `AccessibleIconButton` wrapper | Multiple screens | Native `IconButton` with tooltip was sufficient for current usage. | Add only if repeated custom semantics emerge. |
| `SegmentedPreferenceControl<T>` | SCR-008 | `SettingChoiceCard<T>` matches current large-touch Stitch visual better. | Revisit if Android segmented controls become preferred. |
| `SensitivitySelector` | SCR-008 | Covered by generic `SettingChoiceCard<T>`. | Keep generic unless future behavior diverges. |

## Component States Still Needed Later

| Component area | Missing state | Why it matters |
|---|---|---|
| Permission screen | physical system-dialog/TalkBack verification | Runtime states and Open Settings are implemented. |
| Home screen | physical large-text/TalkBack verification | Runtime readiness and session state are implemented. |
| Assistance UI | physical camera/box/alert verification | Real preview, zero/real detections, errors, alerts, Start/Stop/Resume are implemented. |
| Settings | physical unavailable speech/haptic capability behavior | Persistence and controller wiring are implemented. |
| Raspberry Pi flow | physical discovery/pairing/connected/loss/incompatible/TalkBack verification | The complete local state machine and simulator path are implemented; hardware acceptance remains. |
| Assistant flow | physical microphone, TalkBack, TTS/audio focus, Gemini/fallback and LAN interruption | Automated layout/controller/backend paths are implemented. |
| Help/About | expanded safety sections, manual support links if approved | FYP safety scope must remain visible and accessible. |

## Component Migration Notes

- Do not copy Tailwind class names into Flutter widgets as implementation detail.
- Keep screen widgets thin; business state belongs in controllers/providers and domain services.
- Use Flutter native controls and semantics before creating custom controls.
- Remote background images from Stitch are not production assets.
- Module 4 intentionally uses Material icons through `AppIcons`; no remote icon font is used.
- All implemented components are covered indirectly by clean analysis and the
  175-test suite. Physical TalkBack, voice and platform feedback checks remain open.
