# Documentation Index

## GitHub project and APK delivery — 2026-10-29

[Delivery verification, commands, checksum and release links](GITHUB_DELIVERY_2026-10-29.md).
Current source branch and updated 1.4.19 ARM64 release-mode APK.

## Complete project guide for GPT and viva — 2026-10-22

[Self-contained Markdown guide](../deliverables/AI_Blind_Assistant_Complete_GPT_Guide.md)
and [Word copy](../deliverables/AI_Blind_Assistant_Complete_GPT_Guide.docx): 35
sections covering stack, architecture, all processing paths, safety/privacy,
dated results, setup, demo scripts, 32 viva answers and genuine proposed training.
Supersedes older unsupported completed fine-tuning wording. [Document checks](GPT_GUIDE_VERIFICATION_2026-10-22.md).

## Reflashed Pi restoration and Pixel pairing — 2026-10-22

[Module 76 deployment and verification](PIXEL_PI_RESTORE_2026-10-22.md): actual
Pi/runtime/model restoration, secure local enrollment, Running/camera/model
evidence, 38 Pi tests, owner-confirmed object audio and remaining power checks.

## Vision AI demo reliability — 2026-10-21

[Module 75 verification and rehearsal](VISION_AI_RELIABILITY_2026-10-21.md):
truthful listening recovery, local ready cue, safe phrase handling, 673 Flutter/
25 native tests, Android artifact/device evidence and the 2026-10-22 demo script.

Last reviewed: 2026-10-22



## Fresh-phone Smart AI circle consistency — 2026-10-21

- [Module 74 verification](SMART_AI_FRESH_PHONE_2026-10-21.md) — same-APK configuration diagnosis, setup-gated circle, 1.4.17 build/device evidence.

## Latest local-command verification — 2026-10-21

- [Vision AI spoken results and screen commands, Module 73](VISION_AI_COMMANDS_2026-10-21.md) — 1.4.16; exact checks, artifact, deployment and physical next steps.

## Smart AI listening vibration and chime — 2026-10-21

[Module 72 verification](SMART_AI_READY_CUE_2026-10-21.md): microphone-ready
accessibility pulse plus local chime, bounded cancellation/cleanup, labelled
local test, 615 Flutter/21 native passes and APK delivery for later physical
acceptance. ADR-073 records the isolated Smart AI feedback decision.

## Smart AI bilingual circle — 2026-10-20

[Module 71 verification](SMART_AI_CIRCLE_2026-10-20.md): per-turn English/Urdu,
hold/vibration/release, local pause/resume/interrupt, exact goodbye → Home,
accessible alternatives, 591 tests, 1.4.13 build/installation and physical gate.
Vision AI/native/backend/Pi/Stitch remain unchanged. ADR-072 records the behavior.

## Smart AI-only Groq/AgentRouter audio — 2026-10-19

[Module 70 verification/setup](SMART_AI_CLOUD_AUDIO_2026-10-19.md): isolated
foreground speech pipeline, personal-key consent, exact provider/model/prompt,
571 Flutter/prior 13 native tests, approved Groq speech/answers, isolated offline
Urdu reply selection/replay, 1.4.12 builds/installation and physical gates. Vision AI/recognizers/backend/Pi hashes remain
unchanged; one existing native recorder method resolves Smart AI private cache.

## Phone hotspot and laptop-free Gemini — 2026-10-19

[Module 69 verification](HOTSPOT_AND_GEMINI_VERIFICATION_2026-10-19.md):
physical phone/Pi deployment, direct text-only personal Gemini, current tests,
Android packaging, exact acceptance results and remaining gates.

## Latest Smart AI speech verification

[Smart AI speech — 2026-10-16](SMART_AI_SPEECH_VERIFICATION_2026-10-16.md):
Module 68, local medium Whisper, owner-approved laptop speech disclosure/deletion,
128 backend/466 Flutter tests, earlier 13 native app passes, Android packaging,
synthetic results and remaining physical acceptance. Hands-free remains Vosk.

## Demo video

[2:50 narrated project demonstration](../deliverables/demo/AI_Blind_Assistant_Demo.mp4)
and [delivery/verification notes](../deliverables/demo/README.md): native app
captures, synthetic camera/OCR, reader, local command result, optional connection
workflows, captions and automatic coloured hover borders. Export verified
15 October 2026; emulator TTS and physical acceptance limits remain explicit.

## Latest reader voice verification

[Reader interruption and echo protection — 2026-10-15](READER_VOICE_VERIFICATION_2026-10-15.md):
Module 67, 459 Flutter and 13 native app tests, debug/release builds, release
1.4.4 and remaining physical overlapping-speech acceptance. The subsequent
[rescan framing follow-up](READER_VOICE_VERIFICATION_2026-10-15.md#rescan-framing-follow-up)
returns restart/rescan to positioning and waits for explicit capture; 459
Flutter passes and signed release 1.4.5 installed/launch verified on the phone.

## Latest voice and Smart AI verification

[Scanner, Smart AI connection and session-exit repairs — 2026-10-15](VOICE_FIXES_2026-10-15.md):
Module 66, 404 Flutter / 108 backend / 9 native app passes, debug/release builds,
emulator release 1.4.3 deployment and remaining physical acceptance.

## Presentation preparation

[Complete project and presentation brief](PROJECT_PRESENTATION_BRIEF.md) and
[editable Word copy](../deliverables/AI_Blind_Assistant_Presentation_Brief.docx):
concept, functionality inventory, architecture, workflows, scope, owner-reported
Open Images V7 household integration, dated evidence, a 22-slide outline,
demo plan and viva answers. Prepared 2026-10-12; physical/training-result gaps are
explicit, and no software acceptance status is promoted. Use the 22 October guide
above for current claims; the older Word export has not been regenerated.

## Latest wearable verification

[Hotspot and phone speech verification — 2026-10-09](HOTSPOT_VERIFICATION_2026-10-09.md):
Module 65 session/audio repairs, 393 Flutter + 33 Pi passes, Android builds,
emulator launch, exact command outcomes and open physical acceptance gates.

## Latest audit

[Whole-project audit — 2026-10-09](PROJECT_AUDIT_2026-10-09.md): verified repairs,
exact command outcomes, coverage, build artifacts and remaining acceptance gates.

## Current project maps

| Document | Purpose | Status | Link |
|---|---|---|---|
| Project Graph | Mermaid graph of implemented components and phone/Pi flow. | Current; physical Pi gate open | [PROJECT_GRAPH.md](PROJECT_GRAPH.md) |
| Phone Hotspot | Researched owner-phone hotspot design, setup, fallbacks, and acceptance. | Current; physical Pi gate open | [PHONE_HOTSPOT.md](PHONE_HOTSPOT.md) |

## Project Governance

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Agent Guide | Required instructions for future agents. | Living | Module 2 | 2026-07-19 | Implemented | [AGENTS.md](../AGENTS.md) |
| Project Status | Authoritative overview of actual implementation state. | Living | Module 65 | 2026-10-09 | Hotspot/audio software verified; physical and native gates open | [PROJECT_STATUS.md](PROJECT_STATUS.md) |
| Current Module | Active module scope, checklist, and evidence. | Living | Module 65 | 2026-10-09 | Hotspot/audio software verified; physical gates open | [CURRENT_MODULE.md](CURRENT_MODULE.md) |
| Agent Handoff | Exact continuation notes for the next agent. | Living | Module 65 | 2026-10-09 | Updated | [AGENT_HANDOFF.md](AGENT_HANDOFF.md) |
| Known Issues | Defects, blockers, conflicts, and environment issues. | Living | Module 65 | 2026-10-09 | Updated | [KNOWN_ISSUES.md](KNOWN_ISSUES.md) |
| Changelog | Chronological record of completed work sessions. | Living | Module 65 | 2026-10-09 | Updated | [CHANGELOG.md](CHANGELOG.md) |

## Requirements

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Specification Baseline | Frozen scope, terminology, constraints, and safety boundaries. | Stable | Module 1 | 2026-07-19 | Verified | [specification-baseline.md](specification-baseline.md) |
| Requirements Traceability | Requirement IDs, implementation evidence, status, and physical checks. | Living | Module 1 onward | 2026-08-20 | Implemented | [requirements-traceability.md](requirements-traceability.md) |

## Architecture

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Architecture | Layering, route, DI, state, domain, infrastructure, accessibility, and privacy design. | Living | Module 1 onward | 2026-08-20 | Implemented through Module 57 | [architecture.md](architecture.md) |
| Offline Vision Assistant Guide | Complete architecture, Vosk ASR, AEC/DSP, and voice command matrix for 100% on-device assistant. | Living | Module 55 | 2026-08-20 | Implemented | [OFFLINE_VISION_ASSISTANT_GUIDE.md](OFFLINE_VISION_ASSISTANT_GUIDE.md) |
| Document Scanner Guide | On-device ML Kit OCR, accessible reader controls, voice actions, and consented assistant draft. | Living | Module 62 | 2026-10-03 | Software verified; physical acceptance open | [DOCUMENT_SCANNER_GUIDE.md](DOCUMENT_SCANNER_GUIDE.md) |
| Decision Log | Accepted architecture, scope, safety, and governance decisions. | Living | Module 1 onward | 2026-08-20 | Implemented | [decision-log.md](decision-log.md) |
| Assistant Architecture and Operation | Voice flow, commands, provider fallback, privacy, setup, and acceptance. | Living | Module 25 | 2026-08-14 | Implemented with physical gates open | [assistant.md](assistant.md) |

## UI Design

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| UI Migration Map | Stitch-to-Flutter screen mapping, implementation status, and accessibility notes. | Living | Module 1 onward | 2026-08-14 | Implemented | [ui-migration-map.md](ui-migration-map.md) |
| Stitch Source Audit | Detailed HTML/CSS/JS/source/render audit for Stitch references. | Stable | Module 3 | 2026-07-19 | Implemented | [stitch-source-audit.md](stitch-source-audit.md) |
| Design System | Extracted design tokens and Flutter theme mapping. | Living | Module 3 onward | 2026-08-14 | Implemented | [design-system.md](design-system.md) |
| Component Inventory | Implemented reusable Flutter UI components and remaining physical states. | Living | Module 3 onward | 2026-08-14 | Implemented | [component-inventory.md](component-inventory.md) |
| Interaction Spec | Implemented Mobile, Wearable, feedback, error, and recovery interactions. | Living | Module 3 onward | 2026-08-20 | Implemented | [interaction-spec.md](interaction-spec.md) |
| Responsive Layout Spec | Android viewport, text-scale, and adaptive-layout migration rules. | Living | Module 3 onward | 2026-07-19 | Implemented | [responsive-layout-spec.md](responsive-layout-spec.md) |
| UI Accessibility Plan | TalkBack labels, focus order, issues, and manual test plan. | Living | Module 3 onward | 2026-08-14 | Implemented | [ui-accessibility-plan.md](ui-accessibility-plan.md) |
| Screen State Matrix | Default, loading, empty, error, and dynamic states per screen. | Living | Module 3 onward | 2026-08-14 | Implemented | [screen-state-matrix.md](screen-state-matrix.md) |
| Asset Inventory | Local, model, rendered, remote, missing, font, and icon asset audit. | Living | Module 3 onward | 2026-08-06 | Implemented | [asset-inventory.md](asset-inventory.md) |

## Development

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Implementation Plan | Sequenced module implementation plan and rollback approach. | Living | Module 1 onward | 2026-08-06 | Implemented | [implementation-plan.md](implementation-plan.md) |
| Roadmap | Full module roadmap with entry and exit criteria. | Living | Module 2 | 2026-08-06 | Implemented | [ROADMAP.md](ROADMAP.md) |
| Build and Run | Setup, assistant backend, Android commands, signing, packaging, and troubleshooting. | Living | Module 25 onward | 2026-08-20 | Implemented | [BUILD_AND_RUN.md](BUILD_AND_RUN.md) |
| Professional Audit | Research sources, whole-app findings, corrections, release evidence, and residual gates. | Stable | Module 24 | 2026-08-14 | Verified | [professional-audit-2026-08-14.md](professional-audit-2026-08-14.md) |
| YOLOv8n LiteRT Integration | Final model provenance, export, tensor, preprocessing, lifecycle, feedback, and replacement record. | Living | Module 14 | 2026-08-06 | Implemented | [model-integration.md](model-integration.md) |
| Detection Pipeline | Implemented camera-to-YOLO processing and coordinate mapping. | Living | Module 14 | 2026-08-06 | Implemented | [detection-pipeline.md](detection-pipeline.md) |
| Alert Engine | Relative risk, suppression, speech, and bounded haptic behavior. | Living | Module 14 | 2026-08-06 | Implemented | [alert-engine.md](alert-engine.md) |
| Workspace Audit | Module 1 workspace and environment audit. | Stable | Module 1 | 2026-07-19 | Verified | [workspace-audit.md](workspace-audit.md) |

## Testing

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Testing Strategy | Automated evidence, provider evidence, and physical-device acceptance matrix. | Living | Module 25 onward | 2026-08-20 | Implemented | [TESTING.md](TESTING.md) |

## Evaluation

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| FYP Evaluation Plan | Evaluation metrics, experiments, and demo evidence. | Living | Module 21 | 2026-07-19 | Not Started | Not created yet |
| Model Evaluation | Final model decision, tensor contract, parity evidence, and limitations. | Living | Module 14 | 2026-08-06 | Implemented | [model-evaluation.md](model-evaluation.md) |

## Raspberry Pi

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Raspberry Pi Wearable Mode | Implemented architecture, code-free enrollment, NCNN contract, phone-audio ownership, installation, operation, troubleshooting, and acceptance. | Living | Module 57 | 2026-08-20 | Verified in simulation; physical LAN blocked | [wearable-mode.md](wearable-mode.md) |
| Wearable Protocol v1 | Typed WebSocket envelope, exclusive enrollment, authentication, settings conflicts, feedback target, and reliability boundary. | Living | Module 57 | 2026-08-20 | Verified cross-stack in simulation | [wearable-protocol.md](wearable-protocol.md) |

## Release and Demonstration

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Release Checklist | Signed APK, assistant, install, phone, Pi, key-preservation, and final verification checklist. | Living | Module 25 onward | 2026-08-20 | Implemented with physical gates open | [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) |
