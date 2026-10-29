import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/assistant_providers.dart';
import '../../../app/providers.dart';
import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/voice_kernel/voice_diagnostic_logger.dart';
import '../../../app/voice_kernel/voice_kernel_providers.dart';
import '../../../core/widgets/app_screen_scaffold.dart';
import '../../../core/widgets/visual_components.dart';
import '../../../domain/entities/accessible_document.dart';
import '../../../domain/enums/assistant_audio_state.dart';
import '../../../domain/enums/reading_profile.dart';
import '../../../domain/enums/voice_feature_context.dart';
import '../../../domain/services/accessible_text_player.dart';
import '../../../domain/services/document_framing_analyzer.dart';
import '../../../domain/services/speech_output_service.dart';

/// States for the OCR scanning workflow.
enum _OcrState { idle, cameraReady, capturing, processing, result, error }

/// Professional, fully accessible Document Scanner & Reader Screen.
///
/// Features:
/// - Real-time animated viewfinder HUD with reticle corners and framing cues.
/// - On-device auto-torch and manual flashlight controls.
/// - On-device ML Kit OCR with instant privacy-first image cleanup.
/// - Sentence-by-sentence karaoke highlighting with interactive tap-to-jump.
/// - Full tactile and voice-controlled media playback console (Study, Normal, Skim, Spell).
/// - Quick clipboard copy and accessible TalkBack semantics.
class OcrScannerScreen extends ConsumerStatefulWidget {
  const OcrScannerScreen({super.key, this.initialDocumentTextForTesting});

  @visibleForTesting
  final String? initialDocumentTextForTesting;

  @override
  ConsumerState<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends ConsumerState<OcrScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;

  _OcrState _state = _OcrState.idle;
  String? _recognisedText;
  String? _errorMessage;
  bool _isSpeaking = false;
  bool _readerError = false;
  Completer<void>? _cameraInitCompleter;
  bool _isInitializingCamera = false;
  bool _resumeCameraAfterInitialization = false;
  bool _isCapturing = false;
  int _cameraGeneration = 0;
  int _captureGeneration = 0;

  final _framingAnalyzer = const DocumentFramingAnalyzer();
  DateTime _lastFramingTime = DateTime(2000);
  FramingCue _currentFramingCue = FramingCue.noDocument;
  FramingCue _lastSpokenCue = FramingCue.noDocument;
  bool _isTorchOn = false;
  bool _manualTorchChoice = false;
  bool _autoTorchFailed = false;
  bool _torchOperationInProgress = false;
  late final SpeechOutputService _speechService;
  late final VisionVoiceKernelV3 _voiceKernel;
  AccessibleTextPlayer? _textPlayer;

  late final AnimationController _scanLaserController;
  late final Animation<double> _scanLaserAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speechService = ref.read(speechOutputServiceProvider);
    _voiceKernel = ref.read(visionVoiceKernelProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _voiceKernel.setFeatureContext(VoiceFeatureContext.scannerCapture);
      ref.read(assistantAudioStateProvider.notifier).state =
          AssistantAudioState.scannerReady;
    });

    _textPlayer = AccessibleTextPlayer(
      speechService: _speechService,
      echoGuard: ref.read(ttsEchoGuardProvider),
      onStateChanged: () {
        if (!mounted) return;
        final currentStatus = _textPlayer?.status;
        if (currentStatus == PlaybackStatus.playing) {
          _readerError = false;
          _voiceKernel.setFeatureContext(VoiceFeatureContext.scannerReading);
          ref.read(assistantAudioStateProvider.notifier).state =
              AssistantAudioState.scannerReading;
        } else if (currentStatus == PlaybackStatus.paused) {
          _voiceKernel.setFeatureContext(VoiceFeatureContext.scannerReading);
          ref.read(assistantAudioStateProvider.notifier).state =
              AssistantAudioState.scannerPaused;
        } else if (currentStatus == PlaybackStatus.error) {
          _readerError = true;
          _voiceKernel.setFeatureContext(VoiceFeatureContext.scannerReading);
          ref.read(assistantAudioStateProvider.notifier).state =
              AssistantAudioState.scannerPaused;
          _announce('Reading aloud failed. Check speech output and try again.');
        } else if (currentStatus == PlaybackStatus.completed ||
            currentStatus == PlaybackStatus.idle) {
          final hasReadableDocument =
              _state == _OcrState.result &&
              !(_textPlayer?.document.isEmpty ?? true);
          _voiceKernel.setFeatureContext(
            hasReadableDocument
                ? VoiceFeatureContext.scannerReading
                : VoiceFeatureContext.scannerCapture,
          );
          ref
              .read(assistantAudioStateProvider.notifier)
              .state = hasReadableDocument
              ? AssistantAudioState.scannerPaused
              : AssistantAudioState.scannerReady;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        _voiceKernel.setReaderPlaybackActive(
          currentStatus == PlaybackStatus.playing,
        );
      },
    );

    _scanLaserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _scanLaserAnimation = CurvedAnimation(
      parent: _scanLaserController,
      curve: Curves.easeInOut,
    );

    final initialDocumentText = widget.initialDocumentTextForTesting;
    if (initialDocumentText != null && initialDocumentText.trim().isNotEmpty) {
      _state = _OcrState.result;
      _recognisedText = initialDocumentText;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _textPlayer?.load(initialDocumentText);
      });
    } else {
      unawaited(_initCamera());
    }
  }

  @override
  void dispose() {
    _voiceKernel.setReaderPlaybackActive(false);
    _cameraGeneration++;
    _captureGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceKernel.setFeatureContext(VoiceFeatureContext.unknown);
    });
    Future.microtask(() {
      try {
        ref.read(assistantAudioStateProvider.notifier).state =
            AssistantAudioState.idle;
      } catch (_) {}
    });
    _scanLaserController.dispose();
    unawaited(_cameraController?.dispose());
    unawaited(_textPlayer?.dispose());
    unawaited(_speechService.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _resumeCameraAfterInitialization = false;
      _cameraGeneration++;
      _captureGeneration++;
      final controller = _cameraController;
      _cameraController = null;
      unawaited(controller?.dispose());
      unawaited(_stopSpeaking());
      if (mounted && _state != _OcrState.result) {
        setState(() => _state = _OcrState.idle);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_state != _OcrState.result) {
        if (_isInitializingCamera) {
          _resumeCameraAfterInitialization = true;
        } else {
          unawaited(_initCamera(cameraIndex: _selectedCameraIndex));
        }
      }
    }
  }

  Future<void> _initCamera({int cameraIndex = 0}) async {
    if (_isInitializingCamera) return;
    _isInitializingCamera = true;
    final generation = ++_cameraGeneration;
    final ready = Completer<void>();
    _cameraInitCompleter = ready;
    CameraController? candidate;
    try {
      _availableCameras = await availableCameras();
      if (!mounted || generation != _cameraGeneration) return;
      if (_availableCameras.isEmpty) {
        _setError('No camera is available on this device.');
        return;
      }

      _selectedCameraIndex = cameraIndex.clamp(0, _availableCameras.length - 1);
      final targetCamera = _availableCameras[_selectedCameraIndex];

      candidate = CameraController(
        targetCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await candidate.initialize();
      if (!mounted || generation != _cameraGeneration) return;

      setState(() {
        _cameraController = candidate;
        _state = _OcrState.cameraReady;
        _isTorchOn = false;
        _manualTorchChoice = false;
        _autoTorchFailed = false;
      });
      _scanLaserController.repeat(reverse: true);
      final activeController = candidate;
      candidate = null;
      _announce('Scanner ready.');
      try {
        await activeController.startImageStream(_handleFramingStream);
      } catch (_) {}
    } on CameraException catch (error) {
      if (generation == _cameraGeneration) {
        _setError(
          error.code.contains('AccessDenied')
              ? 'Camera access is required. Allow it in Android settings, then restart the scanner.'
              : 'Camera could not start. Close other camera apps and try again.',
        );
      }
    } catch (_) {
      if (generation == _cameraGeneration) {
        _setError('Camera could not start. Please try again.');
      }
    } finally {
      await candidate?.dispose();
      if (!ready.isCompleted) ready.complete();
      if (identical(_cameraInitCompleter, ready)) _cameraInitCompleter = null;
      _isInitializingCamera = false;
      if (_resumeCameraAfterInitialization &&
          mounted &&
          _state != _OcrState.result) {
        _resumeCameraAfterInitialization = false;
        unawaited(_initCamera(cameraIndex: _selectedCameraIndex));
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isInitializingCamera || _isCapturing) {
      return;
    }
    final nextIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    _cameraGeneration++;
    final oldController = _cameraController;
    _cameraController = null;
    setState(() => _state = _OcrState.idle);
    await oldController?.dispose();
    await _initCamera(cameraIndex: nextIndex);
    if (mounted && _state == _OcrState.cameraReady) {
      _announce('Camera switched.');
    }
  }

  Future<void> _toggleTorch() async {
    await _setTorchEnabled(!_isTorchOn);
  }

  Future<void> _setTorchEnabled(bool enabled, {bool manual = true}) async {
    if (manual) _manualTorchChoice = true;
    if (_torchOperationInProgress) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      _announce('Camera is not ready.');
      return;
    }
    _torchOperationInProgress = true;
    try {
      await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
      if (!mounted || !identical(controller, _cameraController)) return;
      setState(() => _isTorchOn = enabled);
      HapticFeedback.lightImpact();
      _announce(enabled ? 'Flashlight on.' : 'Flashlight off.');
    } catch (_) {
      if (!manual) _autoTorchFailed = true;
      _announce('Flashlight is unavailable on this camera.');
    } finally {
      _torchOperationInProgress = false;
    }
  }

  void _handleFramingStream(CameraImage image) {
    if (_state != _OcrState.cameraReady || _isSpeaking) return;
    final now = DateTime.now();
    if (now.difference(_lastFramingTime).inMilliseconds < 1200) return;
    _lastFramingTime = now;

    if (image.planes.isEmpty) return;
    final yBytes = image.planes[0].bytes;
    final cue = _framingAnalyzer.analyzeYPlane(
      yBytes,
      width: image.width,
      height: image.height,
      bytesPerRow: image.planes[0].bytesPerRow,
      pixelStride: image.planes[0].bytesPerPixel ?? 1,
    );

    if (mounted && _currentFramingCue != cue) {
      setState(() => _currentFramingCue = cue);
    }

    // Auto-torch on low light in scanner: enable once if too dark, and keep on.
    if (cue == FramingCue.tooDark &&
        !_isTorchOn &&
        !_manualTorchChoice &&
        !_autoTorchFailed &&
        !_torchOperationInProgress) {
      unawaited(_setTorchEnabled(true, manual: false));
    }

    if (cue != _lastSpokenCue && cue != FramingCue.noDocument) {
      _lastSpokenCue = cue;
      if (cue == FramingCue.aligned) {
        HapticFeedback.mediumImpact();
      }
      _announce(cue.spokenGuidance);
    }
  }

  Future<void> _captureAndRecognise() async {
    if (_isCapturing) return;
    _isCapturing = true;
    final generation = ++_captureGeneration;
    final requestId = 'scan_${DateTime.now().millisecondsSinceEpoch}';
    VoiceDiagnosticLogger.scanAccepted(requestId);
    File? tempFile;
    try {
      await _stopSpeaking();
      HapticFeedback.heavyImpact();
      if (_isInitializingCamera) await _cameraInitCompleter?.future;
      if (!mounted || generation != _captureGeneration) return;
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        await _initCamera(cameraIndex: _selectedCameraIndex);
      }
      if (!mounted || generation != _captureGeneration) return;
      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) {
        _setError('Camera is not ready. Please restart the scanner.');
        return;
      }
      _textPlayer?.load('');
      _voiceKernel.setFeatureContext(VoiceFeatureContext.scannerCapture);
      ref.read(assistantAudioStateProvider.notifier).state =
          AssistantAudioState.scannerReady;
      setState(() {
        _state = _OcrState.capturing;
        _recognisedText = null;
        _errorMessage = null;
      });
      _scanLaserController.stop();
      _announce('Scanning.');
      if (controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
      }
      final xFile = await controller.takePicture();
      tempFile = File(xFile.path);
      if (!mounted || generation != _captureGeneration) return;
      setState(() => _state = _OcrState.processing);
      final ocrService = ref.read(ocrServiceProvider);
      final text = await ocrService.recogniseText(xFile.path);
      // Camera plugin stills are temporary; remove them before any playback.
      try {
        await tempFile.delete();
        tempFile = null;
      } catch (_) {
        if (mounted && generation == _captureGeneration) {
          _setError('The temporary photo could not be removed. Please retry.');
        }
        return;
      }
      if (!mounted || generation != _captureGeneration) return;
      if (text.trim().isEmpty) {
        setState(() {
          _state = _OcrState.result;
          _recognisedText = '';
        });
        _announce('No text found.');
        await _speechService.speak('No text found.');
      } else {
        setState(() {
          _state = _OcrState.result;
          _recognisedText = text;
        });
        unawaited(_speakResult(text));
      }
    } catch (_) {
      if (mounted && generation == _captureGeneration) {
        _setError(
          'Could not read this page. Hold the phone steady and try again.',
        );
      }
    } finally {
      try {
        await tempFile?.delete();
      } catch (_) {}
      _isCapturing = false;
      VoiceDiagnosticLogger.scanConsumed(requestId);
    }
  }

  Future<void> _speakResult(String text) async {
    await _stopSpeaking();
    if (!mounted) return;
    _isSpeaking = true;
    if (mounted) setState(() {});
    try {
      _textPlayer?.load(text);
      await _textPlayer?.play();
    } catch (_) {}
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _stopSpeaking() async {
    try {
      await _textPlayer?.stop();
      final tts = ref.read(speechOutputServiceProvider);
      await tts.stop();
    } catch (_) {}
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _pauseReading() async {
    await _textPlayer?.pause();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _resumeReading() async {
    if (_textPlayer?.document.isEmpty ?? true) return;
    if (mounted) setState(() => _isSpeaking = true);
    await _textPlayer?.resume();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _readPreviousLine() async {
    if (mounted) setState(() => _isSpeaking = true);
    await _textPlayer?.previous();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _readNextLine() async {
    if (mounted) setState(() => _isSpeaking = true);
    await _textPlayer?.next();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _repeatCurrentLine() async {
    if (mounted) setState(() => _isSpeaking = true);
    await _textPlayer?.repeat();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _readFirstLine() async {
    if (mounted) setState(() => _isSpeaking = true);
    await _textPlayer?.restart();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _readLastLine() async {
    if (mounted) setState(() => _isSpeaking = true);
    await _textPlayer?.readLast();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _readLine(int oneBasedLineNumber) async {
    final total = _textPlayer?.totalSentences ?? 0;
    if (total == 0) return;
    final target = oneBasedLineNumber.clamp(1, total);
    _announce('Reading line $target of $total.');
    if (mounted) setState(() => _isSpeaking = true);
    await _textPlayer?.readLine(target);
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _spellCurrentLine() async {
    if (mounted) setState(() => _isSpeaking = true);
    await _textPlayer?.spellCurrent();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _setReadingProfile(ReadingProfile profile) async {
    HapticFeedback.selectionClick();
    await _textPlayer?.setProfile(profile);
    _announce('${profile.label} reading speed selected.');
  }

  Future<void> _jumpToSentence(int index) async {
    HapticFeedback.selectionClick();
    await _readLine(index + 1);
  }

  Future<void> _showLinePicker() async {
    final total = _textPlayer?.totalSentences ?? 0;
    if (total == 0) return;
    final controller = TextEditingController(
      text: '${(_textPlayer?.currentIndex ?? 0) + 1}',
    );
    String? errorText;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Go to line'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Enter a line number from 1 to $total.'),
              const SizedBox(height: AppSpacing.space3),
              TextField(
                key: const Key('ocr_line_number_field'),
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Line number',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  final value = int.tryParse(controller.text);
                  if (value != null && value >= 1 && value <= total) {
                    Navigator.of(dialogContext).pop(value);
                  } else {
                    setDialogState(
                      () => errorText = 'Enter a number from 1 to $total.',
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('ocr_go_to_line_confirm_button'),
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null && value >= 1 && value <= total) {
                  Navigator.of(dialogContext).pop(value);
                } else {
                  setDialogState(
                    () => errorText = 'Enter a number from 1 to $total.',
                  );
                }
              },
              child: const Text('Read Line'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (selected != null && mounted) {
      await _readLine(selected);
    }
  }

  Future<void> _rescan() async {
    if (_isCapturing) {
      _announce('Please wait for this scan to finish.');
      return;
    }
    _captureGeneration++;
    await _stopSpeaking();
    if (!mounted) return;
    _textPlayer?.load('');
    _voiceKernel.setFeatureContext(VoiceFeatureContext.scannerCapture);
    HapticFeedback.lightImpact();
    setState(() {
      _state = _cameraController?.value.isInitialized == true
          ? _OcrState.cameraReady
          : _OcrState.idle;
      _recognisedText = null;
      _errorMessage = null;
      _currentFramingCue = FramingCue.noDocument;
    });
    _lastSpokenCue = FramingCue.noDocument;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _initCamera(cameraIndex: _selectedCameraIndex);
      return;
    }
    _scanLaserController.repeat(reverse: true);
    _announce('Scanner ready.');
    if (!controller.value.isStreamingImages) {
      try {
        await controller.startImageStream(_handleFramingStream);
      } catch (_) {}
    }
  }

  Future<void> _copyTextToClipboard(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    _announce('Text copied.');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 20),
              SizedBox(width: AppSpacing.space2),
              Text(
                'Text copied to clipboard',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppColors.slate800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            side: const BorderSide(color: AppColors.slate700),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openAssistantWithDocument() async {
    final document = _recognisedText;
    if (document == null || document.trim().isEmpty) return;
    await _stopSpeaking();
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review document with Vision AI'),
        content: const Text(
          'The document will be placed in an editable draft. Nothing is sent '
          'until you tap Send. Sending uses your paired laptop assistant and '
          'may use optional Gemini reasoning if you enabled it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('ocr_review_in_assistant_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Review Draft'),
          ),
        ],
      ),
    );
    if (proceed == true && mounted) {
      await Navigator.of(context).pushNamed(
        RoutePaths.assistant,
        arguments: 'Help me understand this scanned document:\n\n$document',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _voiceKernel.setFeatureContext(
          _state == _OcrState.result
              ? VoiceFeatureContext.scannerReading
              : VoiceFeatureContext.scannerCapture,
        );
      });
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    _scanLaserController.stop();
    setState(() {
      _state = _OcrState.error;
      _errorMessage = message;
    });
    _announce('Error: $message');
  }

  void _announce(String message) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view != null) {
      SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ocrActionTriggerProvider, (previous, next) {
      if (next == null) return;
      Future<void>.microtask(() {
        if (!mounted) return;
        ref.read(ocrActionTriggerProvider.notifier).clear();

        final reqId = 'trig_${DateTime.now().millisecondsSinceEpoch}';
        VoiceDiagnosticLogger.scanRequest(
          source: 'trigger_${next.action.name}',
          scanRequestId: reqId,
        );
        VoiceDiagnosticLogger.ocrAction(next.action.name);

        switch (next.action) {
          case OcrActionTrigger.capture:
            unawaited(_captureAndRecognise());
            break;
          case OcrActionTrigger.reset:
            unawaited(_rescan());
            break;
          case OcrActionTrigger.stopSpeaking:
            unawaited(_stopSpeaking());
            break;
          case OcrActionTrigger.readAgain:
            if (_recognisedText != null && _recognisedText!.isNotEmpty) {
              unawaited(_speakResult(_recognisedText!));
            }
            break;
          case OcrActionTrigger.pause:
            unawaited(_pauseReading());
            break;
          case OcrActionTrigger.resume:
            unawaited(_resumeReading());
            break;
          case OcrActionTrigger.previous:
            unawaited(_readPreviousLine());
            break;
          case OcrActionTrigger.next:
            unawaited(_readNextLine());
            break;
          case OcrActionTrigger.repeat:
            unawaited(_repeatCurrentLine());
            break;
          case OcrActionTrigger.restart:
            unawaited(_readFirstLine());
            break;
          case OcrActionTrigger.last:
            unawaited(_readLastLine());
            break;
          case OcrActionTrigger.goToLine:
            final lineNumber = next.lineNumber;
            if (lineNumber != null) unawaited(_readLine(lineNumber));
            break;
          case OcrActionTrigger.spell:
            unawaited(_spellCurrentLine());
            break;
          case OcrActionTrigger.setLearningMode:
            unawaited(_setReadingProfile(ReadingProfile.learning));
            break;
          case OcrActionTrigger.setNormalMode:
            unawaited(_setReadingProfile(ReadingProfile.normal));
            break;
          case OcrActionTrigger.setSkimMode:
            unawaited(_setReadingProfile(ReadingProfile.skim));
            break;
          case OcrActionTrigger.switchCamera:
            unawaited(_switchCamera());
            break;
          case OcrActionTrigger.enableTorch:
            unawaited(_setTorchEnabled(true));
            break;
          case OcrActionTrigger.disableTorch:
            unawaited(_setTorchEnabled(false));
            break;
          case OcrActionTrigger.copyText:
            if (_recognisedText != null && _recognisedText!.isNotEmpty) {
              unawaited(_copyTextToClipboard(_recognisedText!));
            }
            break;
        }
      });
    });

    return AppScreenScaffold(
      title: 'Document Scanner',
      children: [
        // Status pill
        Semantics(
          liveRegion: true,
          child: StatusPill(
            label: _statusLabel,
            icon: _statusIcon,
            color: _statusColor,
          ),
        ),
        const SizedBox(height: AppSpacing.space3),

        // Main dynamic area (Viewfinder, processing animation, or reader)
        _buildMainArea(context),

        const SizedBox(height: AppSpacing.space4),

        // Controls and action buttons
        _buildActionButtons(context),

        if (_state != _OcrState.result) ...[
          const SizedBox(height: AppSpacing.space4),
          const SafetyNotice(
            title: 'Document Scanner Privacy',
            messages: [
              'Photos are processed on this phone only using local ML Kit AI. '
                  'The temporary photo is deleted after recognition.',
              'For best results, hold the phone parallel and steady ~10-12 inches over a flat document.',
              'Voice accessible: you can say "Scan Document" or "Read Document" anytime.',
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMainArea(BuildContext context) {
    return switch (_state) {
      _OcrState.idle || _OcrState.cameraReady => _ScannerViewfinder(
        controller: _cameraController,
        isReady: _state == _OcrState.cameraReady,
        framingCue: _currentFramingCue,
        isTorchOn: _isTorchOn,
        canSwitchCamera: _availableCameras.length > 1,
        onToggleTorch: _toggleTorch,
        onSwitchCamera: _switchCamera,
        laserAnimation: _scanLaserAnimation,
      ),
      _OcrState.capturing || _OcrState.processing => _ProcessingArea(
        isCapturing: _state == _OcrState.capturing,
      ),
      _OcrState.result =>
        (_recognisedText == null || _recognisedText!.trim().isEmpty)
            ? _EmptyTextResultArea(onRescan: _rescan)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Interactive Playback Transport Deck at TOP
                  _PlaybackControlConsole(
                    player: _textPlayer,
                    isPlaying: _textPlayer?.isPlaying ?? _isSpeaking,
                    onPlayPause: () {
                      if (_textPlayer?.isPlaying ?? _isSpeaking) {
                        unawaited(_pauseReading());
                      } else {
                        unawaited(_resumeReading());
                      }
                    },
                    onStop: () => unawaited(_stopSpeaking()),
                    onPrevious: () => unawaited(_readPreviousLine()),
                    onNext: () => unawaited(_readNextLine()),
                    onFirst: () => unawaited(_readFirstLine()),
                    onLast: () => unawaited(_readLastLine()),
                    onSelectLine: () => unawaited(_showLinePicker()),
                    onRepeat: () => unawaited(_repeatCurrentLine()),
                    onSpell: () => unawaited(_spellCurrentLine()),
                    onSetProfile: (profile) =>
                        unawaited(_setReadingProfile(profile)),
                  ),
                  if (_readerError) ...[
                    const SizedBox(height: AppSpacing.space3),
                    Semantics(
                      liveRegion: true,
                      child: const Text(
                        'Reading aloud stopped because speech output failed. '
                        'Check your phone volume and speech engine, then tap Start Reading.',
                        style: TextStyle(color: AppColors.warning),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.space3),
                  const _ScannerVoiceShortcutsCard(),
                  const SizedBox(height: AppSpacing.space3),

                  // 2. Large Currently-Reading Spotlight Box
                  _CurrentSentenceSpotlightCard(
                    player: _textPlayer,
                    isSpeaking:
                        _isSpeaking || (_textPlayer?.isPlaying ?? false),
                    onStop: () => unawaited(_stopSpeaking()),
                  ),
                  const SizedBox(height: AppSpacing.space3),

                  // 3. Full Document Karaoke Text Card
                  _DocumentReaderKaraokeCard(
                    text: _recognisedText!,
                    player: _textPlayer,
                    onSentenceTapped: _jumpToSentence,
                    onCopyText: () => _copyTextToClipboard(_recognisedText!),
                  ),
                ],
              ),
      _OcrState.error => _ErrorArea(
        message: _errorMessage ?? 'Unknown camera error',
      ),
    };
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_state == _OcrState.cameraReady) ...[
          // Primary Scan Action Button
          Semantics(
            button: true,
            label: 'Scan document and read aloud',
            hint: 'Captures a photo and recognizes text on this phone.',
            onTap: _captureAndRecognise,
            excludeSemantics: true,
            child: FilledButton.icon(
              key: const Key('ocr_scan_button'),
              onPressed: _captureAndRecognise,
              icon: const Icon(Icons.document_scanner_outlined, size: 28),
              label: const Text('Scan Document'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
                minimumSize: const Size.fromHeight(
                  AppDimensions.heroControlHeight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                ),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),

          // Quick Action Toolbar: Flashlight, Camera Flip, Voice Assistant
          _ResponsiveActionGroup(
            children: [
              OutlinedButton.icon(
                onPressed: _toggleTorch,
                icon: Icon(
                  _isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: _isTorchOn ? AppColors.warning : AppColors.slate300,
                ),
                label: Text(
                  _isTorchOn ? 'Turn flashlight off' : 'Turn flashlight on',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_availableCameras.length > 1) ...[
                OutlinedButton.icon(
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.flip_camera_ios_outlined),
                  label: const Text('Switch camera'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
              FilledButton.tonalIcon(
                onPressed: () {
                  unawaited(
                    ref
                        .read(visionVoiceKernelProvider.notifier)
                        .startHandsFree(),
                  );
                },
                icon: const Icon(Icons.mic, color: AppColors.primary),
                label: const Text('Enable voice controls'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.space2),
          const Center(
            child: Text(
              'Voice commands: Say "Scan Document", "Flashlight on", or "Read document"',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.slate400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (_state == _OcrState.result &&
            _recognisedText != null &&
            _recognisedText!.trim().isNotEmpty) ...[
          // Secondary Action Row: Read Again, Copy Text, Ask AI
          _ResponsiveActionGroup(
            children: [
              OutlinedButton.icon(
                onPressed: () => _speakResult(_recognisedText!),
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Read document again'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyTextToClipboard(_recognisedText!),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy document text'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              Semantics(
                label: 'Review scanned document with Vision AI',
                button: true,
                onTap: _openAssistantWithDocument,
                excludeSemantics: true,
                child: FilledButton.tonalIcon(
                  onPressed: _openAssistantWithDocument,
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                  ),
                  label: const Text('Ask AI'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),

          // Scan another document primary button
          Semantics(
            button: true,
            label: 'Scan another document',
            hint: 'Returns to the camera to scan a new page.',
            onTap: _rescan,
            excludeSemantics: true,
            child: FilledButton.icon(
              key: const Key('ocr_rescan_button'),
              onPressed: _rescan,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan Another Page'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(
                  AppDimensions.heroControlHeight,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        if (_state == _OcrState.error) ...[
          Semantics(
            button: true,
            label: 'Restart document scanner camera',
            onTap: () => unawaited(_initCamera()),
            excludeSemantics: true,
            child: FilledButton.icon(
              key: const Key('ocr_retry_button'),
              onPressed: () => unawaited(_initCamera()),
              icon: const Icon(Icons.refresh),
              label: const Text('Restart Scanner'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(
                  AppDimensions.heroControlHeight,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String get _statusLabel => switch (_state) {
    _OcrState.idle => 'Scanner: Initialising',
    _OcrState.cameraReady => 'Scanner: Ready to Scan',
    _OcrState.capturing => 'Scanner: Capturing Photo',
    _OcrState.processing => 'Scanner: Reading Document with AI',
    _OcrState.result =>
      (_recognisedText != null && _recognisedText!.trim().isNotEmpty)
          ? 'Scanner: Reading Text'
          : 'Scanner: Ready',
    _OcrState.error => 'Scanner: Camera Error',
  };

  IconData get _statusIcon => switch (_state) {
    _OcrState.idle || _OcrState.cameraReady => Icons.document_scanner_outlined,
    _OcrState.capturing => Icons.camera_alt,
    _OcrState.processing => Icons.auto_awesome,
    _OcrState.result => Icons.check_circle_outline,
    _OcrState.error => Icons.error_outline,
  };

  Color get _statusColor => switch (_state) {
    _OcrState.idle || _OcrState.cameraReady => AppColors.primary,
    _OcrState.capturing || _OcrState.processing => AppColors.warning,
    _OcrState.result => AppColors.success,
    _OcrState.error => AppColors.error,
  };
}

// ---------------------------------------------------------------------------
// Viewfinder & Reticle Overlay
// ---------------------------------------------------------------------------

class _ScannerViewfinder extends StatelessWidget {
  const _ScannerViewfinder({
    required this.controller,
    required this.isReady,
    required this.framingCue,
    required this.isTorchOn,
    required this.canSwitchCamera,
    required this.onToggleTorch,
    required this.onSwitchCamera,
    required this.laserAnimation,
  });

  final CameraController? controller;
  final bool isReady;
  final FramingCue framingCue;
  final bool isTorchOn;
  final bool canSwitchCamera;
  final VoidCallback onToggleTorch;
  final VoidCallback onSwitchCamera;
  final Animation<double> laserAnimation;

  @override
  Widget build(BuildContext context) {
    if (!isReady || controller == null) {
      return const _PlaceholderBox(
        icon: Icons.camera_alt_outlined,
        label: 'Initialising high-resolution camera…',
        color: AppColors.slate400,
        showSpinner: true,
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          'Live camera document scanner viewfinder. Point at document to align.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(
              color: framingCue == FramingCue.aligned
                  ? AppColors.success
                  : AppColors.primary.withValues(alpha: 0.6),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera Live Feed Fitted
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller!.value.previewSize?.height ?? 1080,
                  height: controller!.value.previewSize?.width ?? 1920,
                  child: CameraPreview(controller!),
                ),
              ),

              // Scanner Reticle Overlay & Corners
              Positioned.fill(
                child: CustomPaint(
                  painter: _ReticleCornerPainter(
                    color: framingCue == FramingCue.aligned
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),
              ),

              // Animated Scanning Laser Line
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: laserAnimation,
                  builder: (context, child) {
                    return Align(
                      alignment: Alignment(0, (laserAnimation.value * 2) - 1.0),
                      child: Container(
                        height: 2.5,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.primary.withValues(alpha: 0.85),
                              Colors.white,
                              AppColors.primary.withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Top Quick Actions Bar (Flashlight + Camera Switch)
              Positioned(
                top: AppSpacing.space3,
                left: AppSpacing.space3,
                right: AppSpacing.space3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Torch button
                    Semantics(
                      button: true,
                      label: isTorchOn
                          ? 'Turn off flashlight'
                          : 'Turn on flashlight',
                      onTap: onToggleTorch,
                      excludeSemantics: true,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadii.full),
                        child: InkWell(
                          key: const Key('ocr_torch_button'),
                          borderRadius: BorderRadius.circular(AppRadii.full),
                          onTap: onToggleTorch,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.space3,
                              vertical: AppSpacing.space2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                                  size: 18,
                                  color: isTorchOn
                                      ? AppColors.warning
                                      : Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isTorchOn ? 'Flash On' : 'Flash Off',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isTorchOn
                                        ? AppColors.warning
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Camera Switch (if available)
                    if (canSwitchCamera)
                      Semantics(
                        button: true,
                        label: 'Switch camera lens',
                        onTap: onSwitchCamera,
                        excludeSemantics: true,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: const Key('ocr_camera_switch_button'),
                            onPressed: onSwitchCamera,
                            icon: const Icon(
                              Icons.flip_camera_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Switch Camera',
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Real-Time Framing Status HUD
              Positioned(
                bottom: AppSpacing.space3,
                left: AppSpacing.space3,
                right: AppSpacing.space3,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space4,
                      vertical: AppSpacing.space2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      border: Border.all(
                        color: _cueColor(framingCue).withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _cueIcon(framingCue),
                          color: _cueColor(framingCue),
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Flexible(
                          child: Text(
                            framingCue == FramingCue.noDocument
                                ? 'Align document inside frame'
                                : framingCue.spokenGuidance,
                            style: TextStyle(
                              color: _cueColor(framingCue),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _cueColor(FramingCue cue) => switch (cue) {
    FramingCue.aligned => AppColors.success,
    FramingCue.tooDark || FramingCue.tooBright => AppColors.warning,
    FramingCue.moveHigher ||
    FramingCue.moveLower ||
    FramingCue.moveLeft ||
    FramingCue.moveRight => AppColors.primary,
    FramingCue.noDocument => AppColors.slate300,
  };

  IconData _cueIcon(FramingCue cue) => switch (cue) {
    FramingCue.aligned => Icons.check_circle,
    FramingCue.tooDark => Icons.flash_on,
    FramingCue.tooBright => Icons.wb_sunny,
    FramingCue.moveHigher => Icons.arrow_upward,
    FramingCue.moveLower => Icons.arrow_downward,
    FramingCue.moveLeft => Icons.arrow_back,
    FramingCue.moveRight => Icons.arrow_forward,
    FramingCue.noDocument => Icons.crop_free,
  };
}

class _ReticleCornerPainter extends CustomPainter {
  const _ReticleCornerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 32.0;
    const padding = 20.0;

    // Top-Left
    canvas.drawLine(
      const Offset(padding, padding + cornerLength),
      const Offset(padding, padding),
      paint,
    );
    canvas.drawLine(
      const Offset(padding, padding),
      const Offset(padding + cornerLength, padding),
      paint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(size.width - padding - cornerLength, padding),
      Offset(size.width - padding, padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding, padding + cornerLength),
      paint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(padding, size.height - padding - cornerLength),
      Offset(padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding + cornerLength, size.height - padding),
      paint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width - padding - cornerLength, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding - cornerLength),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReticleCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Processing Area
// ---------------------------------------------------------------------------

class _ProcessingArea extends StatelessWidget {
  const _ProcessingArea({required this.isCapturing});
  final bool isCapturing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: isCapturing
          ? 'Capturing photo, hold steady.'
          : 'Extracting text with on-device AI. Please wait.',
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                isCapturing
                    ? 'Capturing Document…'
                    : 'Reading Document with AI…',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.space1),
              const Text(
                'On-device ML Kit OCR Engine',
                style: TextStyle(fontSize: 13, color: AppColors.slate400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Current Sentence Spotlight Card (Hero Reading Box)
// ---------------------------------------------------------------------------

class _CurrentSentenceSpotlightCard extends StatelessWidget {
  const _CurrentSentenceSpotlightCard({
    required this.player,
    required this.isSpeaking,
    required this.onStop,
  });

  final AccessibleTextPlayer? player;
  final bool isSpeaking;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final currentSentence = player?.currentSentence?.text ?? '';
    final total = player?.totalSentences ?? 1;
    final currentIdx = (player?.currentIndex ?? 0) + 1;

    if (currentSentence.trim().isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: isSpeaking
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.slate800,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(
            color: isSpeaking ? AppColors.primary : AppColors.slate700,
            width: 2,
          ),
          boxShadow: isSpeaking
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isSpeaking
                      ? Icons.graphic_eq_rounded
                      : Icons.pause_circle_outline_rounded,
                  color: isSpeaking ? AppColors.primary : AppColors.slate400,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: Text(
                    isSpeaking
                        ? 'NOW READING (LINE $currentIdx / $total)'
                        : 'READY (LINE $currentIdx / $total)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isSpeaking
                          ? AppColors.primary
                          : AppColors.slate400,
                    ),
                  ),
                ),
                if (isSpeaking)
                  Semantics(
                    button: true,
                    label: 'Stop document reading',
                    onTap: onStop,
                    excludeSemantics: true,
                    child: OutlinedButton.icon(
                      onPressed: onStop,
                      icon: const Icon(
                        Icons.stop_circle,
                        color: AppColors.error,
                        size: 18,
                      ),
                      label: const Text(
                        'Stop',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              currentSentence,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Interactive Document Karaoke Reader Deck
// ---------------------------------------------------------------------------

class _DocumentReaderKaraokeCard extends StatelessWidget {
  const _DocumentReaderKaraokeCard({
    required this.text,
    required this.player,
    required this.onSentenceTapped,
    required this.onCopyText,
  });

  final String text;
  final AccessibleTextPlayer? player;
  final ValueChanged<int> onSentenceTapped;
  final VoidCallback onCopyText;

  @override
  Widget build(BuildContext context) {
    final sentences = player?.sentenceTexts ?? [text];
    final currentIndex = player?.currentIndex ?? 0;
    final wordCount = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar: Metadata & Quick Copy
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space3,
            ),
            decoration: BoxDecoration(
              color: AppColors.slate800,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              border: Border.all(color: AppColors.slate700),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.article_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Document Text',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onDarkSurface,
                        ),
                      ),
                      Text(
                        '$wordCount words • ${sentences.length} reading lines',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Copy Action Button
                Semantics(
                  button: true,
                  label: 'Copy full document text to clipboard',
                  onTap: onCopyText,
                  excludeSemantics: true,
                  child: OutlinedButton.icon(
                    key: const Key('ocr_copy_button'),
                    onPressed: onCopyText,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space3,
                        vertical: AppSpacing.space1,
                      ),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space3),

          // Interactive Sentence-by-Sentence Karaoke List
          for (int index = 0; index < sentences.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.space2),
            () {
              final isCurrent = index == currentIndex;
              final sentence = sentences[index];

              return Semantics(
                button: true,
                label: 'Read from line ${index + 1}: $sentence',
                selected: isCurrent,
                onTap: () => onSentenceTapped(index),
                excludeSemantics: true,
                child: Material(
                  color: isCurrent
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.slate800,
                  borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
                    onTap: () => onSentenceTapped(index),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.space3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppRadii.defaultRadius,
                        ),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primary
                              : AppColors.slate700,
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Index / Reading Marker
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(
                              right: AppSpacing.space3,
                              top: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.primary
                                  : AppColors.slate700,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isCurrent
                                  ? const Icon(
                                      Icons.volume_up,
                                      size: 16,
                                      color: AppColors.onPrimary,
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          // Sentence Text
                          Expanded(
                            child: isCurrent && player?.currentWord != null
                                ? _buildWordHighlight(
                                    sentence,
                                    player!.currentWord!,
                                  )
                                : Text(
                                    sentence,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.45,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isCurrent
                                          ? Colors.white
                                          : AppColors.slate200,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }(),
          ],
        ],
      ),
    );
  }

  Widget _buildWordHighlight(String sentence, AccessibleWord currentWord) {
    final start = currentWord.sentenceStart.clamp(0, sentence.length);
    final end = currentWord.sentenceEnd.clamp(0, sentence.length);
    if (start >= end) {
      return Text(
        sentence,
        style: const TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }

    final prefix = sentence.substring(0, start);
    final word = sentence.substring(start, end);
    final suffix = sentence.substring(end);

    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: word,
            style: const TextStyle(
              backgroundColor: AppColors.primary,
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: suffix),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Playback Control Console (Deck)
// ---------------------------------------------------------------------------

class _PlaybackControlConsole extends StatelessWidget {
  const _PlaybackControlConsole({
    required this.player,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onStop,
    required this.onPrevious,
    required this.onNext,
    required this.onFirst,
    required this.onLast,
    required this.onSelectLine,
    required this.onRepeat,
    required this.onSpell,
    required this.onSetProfile,
  });

  final AccessibleTextPlayer? player;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFirst;
  final VoidCallback onLast;
  final VoidCallback onSelectLine;
  final VoidCallback onRepeat;
  final VoidCallback onSpell;
  final ValueChanged<ReadingProfile> onSetProfile;

  @override
  Widget build(BuildContext context) {
    final total = player?.totalSentences ?? 1;
    final current = (player?.currentIndex ?? 0) + 1;
    final progress = (total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;
    final currentProfile = player?.profile ?? ReadingProfile.normal;
    final playLabel = isPlaying
        ? 'Pause Reading'
        : player?.status == PlaybackStatus.paused
        ? 'Resume Reading'
        : 'Start Reading';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.slate800,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.slate700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Reading-line progress and active speed.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Line $current of $total',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.slate700.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(color: AppColors.slate600),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.speed_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currentProfile.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate200,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),

          // Linear Progress Indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.slate700,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),

          // Hero Media Transport Controls (Skip Back, Hero Play/Pause, Skip Next)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous reading line.
              Semantics(
                button: true,
                label: 'Read previous document line',
                onTap: onPrevious,
                excludeSemantics: true,
                child: Material(
                  color: AppColors.slate700,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('ocr_prev_button'),
                    customBorder: const CircleBorder(),
                    onTap: onPrevious,
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.space3),
                      child: Icon(
                        Icons.skip_previous_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space4),

              // Hero Play / Pause Button with Cyan Glow
              Semantics(
                button: true,
                label: playLabel,
                onTap: onPlayPause,
                excludeSemantics: true,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const Key('ocr_play_pause_button'),
                      customBorder: const CircleBorder(),
                      onTap: onPlayPause,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 38,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space4),

              // Next reading line.
              Semantics(
                button: true,
                label: 'Read next document line',
                onTap: onNext,
                excludeSemantics: true,
                child: Material(
                  color: AppColors.slate700,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('ocr_next_button'),
                    customBorder: const CircleBorder(),
                    onTap: onNext,
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.space3),
                      child: Icon(
                        Icons.skip_next_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          ExcludeSemantics(
            child: Text(
              playLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.onDarkSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),

          // Direct line navigation: first, numbered picker, and last.
          _ResponsiveActionGroup(
            children: [
              OutlinedButton.icon(
                key: const Key('ocr_first_line_button'),
                onPressed: onFirst,
                icon: const Icon(Icons.first_page_rounded, size: 19),
                label: const Text('Read first line'),
              ),
              FilledButton.tonalIcon(
                key: const Key('ocr_line_picker_button'),
                onPressed: onSelectLine,
                icon: const Icon(Icons.format_list_numbered_rounded, size: 19),
                label: const Text('Choose reading line'),
              ),
              OutlinedButton.icon(
                key: const Key('ocr_last_line_button'),
                onPressed: onLast,
                icon: const Icon(Icons.last_page_rounded, size: 19),
                label: const Text('Read last line'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Semantics(
            button: true,
            label: 'Stop document reading',
            hint: 'Keeps the current line selected.',
            onTap: onStop,
            excludeSemantics: true,
            child: OutlinedButton.icon(
              key: const Key('ocr_stop_reading_button'),
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop Reading'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),

          // Secondary Utilities Row: Repeat & Spell Out
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Repeat current line',
                  onTap: onRepeat,
                  excludeSemantics: true,
                  child: OutlinedButton.icon(
                    key: const Key('ocr_repeat_button'),
                    onPressed: onRepeat,
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Repeat'),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space2,
                        vertical: AppSpacing.space2,
                      ),
                      side: const BorderSide(color: AppColors.slate600),
                      foregroundColor: AppColors.slate200,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Spell out current line letter by letter',
                  onTap: onSpell,
                  excludeSemantics: true,
                  child: OutlinedButton.icon(
                    key: const Key('ocr_spell_button'),
                    onPressed: onSpell,
                    icon: const Icon(Icons.spellcheck_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Spell Out'),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space2,
                        vertical: AppSpacing.space2,
                      ),
                      side: const BorderSide(color: AppColors.slate600),
                      foregroundColor: AppColors.slate200,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),

          // Section Divider
          const Divider(color: AppColors.slate700, height: 1),
          const SizedBox(height: AppSpacing.space3),

          // Speed Control Section Header
          const Row(
            children: [
              Icon(Icons.speed_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'READING SPEED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.slate400,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),

          // Professional Segmented Speed Pill Bar (Unbreakable, Fitted)
          Container(
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              border: Border.all(color: AppColors.slate700),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _SpeedSegmentPill(
                  key: const Key('ocr_speed_learning_button'),
                  title: 'Study',
                  multiplier: '0.35×',
                  isSelected: currentProfile == ReadingProfile.learning,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSetProfile(ReadingProfile.learning);
                  },
                  semanticLabel: 'Set study reading speed',
                ),
                const SizedBox(width: 4),
                _SpeedSegmentPill(
                  key: const Key('ocr_speed_normal_button'),
                  title: 'Normal',
                  multiplier: '0.50×',
                  isSelected: currentProfile == ReadingProfile.normal,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSetProfile(ReadingProfile.normal);
                  },
                  semanticLabel: 'Set normal reading speed',
                ),
                const SizedBox(width: 4),
                _SpeedSegmentPill(
                  key: const Key('ocr_speed_skim_button'),
                  title: 'Fast',
                  multiplier: '0.75×',
                  isSelected: currentProfile == ReadingProfile.skim,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSetProfile(ReadingProfile.skim);
                  },
                  semanticLabel: 'Set fast reading speed',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps actions readable at large text sizes and on narrow phones.
class _ResponsiveActionGroup extends StatelessWidget {
  const _ResponsiveActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 440 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        final width = stacked
            ? constraints.maxWidth
            : (constraints.maxWidth -
                      AppSpacing.space2 * (children.length - 1)) /
                  children.length;
        return Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _SpeedSegmentPill extends StatelessWidget {
  const _SpeedSegmentPill({
    super.key,
    required this.title,
    required this.multiplier,
    required this.isSelected,
    required this.onTap,
    required this.semanticLabel,
  });

  final String title;
  final String multiplier;
  final bool isSelected;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        inMutuallyExclusiveGroup: true,
        label: semanticLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.space2,
                horizontal: AppSpacing.space1,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected ? AppColors.onPrimary : Colors.white,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      multiplier,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.onPrimary.withValues(alpha: 0.85)
                            : AppColors.slate400,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerVoiceShortcutsCard extends StatelessWidget {
  const _ScannerVoiceShortcutsCard();

  @override
  Widget build(BuildContext context) {
    const commands =
        'Pause reading • Start reading • Stop reading • First line • '
        'Last line • Go to line 5 • Spell out';
    return Semantics(
      label: 'Available document voice commands: $commands',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.mic_none_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: AppSpacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VOICE CONTROLS',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    commands,
                    style: TextStyle(
                      color: AppColors.slate200,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / Error State Areas
// ---------------------------------------------------------------------------

class _EmptyTextResultArea extends StatelessWidget {
  const _EmptyTextResultArea({required this.onRescan});
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'No text detected on document. Tips to scan again.',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 48,
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.space2),
            const Text(
              'No Text Detected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            const Text(
              'We couldn\'t find legible text on this image. Follow these quick tips for a clean scan:',
              style: TextStyle(fontSize: 14, color: AppColors.slate300),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTip(
                  Icons.lightbulb_outline,
                  'Ensure good lighting (turn on flashlight).',
                ),
                _buildTip(
                  Icons.straighten,
                  'Hold phone parallel ~10-12 inches over page.',
                ),
                _buildTip(
                  Icons.document_scanner,
                  'Avoid blurry motion while capturing.',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            FilledButton.icon(
              onPressed: onRescan,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Scanning Again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space1),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.slate200),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorArea extends StatelessWidget {
  const _ErrorArea({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Scanner error: $message',
      child: _PlaceholderBox(
        icon: Icons.error_outline,
        label: message,
        color: AppColors.error,
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox({
    required this.icon,
    required this.label,
    required this.color,
    this.showSpinner = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSpinner)
              CircularProgressIndicator(color: color)
            else
              Icon(icon, size: 48, color: color),
            const SizedBox(height: AppSpacing.space3),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
