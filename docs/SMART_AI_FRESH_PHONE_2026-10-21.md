# Smart AI circle consistency on a fresh phone

Date: 2026-10-21. Module 74 / ADR-075. Software/build/installation verified; owner confirms the Pixel circle/setup UI.

## Cause and resulting behavior

The owner reports that version 1.4.16 differs between TECNO and Pixel. A fresh
read of the Pixel package confirms 1.4.16/code 4056 and SHA-256
`1bc10e550d14a475ac69a48f2b323573a43c085d36d2ac23ee110f1f05d7fda3`, exactly
matching the delivered/TECNO artifact. This is configuration-dependent UI, not
an older or different binary. AssistantScreen previously rendered the circle only
when cloud keys existed; the fresh Pixel fell back to the unpaired legacy view.

Fresh phones now open the existing circle with Set up Smart AI, accurate local
setup disclosure, accessible disabled-recording label and personal key/consent
workflow. Local Vision AI commands, setup speech and vibration/chime test work
before cloud setup. No cloud client or Smart AI recorder is initialized without
configuration; start/hold/send retain controller gates. Local guide pause/resume
remains available through the circle and named controls. Existing configured
circle layout, models, language, recording and provider policies remain.

Wait for bounded local saved-mode restore before selecting the view. Preserve
already configured personal Gemini/laptop modes; fresh users can explicitly open
Use Gemini or laptop assistant. No provider migration, copied keys or inferred
consent. Returning from setup and removing keys keeps the circle for fresh users,
preserving unsent drafts. Key-removal copy now describes the actual disabled
cloud setup. Widgets invoke existing controllers and initialize no hardware.
Riverpod, feature-first layers and central routes remain. No new folders,
screens, domain types, dependencies, native/kernel/Vision AI/backend/Pi/model or
signing/version-source changes. Snapshot before edits:
`/tmp/aiba-pixel-smart-ai-before-20261021.json` (575 files). Dirty user work stays.

## Verification

Commands ran in mobile_app unless stated otherwise.

| Command/check | Actual result |
|---|---|
| `dart format --output=none --set-exit-if-changed <9 changed Dart files>` from root | Exit 0; 9 files, 0 changed, 0.06 s |
| `flutter --no-version-check analyze --no-pub` | Exit 0; No issues found, 2.8 s |
| Focused assistant/controller/cloud/router/module4 tests, `flutter --no-version-check test --no-pub ... -r expanded` | Exit 0; **89 passed**, 2 s |
| `AIBA_PI_PYTHON=/Users/mm/AI_BLIND_ASSISTANT/raspberry_pi/.venv/bin/python flutter --no-version-check test --no-pub --concurrency=4 -r expanded` | Exit 0; **652 passed**, 0 failed/skipped, 19 s; actual Python Pi simulator, 6 more than 646 |
| `flutter --no-version-check build apk --debug --target-platform android-arm64 --split-per-abi --build-name=1.4.17 --build-number=2057` | Exit 0; assembleDebug **9.8 s**, ARM64 debug APK |
| Same flags with `--release` | Exit 0; assembleRelease **24.2 s**, ARM64 release APK; dependency/plugin preparation ran without --no-pub |
| SDK 36 `apksigner sign/verify --verbose --print-certs`, `zipalign -c -P 16 4`, `aapt dump badging`, AOT string inspection | Exit 0; signature matches installed Pixel predecessor; alignment passes; 1.4.17/code 4057, DEBUGGABLE absent; new setup/circle/alternative labels packaged |
| Targeted `adb install --no-incremental -r deliverables/AI-Blind-Assistant-1.4.17-smart-ai-circle-setup.apk` | Exit 0; Performing Streamed Install; Success |
| Installed base-APK SHA-256 and package metadata | Hash matches delivery below; 1.4.17/code 4057, DEBUGGABLE absent; firstInstallTime **2026-10-21 14:30:57** preserved, lastUpdateTime **2026-10-21 14:53:38** |
| Targeted `adb shell am start -S -W -n com.example.ai_blind_assistant/.MainActivity` | Exit 0; Status ok/COLD, MainActivity, TotalTime **217 ms**, WaitTime **220 ms** |
| Post-launch current-PID/window check | App process alive, zero Java/native fatal markers; phone later locked/NotificationShade, so agent could not inspect foreground controls then |
| Owner check after unlock/open Smart AI | **Confirms large circle and Set up Smart AI button appear** |
| `git diff --check` and pre-request hash preservation | Exit 0; no baseline removal, all 31 Stitch/58 native/7 kernel/78 backend+Pi references unchanged |

The initial test invocation from the workspace root reported no pubspec; rerun
in mobile_app. Initial focused tests: 75 pass/4 router failures exposed the router
fixture's unmocked native credential restore and pending three-second timer.
Router/large-text harnesses now inject deterministic empty credential repositories
and fake local audio, preserving all assertions. Legacy unpaired screen assertions
now enter that explicitly selected mode; paired restoration tests remain. The new
fresh-phone routing expectation verifies the circle/setup action. One analyzer
brace finding was corrected. No tests were removed, skipped or disabled.

New coverage: fresh circle/disabled capture, no false enabled-cloud message,
local-only activation with throwing recorder/client providers, no uploads on
start/hold/send before consent, local guide/cue test, accessible setup callback,
360 px/2x text, setup-save-return and key-removal-return with unsent draft intact,
and saved Gemini preservation without laptop checks. Existing configured, paired,
recording, language, privacy, navigation and Pi regressions remain.

Native code is unchanged. The prior 22 app-native tests from Module 73 are
historical evidence, not a new native rerun. No paid Groq/AgentRouter request,
phone recording, credential copy, screenshot of keys, uninstall/data clear,
commit or push. The owner confirms the circle and setup button on the Pixel after installation.
This closes the reported UI mismatch. Local speech/cue/recognition and cloud
question acceptance remain separate; no broad acceptance is inferred from that
visual confirmation. Existing Kotlin plugin migration warnings remain; builds
succeed. No native unit task or dependency upgrade was added.

## Requirements and next action

FR-001/013/014/019/022; NFR-ACC-001/002, NFR-SEC-002/003, NFR-REL-001 and
NFR-MAINT-002. The verified update is installed and the owner accepts the Pixel circle/setup
view. Exact next action: tap Set up Smart AI and save the personal Groq key with
the existing provider-specific consent to enable questions on this phone. Local
commands/guide/cue test are already available. Keys/consent and Pi trust remain
per device. Preserve ISSUE-082/083 speech/haptic/voice gates and the independent
Pi power limitation; no paid test is required for local UI/cue acceptance.

## Artifact and file inventory

[Installed Pixel APK](../deliverables/AI-Blind-Assistant-1.4.17-smart-ai-circle-setup.apk)
uses the existing Pixel predecessor's development certificate for an in-place
release-mode update. Source signing configuration and version files are unchanged.
The project-signed release remains in Flutter build output.

| Artifact | Bytes | SHA-256 |
|---|---:|---|

| Delivered/installed phone APK | 126,355,367 | `f59868945b8f4a2566611a8778d1698a75574ddd9a389d2281d50dd03d5a0248` |
| Project-signed Flutter release | 126,310,220 | `86faec4de6928e1a7ee110535c982c39f96cd0842427cd4e581a51e3b5c20d7e` |

Relative to the 575-file request baseline: **22 modified files, 1 added report,
0 removed**. The ignored delivery APK is an additional artifact.

### Added

- `docs/SMART_AI_FRESH_PHONE_2026-10-21.md`

### Modified

- `deliverables/README.md`
- `docs/AGENT_HANDOFF.md`
- `docs/CHANGELOG.md`
- `docs/CURRENT_MODULE.md`
- `docs/INDEX.md`
- `docs/KNOWN_ISSUES.md`
- `docs/PROJECT_STATUS.md`
- `docs/TESTING.md`
- `docs/architecture.md`
- `docs/assistant.md`
- `docs/decision-log.md`
- `docs/requirements-traceability.md`
- `docs/specification-baseline.md`
- `mobile_app/lib/app/smart_ai_cloud_controller.dart`
- `mobile_app/lib/features/assistant/presentation/assistant_screen.dart`
- `mobile_app/lib/features/assistant/presentation/smart_ai_cloud_connection_card.dart`
- `mobile_app/lib/features/assistant/presentation/smart_ai_cloud_screen.dart`
- `mobile_app/test/app/module4_ui_migration_test.dart`
- `mobile_app/test/app/router_test.dart`
- `mobile_app/test/features/assistant/assistant_screen_test.dart`
- `mobile_app/test/features/assistant/smart_ai_cloud_controller_test.dart`
- `mobile_app/test/features/assistant/smart_ai_cloud_screen_test.dart`

## Module checklist

1. Result: fresh-phone circle restored; installed Pixel 1.4.17 and owner UI acceptance.
2. Workspace before work: already dirty; 575-file snapshot, no user work reverted.
3. Architecture: existing feature-first layers/controllers retained.
4. State management: existing Riverpod with presentation-only mode state.
5. Routing: existing centralized routes; explicit legacy alternative.
6. Folders created: none.
7. Screens created: none; existing assistant/circle/setup views updated.
8. Domain types created: none.
9. Tests: 6 new Flutter cases; 652 full and 89 focused pass, existing assertions retained.
10. Markdown created: this report.
11. Markdown updated: status/handoff/testing/index/specification/ADR/architecture/assistant/requirements/changelog/issues/delivery README (inventory above).
12. Requirement IDs: FR-001/013/014/019/022 and accessibility/privacy/reliability/maintainability IDs above.
13. Commands: format/analyze/focused/full tests/debug/release/sign/verify/alignment/install/launch/hash/diff; exact results above.
14. Results: 652 Flutter pass; clean analysis, nine-file format check; no new native rerun.
15. Android: debug/release pass, verified signed/aligned non-debuggable APK installed, cold launch succeeds.
16. Added: report and ignored APK artifact, no source file added.
17. Modified: 22 files, exact inventory above.
18. Deliberately unchanged: Vision AI/kernel/native/backend/Pi/models/assets/dependencies/signing/version source/AGENTS and all prior artifacts.
19. Stitch: all 31 reference hashes match baseline.
20. Known issues: UI mismatch ISSUE-084 resolved/owner accepted; earlier physical voice/haptic/Pi power gates remain.
21. Deferred: personal-key cloud setup/actual new-phone conversations and separate physical audio/TalkBack/recognition checks.
22. Next action: personal Smart AI setup with existing disclosure/consent on Pixel; use local controls/cue without provider probes.
23. Git-style summary: `fix(smart-ai): retain the circle before personal setup`; no commit/push.
