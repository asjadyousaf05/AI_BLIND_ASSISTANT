# Documentation Index

Last reviewed: 2026-08-14

## Project Governance

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Agent Guide | Required instructions for future agents. | Living | Module 2 | 2026-07-19 | Implemented | [AGENTS.md](../AGENTS.md) |
| Project Status | Authoritative overview of actual implementation state. | Living | Module 25 | 2026-08-14 | Implemented | [PROJECT_STATUS.md](PROJECT_STATUS.md) |
| Current Module | Active module scope, checklist, and evidence. | Living | Module 25 | 2026-08-14 | Implemented | [CURRENT_MODULE.md](CURRENT_MODULE.md) |
| Agent Handoff | Exact continuation notes for the next agent. | Living | Module 25 | 2026-08-14 | Implemented | [AGENT_HANDOFF.md](AGENT_HANDOFF.md) |
| Known Issues | Defects, blockers, conflicts, and environment issues. | Living | Module 25 | 2026-08-14 | Implemented | [KNOWN_ISSUES.md](KNOWN_ISSUES.md) |
| Changelog | Chronological record of completed work sessions. | Living | Module 25 | 2026-08-14 | Implemented | [CHANGELOG.md](CHANGELOG.md) |

## Requirements

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Specification Baseline | Frozen scope, terminology, constraints, and safety boundaries. | Stable | Module 1 | 2026-07-19 | Verified | [specification-baseline.md](specification-baseline.md) |
| Requirements Traceability | Requirement IDs, implementation evidence, status, and physical checks. | Living | Module 1 onward | 2026-08-14 | Implemented | [requirements-traceability.md](requirements-traceability.md) |

## Architecture

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Architecture | Layering, route, DI, state, domain, infrastructure, accessibility, and privacy design. | Living | Module 1 onward | 2026-08-14 | Implemented | [architecture.md](architecture.md) |
| Offline Vision Assistant Guide | Complete architecture, Vosk ASR, AEC/DSP, and voice command matrix for 100% on-device assistant. | Living | Module 25 | 2026-08-17 | Implemented | [OFFLINE_VISION_ASSISTANT_GUIDE.md](OFFLINE_VISION_ASSISTANT_GUIDE.md) |
| Document Scanner Guide | End-to-end guide on on-device ML Kit OCR, NLP sentence engine, and accessible karaoke reader. | Living | Module 25 | 2026-08-17 | Implemented | [DOCUMENT_SCANNER_GUIDE.md](DOCUMENT_SCANNER_GUIDE.md) |
| Decision Log | Accepted architecture, scope, safety, and governance decisions. | Living | Module 1 onward | 2026-08-14 | Implemented | [decision-log.md](decision-log.md) |
| Assistant Architecture and Operation | Voice flow, commands, provider fallback, privacy, setup, and acceptance. | Living | Module 25 | 2026-08-14 | Implemented with physical gates open | [assistant.md](assistant.md) |

## UI Design

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| UI Migration Map | Stitch-to-Flutter screen mapping, implementation status, and accessibility notes. | Living | Module 1 onward | 2026-08-14 | Implemented | [ui-migration-map.md](ui-migration-map.md) |
| Stitch Source Audit | Detailed HTML/CSS/JS/source/render audit for Stitch references. | Stable | Module 3 | 2026-07-19 | Implemented | [stitch-source-audit.md](stitch-source-audit.md) |
| Design System | Extracted design tokens and Flutter theme mapping. | Living | Module 3 onward | 2026-08-14 | Implemented | [design-system.md](design-system.md) |
| Component Inventory | Implemented reusable Flutter UI components and remaining physical states. | Living | Module 3 onward | 2026-08-14 | Implemented | [component-inventory.md](component-inventory.md) |
| Interaction Spec | Implemented Mobile, Wearable, feedback, error, and recovery interactions. | Living | Module 3 onward | 2026-08-14 | Implemented | [interaction-spec.md](interaction-spec.md) |
| Responsive Layout Spec | Android viewport, text-scale, and adaptive-layout migration rules. | Living | Module 3 onward | 2026-07-19 | Implemented | [responsive-layout-spec.md](responsive-layout-spec.md) |
| UI Accessibility Plan | TalkBack labels, focus order, issues, and manual test plan. | Living | Module 3 onward | 2026-08-14 | Implemented | [ui-accessibility-plan.md](ui-accessibility-plan.md) |
| Screen State Matrix | Default, loading, empty, error, and dynamic states per screen. | Living | Module 3 onward | 2026-08-14 | Implemented | [screen-state-matrix.md](screen-state-matrix.md) |
| Asset Inventory | Local, model, rendered, remote, missing, font, and icon asset audit. | Living | Module 3 onward | 2026-08-06 | Implemented | [asset-inventory.md](asset-inventory.md) |

## Development

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Implementation Plan | Sequenced module implementation plan and rollback approach. | Living | Module 1 onward | 2026-08-06 | Implemented | [implementation-plan.md](implementation-plan.md) |
| Roadmap | Full module roadmap with entry and exit criteria. | Living | Module 2 | 2026-08-06 | Implemented | [ROADMAP.md](ROADMAP.md) |
| Build and Run | Setup, assistant backend, Android commands, signing, packaging, and troubleshooting. | Living | Module 25 | 2026-08-14 | Implemented | [BUILD_AND_RUN.md](BUILD_AND_RUN.md) |
| Professional Audit | Research sources, whole-app findings, corrections, release evidence, and residual gates. | Stable | Module 24 | 2026-08-14 | Verified | [professional-audit-2026-08-14.md](professional-audit-2026-08-14.md) |
| YOLOv8n LiteRT Integration | Final model provenance, export, tensor, preprocessing, lifecycle, feedback, and replacement record. | Living | Module 14 | 2026-08-06 | Implemented | [model-integration.md](model-integration.md) |
| Detection Pipeline | Implemented camera-to-YOLO processing and coordinate mapping. | Living | Module 14 | 2026-08-06 | Implemented | [detection-pipeline.md](detection-pipeline.md) |
| Alert Engine | Relative risk, suppression, speech, and bounded haptic behavior. | Living | Module 14 | 2026-08-06 | Implemented | [alert-engine.md](alert-engine.md) |
| Workspace Audit | Module 1 workspace and environment audit. | Stable | Module 1 | 2026-07-19 | Verified | [workspace-audit.md](workspace-audit.md) |

## Testing

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Testing Strategy | Automated evidence, provider evidence, and physical-device acceptance matrix. | Living | Module 25 | 2026-08-14 | Implemented | [TESTING.md](TESTING.md) |

## Evaluation

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| FYP Evaluation Plan | Evaluation metrics, experiments, and demo evidence. | Living | Module 21 | 2026-07-19 | Not Started | Not created yet |
| Model Evaluation | Final model decision, tensor contract, parity evidence, and limitations. | Living | Module 14 | 2026-08-06 | Implemented | [model-evaluation.md](model-evaluation.md) |

## Raspberry Pi

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Raspberry Pi Wearable Mode | Implemented architecture, NCNN contract, installation, operation, troubleshooting, and acceptance. | Living | Module 15 | 2026-08-09 | Implemented | [wearable-mode.md](wearable-mode.md) |
| Wearable Protocol v1 | Typed WebSocket envelope, messages, authentication, settings conflicts, and reliability boundary. | Living | Module 15 | 2026-08-09 | Verified in simulation | [wearable-protocol.md](wearable-protocol.md) |

## Release and Demonstration

| Document | Purpose | Classification | Responsible module | Last reviewed | Status | Link |
|---|---|---|---|---|---|---|
| Release Checklist | Signed APK, assistant, install, phone, Pi, key-preservation, and final verification checklist. | Living | Module 25 | 2026-08-14 | Implemented with physical gates open | [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) |
