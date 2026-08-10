# AI Blind Assistant Agent Guide

Last reviewed: 2026-07-19

## Project Name and Purpose

AI Blind Assistant is an academic Final Year Project for an offline Android assistive application for blind and visually impaired users. The completed application will use local camera input, lightweight on-device object detection, offline spoken alerts, bounded vibration alerts, local settings, and a TalkBack-compatible Flutter interface.

## Primary User

The primary user is a blind or visually impaired Android user who may rely on TalkBack, large text, audio prompts, and haptic feedback.

## Core Scope

- Android-first Flutter application.
- Native Flutter UI, not WebView.
- Mobile Mode as the first production priority.
- Generic object detection only in the first production version.
- Generic `person` class detection, not face recognition.
- Estimated obstacle risk, not exact physical distance.
- Offline audio and bounded haptic feedback in later modules.
- Optional local Raspberry Pi wearable mode only after Mobile Mode is stable.
- Local-only settings.
- No cloud processing or camera-frame upload.

## Deferred Scope

- Camera streaming.
- Model integration and inference.
- YOLO/LiteRT output parsing.
- Risk assessment.
- TTS and vibration output.
- Raspberry Pi discovery and networking.
- Final Stitch UI conversion.
- Voice commands.
- Familiar-face or familiar-person identification.
- Release signing and production app icon.

## Safety Limitations

The app is an assistive aid only. It must not claim to replace a white cane, guide dog, trained human assistance, professional orientation and mobility training, or user judgment. Detection accuracy can vary, and the app must not be presented as the user's only safety mechanism.

## Required Reading Order

1. `AGENTS.md`
2. `docs/INDEX.md`
3. `docs/PROJECT_STATUS.md`
4. `docs/CURRENT_MODULE.md`
5. `docs/specification-baseline.md`
6. `docs/requirements-traceability.md`
7. `docs/architecture.md`
8. `docs/decision-log.md`
9. `docs/KNOWN_ISSUES.md`
10. `docs/AGENT_HANDOFF.md`

## Source-of-Truth Hierarchy

When information conflicts, use this order:

1. Approved project specification and finalized Module 1 scope decisions.
2. `docs/specification-baseline.md`
3. `docs/requirements-traceability.md`
4. `docs/architecture.md`
5. Accepted records in `docs/decision-log.md`
6. Current source code and automated tests.
7. `docs/PROJECT_STATUS.md`
8. `docs/CURRENT_MODULE.md`
9. `docs/AGENT_HANDOFF.md`
10. Comments, temporary notes, and historical changelog entries.

Record conflicts in `docs/KNOWN_ISSUES.md` and update the conflicting source when the correct interpretation is clear.

## Architecture Rules

- Use feature-first layered structure.
- Presentation may depend on application and domain abstractions.
- Application may depend on domain abstractions.
- Domain must not depend on Flutter UI, camera plugins, AI inference packages, or Raspberry Pi networking packages.
- Infrastructure may implement domain interfaces.
- Widgets must not initialize camera, model, speech, vibration, storage, or networking services directly.
- Do not hardcode route strings throughout widgets.
- Use one state-management approach.
- Use dependency injection through the selected state-management mechanism.

## Accessibility Rules

- Every screen needs a meaningful title.
- Every important control needs a meaningful accessible label.
- Do not communicate status only through color.
- Prefer native buttons and controls.
- Support text scaling and avoid clipped text.
- Avoid icon-only buttons without accessible names.
- Preserve logical focus order.
- Use semantic headers where useful.
- Avoid time-limited interactions.

## Offline-Operation Rules

- Do not add cloud inference.
- Do not add remote configuration.
- Do not add analytics or remote crash reporting.
- Do not load production UI assets from URLs.
- Do not add remote fonts.
- Local Raspberry Pi communication in later modules is allowed only as local offline communication.

## Privacy Rules

Never log or store:

- Camera frames.
- Image byte arrays.
- Face data.
- Audio recordings.
- Personal identifiers.
- Wi-Fi passwords.
- API keys.
- Device secrets.
- Full local file contents.

## Testing Requirements

- Run formatting after code changes.
- Run static analysis.
- Run relevant unit and widget tests.
- Attempt Android debug build when the environment supports it.
- Do not mark a feature complete without verification.
- Do not bypass failing tests by deleting them.
- Record exact command results in living docs.

## Documentation-Update Requirements

- Update `docs/CURRENT_MODULE.md` during active module work.
- Update `docs/PROJECT_STATUS.md` after implementation and validation.
- Update `docs/CHANGELOG.md` only with completed, verified work.
- Update `docs/AGENT_HANDOFF.md` with exact next action.
- Update `docs/requirements-traceability.md` when requirement status or verification evidence changes.
- Add decision-log records for architecture, scope, safety, or user-behavior changes.
- Add known issues for unresolved blockers or conflicts.

## Prohibited Actions

Agents must never:

- Delete Stitch reference files.
- Replace the Flutter interface with a WebView.
- Introduce Firebase.
- Introduce cloud inference.
- Add authentication.
- Upload camera frames.
- Log image data.
- Claim exact object distance without a valid distance sensor.
- Claim generic person detection is face recognition.
- Mark a feature complete without verifying it.
- Bypass failing tests by deleting them.
- Hide build failures.
- Change architecture without recording the decision.
- Store secrets in source code or documentation.
- Implement functionality outside the current module without a justified dependency.

## Definition of Done

A module is done only when:

- Its scope is implemented or documented as blocked.
- Required tests pass, or exact environment blockers are recorded.
- Static analysis has no unresolved errors.
- Documentation reflects the real source state.
- Known issues and handoff are updated.
- Stitch sources remain preserved.

## Required Final-Response Format

When completing a module, report:

1. Module result.
2. Workspace state before implementation.
3. Architecture selected.
4. State-management approach selected.
5. Routing approach selected.
6. Folder structure created.
7. Screens created.
8. Domain types created.
9. Tests created.
10. Markdown files created.
11. Markdown files updated.
12. Requirement IDs addressed.
13. Commands executed.
14. Exact command results.
15. Android build result.
16. Files added.
17. Files modified.
18. Files deliberately left unchanged.
19. Stitch files verified as preserved.
20. Known issues.
21. Deferred work.
22. Exact next action.
23. Git-style summary.
