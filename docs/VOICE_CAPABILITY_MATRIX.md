# Voice Capability Matrix (VisionVoiceKernelV2)

Last updated: 2026-08-17

## 1. Overview

This matrix maps every user-facing application function in **AI Blind Assistant / Vision AI** to its canonical [VoiceIntent](file:///Users/mm/AI_BLIND_ASSISTANT/mobile_app/lib/domain/enums/voice_intent.dart), supported phrases/variations, allowed [VoiceFeatureContext](file:///Users/mm/AI_BLIND_ASSISTANT/mobile_app/lib/domain/enums/voice_feature_context.dart), and confirmation/execution policies.

---

## 2. Emergency & Silence Actions

| Canonical Intent | Semantic Composition | Natural Phrase Variations | Allowed Contexts | Policy |
|---|---|---|---|---|
| `EmergencyStop` | `DEACTIVATE + ALL` | "stop everything", "emergency stop", "halt everything", "stop all" | ALL | Emergency: stops all detection, wearable, and audio immediately |
| `Silence` | `DEACTIVATE + AUDIO` | "stop speaking", "be quiet", "quiet", "silence", "shut up", "mute", "hush", "shh" | ALL | Emergency: silences active TTS/reading |

---

## 3. Mobile Detection Actions

| Canonical Intent | Semantic Composition | Natural Phrase Variations | Allowed Contexts | Policy |
|---|---|---|---|---|
| `StartMobileDetection` | `ACTIVATE + MOBILE_DETECTION` | "start mobile mode", "start detection", "start camera", "start seeing", "help me see", "detect objects", "run detection", "turn on detection", "start obstacle detection", "start assistance" | `home`, `mobileDetection`, `unknown` | Requires confirmation if launched from outside; starts camera + model pipeline |
| `StopMobileDetection` | `DEACTIVATE + MOBILE_DETECTION` | "stop mobile mode", "stop detection", "stop camera", "stop vision", "stop seeing", "turn off detection", "close detection", "exit detection", "kill detection", "disable detection", bare "stop" (in Mobile Detection) | `mobileDetection`, `home` | Stops pipeline, cleans up native camera/inference resources, navigates home |
| `PauseMobileDetection` | `PAUSE + MOBILE_DETECTION` | "pause detection", "pause camera", "pause vision", "pause mobile mode", "pause seeing", bare "pause" (in Mobile Detection) | `mobileDetection` | Releases native camera capture pipeline |
| `ResumeMobileDetection` | `RESUME + MOBILE_DETECTION` | "resume detection", "resume camera", "resume vision", "resume mobile mode", "resume seeing", bare "resume" (in Mobile Detection) | `mobileDetection` | Restarts camera capture pipeline |
| `GetMobileDetectionStatus` | `QUERY + MOBILE_DETECTION` | "detection status", "mobile mode status", "is detection running", "camera status" | ALL | Speaks current state label |
| `ReadRecentDetections` | `QUERY + DETECTIONS` | "what do you see", "what is nearby", "what's nearby", "recent detections", "detected objects", "what did you detect", "read recent detections" | `mobileDetection`, `home` | Speaks labels of top 5 detected objects |

---

## 4. Document Scanner & Accessible Reader Actions

| Canonical Intent | Semantic Composition | Natural Phrase Variations | Allowed Contexts | Policy |
|---|---|---|---|---|
| `ScanDocument` | `SCAN + SCANNER` | "scan document", "take photo", "read document", "read text", "capture document", "read page", "scan page", "capture", bare "scan" (in Scanner Capture) | `scannerCapture`, `scannerReading`, `home` | Triggers OCR capture & ML Kit text extraction |
| `RescanDocument` | `RESCAN + SCANNER` | "scan again", "scan another page", "rescan", "new scan", "try again" | `scannerCapture`, `scannerReading` | Resets OCR buffer, prepares camera for next page |
| `ReadDocumentAgain` | `READ_AGAIN + SCANNER` | "read again", "read text again", "read document again", "repeat text" | `scannerReading`, `scannerCapture` | Restarts sentence reading from beginning |
| `ReadingPause` | `PAUSE + READING` | "pause reading", "pause audio", "pause speech", "hold on", bare "pause" (in Scanner Reading) | `scannerReading` | Pauses TTS while preserving the current reading line |
| `ReadingResume` | `RESUME + READING` | "start reading", "begin reading", "read aloud", "resume reading", "continue reading", "keep reading", "play", "unpause", bare "resume" (in Scanner Reading) | `scannerReading` | Starts/resumes audible reading from the selected line; completed documents restart from line 1 |
| `ReadingNext` | `NEXT + SENTENCE` | "next", "next sentence", "next line", "read next", "skip line", "skip ahead", "forward" | `scannerReading` | Advances reader head to next sentence |
| `ReadingPrevious` | `PREVIOUS + SENTENCE` | "previous", "previous sentence", "previous line", "read previous", "rewind", "go back" | `scannerReading` | Reads from the previous reading line |
| `ReadingRepeat` | `REPEAT + SENTENCE` | "repeat", "repeat sentence", "repeat line", "say line again", "say again", "again", "one more time" | `scannerReading` | Repeats current sentence |
| `ReadingRestart` | `RESTART + READING` | "first line", "read first line", "restart", "start over", "read from beginning", "from the beginning", "from the top" | `scannerReading` | Reads from line 1 |
| `ReadingLast` | `LAST + READING` | "last line", "final line", "read last line", "go to the last line", "end of document", "bottom of document" | `scannerReading` | Reads the final reading line |
| `ReadingGoToLine` | `GOTO + LINE_NUMBER` | "line 5", "go to line five", "read sentence twenty one", "jump to the third line" | `scannerReading` | Reads from a one-based line target; native focused speech covers 1-100 and Dart accepts 1-999 |
| `ReadingSpell` | `SPELL + READING_LINE` | "spell", "spell out", "spell this line", "spell current line", "read letter by letter" | `scannerReading` | Spells the complete current reading line letter-by-letter |
| `SetReadingProfile` | `SET + READING_PROFILE` | "study mode", "learning mode", "slow down", "fast mode", "skim mode", "speed up", "normal speed", "normal mode" | `scannerReading` | Adjusts TTS speed & sentence boundaries |
| `SwitchScannerCamera` | `SET + SCANNER_CAMERA` | "switch camera", "flip camera", "change camera", "front camera", "back camera" | `scannerCapture`, `scannerReading` | Toggles rear / front camera |
| `CopyScannedText` | `COPY + TEXT` | "copy text", "copy to clipboard", "copy result", "copy document" | `scannerReading`, `scannerCapture` | Copies full OCR document text to system clipboard |

---

## 5. Navigation Actions

| Canonical Intent | Target Screen | Natural Phrase Variations | Allowed Contexts |
|---|---|---|---|
| `NavigateHome` | `RoutePaths.home` | "go home", "open home", "home screen", "main screen" | ALL |
| `NavigateSettings` | `RoutePaths.settings` | "open settings", "go to settings", "show settings", "preferences" | ALL |
| `NavigateScanner` | `RoutePaths.ocrScanner` | "open scanner", "open document scanner", "open ocr", "open reader" | ALL |
| `NavigateSmartAi` | `RoutePaths.assistant` | "open smart ai", "talk to ai", "ask ai", "open ai chat", "open assistant" | ALL |
| `NavigateMobileAssistance` | `RoutePaths.mobileAssistance` | "open mobile mode", "go to mobile mode", "open camera screen" | ALL |
| `NavigateRaspberryPi` | `RoutePaths.raspberryPi` | "open raspberry pi", "open pi", "pi screen", "wearable screen" | ALL |
| `NavigateModeSelection` | `RoutePaths.modeSelection` | "select mode", "choose mode", "mode selection", "open modes" | ALL |
| `NavigateSafety` | `RoutePaths.aboutSafety` | "open safety", "about safety", "safety screen", "safety info" | ALL |
| `NavigateHelp` | `RoutePaths.help` | "open help", "help screen", "open user guide", "instructions" | ALL |
| `NavigateBack` | `Navigator.pop()` | "go back", "navigate back", "return back", "previous screen" | ALL |

---

## 6. Settings & Accessibility Actions

| Canonical Intent | Setting | Natural Phrase Variations | Policy |
|---|---|---|---|
| `SetDetectionSensitivity` | `low`, `medium`, `high` | "decrease sensitivity", "increase confidence", "higher accuracy", "low sensitivity", "high sensitivity", "default sensitivity" | Updates detection confidence threshold; requires confirmation |
| `SetFeedbackMode` | `audio`, `vibration`, `both` | "feedback mode audio", "feedback mode vibration", "feedback mode both", "feedback mode audio and vibration" | Updates sensory alert channels; requires confirmation |
| `SetBooleanSetting` | `high_contrast` | "turn on high contrast", "enable high contrast", "disable high contrast" | Updates UI contrast theme |
| `SetBooleanSetting` | `large_text` | "turn on large text", "make text bigger", "disable large text" | Updates UI typography scale |
| `SetBooleanSetting` | `reduced_motion` | "turn on reduced motion", "disable animations", "turn off reduced motion" | Disables UI transitions |
| `SetBooleanSetting` | `vibration` | "turn on vibration", "enable haptics", "turn off vibration", "disable haptics" | Toggles phone vibration engine |
| `SetBooleanSetting` | `hands_free` | "turn on hands free", "enable wake word", "turn off hands free" | Toggles the foreground in-app wake listener |
| `SetFlashlight` | `enabled` (bool) | "turn on flashlight", "torch on", "light on", "turn off flashlight", "torch off", "light off" | Controls rear camera LED |
| `SetSpeechRate` | `fast`, `slow`, `normal` | "speak faster", "faster voice", "speak slower", "slower voice", "normal speech rate" | Updates platform TTS speed |
| `SetAnnouncementCooldown` | `seconds` (1-30) | "cooldown 2 seconds", "alert interval 5 seconds", "set cooldown to 3 seconds" | Limits minimum interval between audio alerts |
| `SetEnvironmentMode` | `indoor`, `outdoor`, `auto` | "indoor mode", "home mode", "outdoor mode", "street mode", "auto environment" | Switches object filter heuristics |
| `GetAppSettings` | (all) | "read settings", "current settings", "settings status", "what are the settings" | Speaks active configuration |

---

## 7. System & Utility Actions

| Canonical Intent | Natural Phrase Variations | Output |
|---|---|---|
| `GetCurrentTime` | "what time is it", "what is the time", "current time", "tell me the time" | Speaks local 12-hour time (e.g. "The time is 11:45 PM.") |
| `GetCurrentDate` | "what is today", "what is the date", "current date", "what day is it" | Speaks weekday, month, day, year (e.g. "Today is Monday, August 17, 2026.") |
| `GetBatteryStatus` | "battery level", "battery status", "how much battery", "check battery" | Speaks battery percentage |
| `GetAssistantConnectionStatus` | "assistant status", "connection status", "laptop status" | Speaks offline readiness status |

---

## 8. Raspberry Pi Wearable Actions

| Canonical Intent | Natural Phrase Variations | Policy |
|---|---|---|
| `GetPiStatus` | "raspberry pi status", "pi status", "is pi connected", "wearable status" | Speaks connection phase and discovered device count |
| `DiscoverPi` | "find raspberry pi", "discover pi", "scan for raspberry pi", "search for pi" | Scans local Wi-Fi LAN for Pi mDNS announcement |
| `ConnectPi` | "connect to raspberry pi", "connect pi", "pair pi" | Connects WebSocket transport; requires confirmation |
| `DisconnectPi` | "disconnect raspberry pi", "disconnect pi", "unpair pi" | Disconnects WebSocket; requires confirmation |
| `StartWearable` | "start wearable mode", "start pi detection" | Starts Pi camera inference stream |
| `StopWearable` | "stop wearable mode", "stop pi detection" | Stops Pi inference stream |
| `PauseWearable` | "pause wearable mode" | Suspends Pi camera stream |
| `ResumeWearable` | "resume wearable mode" | Resumes Pi camera stream |

---

## 9. Conversation & Meta Actions

| Canonical Intent | Natural Phrase Variations | Output |
|---|---|---|
| `Greeting` | "hello", "hi", "hey", "how are you", "vision" (wake word only) | "Hello. I'm ready to help. What would you like me to do?" |
| `WhatCanYouDo` | "what can you do", "how can you help", "available commands", "voice commands" | Lists primary capabilities and example phrasing |
| `WhoAreYou` | "who are you", "what are you", "your name" | "I'm Vision AI, your voice assistant for this app." |
| `ThankYou` | "thank you", "thanks" | "You're welcome. Say Vision whenever you need me." |
| `DismissAssistant` | "goodbye", "bye", "dismiss", "stop listening", "go to sleep", "sleep", "that's all", "quit" | "Goodbye." (Dismisses assistant overlay) |
| `ConfirmYes` | "yes", "confirm", "proceed", "do it", "sure" | Confirms pending dangerous action |
| `ConfirmNo` | "no", "cancel", "never mind", "stop", "abort" | Aborts pending dangerous action |
