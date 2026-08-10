# Implementation Plan

Last reviewed: 2026-08-06

This implementation plan records the accepted sequence. Modules 6–14 have now
been implemented, including the real bundled YOLOv8n Mobile Mode pipeline.
Module 14 remains in physical-device acceptance; do not begin Module 15 until
that acceptance is complete and the owner explicitly requests Pi work.

## Module Sequence

| Module | Depends On | Deliverable | Acceptance Criteria | Testing Requirement | FYP Documentation Artifact |
|---|---|---|---|---|---|
| Module 1: Specification and workspace audit | Existing Stitch workspace | `mobile_app/` Flutter shell and baseline docs | Workspace audited, requirements identified, architecture documented, Stitch screens mapped, validation recorded | Format, analyze, test, Android build attempt | Baseline, traceability, architecture, UI map, implementation plan, decision log, workspace audit |
| Module 2: Flutter engineering foundation | Module 1 | Feature-first source structure, routing, state/DI convention, placeholder flow, tests, tracking docs | Placeholder routes reachable; no camera/AI/cloud/final UI migration; docs updated | Route, domain, accessibility, text-scale widget tests; Android build attempt | Tracking system, updated architecture, traceability, decisions, status, handoff |
| Module 3: Stitch design analysis and design-token extraction | Module 2 | Design-token catalog, asset inventory, component inventory, state matrix, accessibility plan, rendered references, and Flutter token tests | Stitch tokens and asset gaps documented without overwriting Stitch sources; token tests pass | Documentation review, asset-path audit, theme-token unit tests | Design system, Stitch audit, accessibility plan, asset inventory |
| Module 4: Accessible Flutter UI migration | Module 3 | Native Flutter versions of all ten Stitch references | Screens match design intent, support TalkBack-oriented semantics, use centralized tokens, and use no WebView | Widget, accessibility, responsive layout tests | UI migration evidence |
| Module 5: Navigation, accessibility hardening, and application-state completion | Module 4 | Complete non-camera navigation/state polish and manual accessibility preparation | Mode/start/stop shell states behave predictably; TalkBack checklist is ready for device validation | Widget, state, and accessibility review tests | App-state and accessibility hardening note |
| Module 6: Android permissions and application lifecycle | Module 5 | Permission and lifecycle foundation | Permission states are recoverable and accessible | Android integration/manual tests | Permission flow documentation |
| Module 7: Local settings persistence | Module 6 | Local settings repository | Preferences persist locally | Persistence tests | Settings storage note |
| Module 8: Mobile camera pipeline | Module 7 | Camera stream lifecycle | Camera starts/stops safely | Device integration tests | Camera pipeline note |
| Module 9: AI model preparation and validation | Module 8 | Local model and labels selected | Model is packaged locally and documented | Model validation tests | Model selection report |
| Module 10: On-device model inference | Module 9 | Inference adapter | Inference runs offline | Unit/device tests | Inference integration note |
| Module 11: Detection post-processing | Module 10 | Detection result mapping | Model output parses into domain detections | Fixture tests | Post-processing note |
| Module 12: Obstacle-risk assessment | Module 11 | Estimated risk service | Risk categories avoid exact distance claims | Unit tests | Risk assessment rationale |
| Module 13: Audio and vibration feedback | Module 12 | Offline speech and bounded haptics | Alerts respect feedback settings and cooldowns | Device tests | Feedback pattern catalog |
| Module 14: Complete Mobile Mode | Module 13 | Integrated Mobile Mode MVP | Offline camera-to-alert workflow works | End-to-end demo tests | Mobile Mode report |
| Module 15: Raspberry Pi software | Module 14 | Pi-side prototype | Wearable input source works locally | Pi tests | Pi software note |
| Module 16: Raspberry Pi communication | Module 15 | Local app-to-Pi connection | Connect/loss/retry states work without cloud | Integration tests | Pi communication note |
| Module 17: Runtime error handling and recovery | Module 14 | Hardened error flows | Failures are recoverable and accessible | Fault-injection tests | Error recovery report |
| Module 18: Performance optimization | Module 17 | Latency, battery, and stability tuning | Demo device meets measured targets | Profiling and long-run tests | Performance report |
| Module 19: Accessibility validation | Module 18 | TalkBack and low-vision validation | Manual accessibility checklist passes | Manual and widget tests | Accessibility validation report |
| Module 20: Automated system testing | Module 19 | Broader regression suite | System tests documented and repeatable | Automated regression tests | System test report |
| Module 21: FYP evaluation and experiments | Module 20 | Academic evaluation evidence | Experiments are recorded with limitations | Evaluation protocol | FYP evaluation report |
| Module 22: Final technical documentation | Module 21 | Submission-ready docs | Docs match implemented behavior | Documentation review | Final technical report |
| Module 23: Release, APK, demonstration and presentation | Module 22 | APK and demo package | Demo is verified on target device | Release validation | Demo checklist and presentation support |

## Dependencies Between Modules

- Module 2 establishes the project structure that all later modules use.
- Module 3 extracted Stitch design tokens before final UI migration.
- Module 4 must complete accessible Flutter screens before advanced application-state flows.
- Module 6 must complete permission and lifecycle handling before camera streaming.
- Module 8 must provide camera frames before model integration.
- Module 10 must produce inference output before post-processing and risk assessment.
- Module 14 must stabilize Mobile Mode before Raspberry Pi implementation begins.

## Engineering Rules For All Modules

- Preserve Stitch files.
- Do not embed Stitch HTML in WebView.
- Do not add cloud services, Firebase, analytics, authentication, or upload flows.
- Keep platform and infrastructure logic outside Flutter screen widgets.
- Add dependencies only when the module needs them.
- Keep TalkBack and offline behavior in scope from the first implementation of each feature.
- Update traceability when a requirement changes status.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| No physical Android phone | Real camera, feedback, TalkBack, offline, and performance acceptance cannot complete | Connect and authorize a physical ARM64 phone; emulator smoke evidence is already recorded. |
| Full NDK missing | Clean/release build is not reproducible | Install official NDK 28.2.13676358 and remove the debug-only workaround. |
| Module scope drift | Later modules start too early | Use `docs/CURRENT_MODULE.md` and `docs/ROADMAP.md`. |
| Remote Stitch assets | Offline production conflicts | Module 3 asset plan must replace remote references. |
| Emulator evidence mistaken for real-camera acceptance | False completion claims | Keep the physical test matrix open and record observed phone results only. |
| Riverpod misuse | Global state becomes hard to test | Keep providers focused and documented. |

## Rollback Strategy

- Keep Module 2 foundation changes separated from future camera/AI work.
- If a dependency introduces unwanted platform or network behavior, remove it before proceeding.
- If a route or provider structure becomes too broad, simplify while preserving route names and tests.
- If Android build remains blocked by environment, keep analysis and tests green and document the blocker.

## Recommended Next Work

Remain in Module 14. Connect a physical ARM64 Android phone and execute the
manual matrix in `docs/TESTING.md`: permission, camera/box alignment, real
detections, feedback, airplane mode, lifecycle/rapid cycling, performance, and
TalkBack. Update living docs with measured results. Pi Modules 15–16 stay
deferred.
