# UI Migration Map

Last reviewed: 2026-08-06

Stitch source files remain under `stitch/` as design references. Production is
native Flutter with local/native assets, centralized tokens, route constants,
and accessibility semantics. No Stitch HTML is embedded and no remote Stitch
asset is loaded at runtime.

| ID | Stitch reference | Flutter screen/route | Current runtime state | Remaining manual work |
|---|---|---|---|---|
| SCR-001 | splash | `StartupScreen`, `/startup` | implemented offline/private entry | physical TalkBack |
| SCR-002 | permissions | `PermissionsScreen`, `/permissions/camera` | real camera request, deny, permanent deny/Open Settings | physical system-dialog flow |
| SCR-003 | mode selection | `ModeSelectionScreen`, `/modes` | local Mobile selection; Pi explicitly deferred | physical TalkBack selected state |
| SCR-004 | home | `HomeScreen`, `/home` | Mobile readiness and start navigation reflect session state | physical large-text review |
| SCR-005 | assistance running | `MobileAssistanceScreen`, `/mobile-assistance` | real permission/camera/model/detection/alert/error/lifecycle states | physical camera, boxes, feedback, TalkBack |
| SCR-006 | Pi connection | `RaspberryPiScreen`, `/raspberry-pi` | disconnected/deferred shell only | runtime intentionally deferred |
| SCR-007 | Pi error | `ConnectionErrorScreen`, `/raspberry-pi/error` | truthful deferred/local error shell | runtime intentionally deferred |
| SCR-008 | settings | `SettingsScreen`, `/settings` | local persistent feedback mode, vibration, cooldown, sensitivity | physical capability/feedback check |
| SCR-009 | help | `HelpScreen`, `/help` | accessible native step controls | physical TalkBack |
| SCR-010 | about | `AboutSafetyScreen`, `/about-safety` | offline/privacy/accessibility/safety limitation | physical TalkBack |

## Corrected Production Behavior

- The permissions flow describes local camera detection, not photo sharing.
- Home and Mobile Mode now state that real offline detection is available.
- Mobile Mode shows permission, camera/model loading, ready, detecting, paused,
  and specific error states without changing the established visual system.
- Detection overlay data comes only from real model output; zero detections is
  shown honestly.
- Alerts use relative direction/visual importance and never exact meters.
- Generic `person` detection is not identity or face recognition.
- Settings are local and immediately affect detection/feedback controllers.
- Pi controls remain unavailable and do not imply networking exists.

## Shared Components Preserved

- `AppScreenScaffold`
- `AccessibleTopBar`
- `PrimaryActionButton` / `SecondaryActionButton`
- `AppBottomNavigation`
- `BrandIconBadge`
- `StatusPill` / `StatusSummaryCard`
- `FeatureNoteCard`, `SafetyNotice`, `ErrorNotice`
- `SelectableInfoCard`, `SettingChoiceCard<T>`

Mobile Assistance composes these with the existing camera preview/detection
overlay and dynamic semantic status; it was not redesigned.

## Automated Evidence

- `WT-ROUTER-001`–`004`: route and back/unknown behavior.
- `WT-UI-001`–`007`: screens, state interactions, settings, Pi deferral,
  help, and 2.0 text scale.
- `WT-ACC-001`–`002`: labels and representative large-text behavior.
- Full suite: all 128 tests passed on 2026-08-06.

## Production Asset Boundaries

- Do not register Stitch screenshots as app UI.
- Do not load `lh3.googleusercontent.com`, Google Fonts, Tailwind CDN, or remote
  Material Symbols.
- Use app-owned assets or Flutter Material icons through existing token aliases.
- Preserve corrected copy; do not reintroduce Lumina branding, History, cloud,
  OCR, exact-distance, or internet-troubleshooting claims.

