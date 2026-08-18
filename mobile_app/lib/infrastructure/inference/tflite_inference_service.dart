import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../domain/entities/raw_inference_output.dart';
import '../../domain/enums/inference_state.dart';
import '../../domain/services/camera_service.dart';
import '../../domain/services/inference_service.dart';
import 'model_assets.dart';

class TfliteInferenceService implements InferenceService {
  TfliteInferenceService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('ai_blind_assistant/inference');

  final MethodChannel _channel;
  final _stateController = StreamController<InferenceState>.broadcast();
  InferenceState _currentState = InferenceState.unloaded;
  bool _processing = false;
  bool _disposed = false;
  int _lastInferenceTimeMs = 0;
  String? _lastError;
  List<int> _inputShape = const [];
  List<int> _outputShape = const [];

  @override
  InferenceState get currentState => _currentState;

  @override
  Stream<InferenceState> get stateStream => _stateController.stream;

  @override
  int get lastInferenceTimeMs => _lastInferenceTimeMs;

  @override
  String? get lastError => _lastError;

  void _setState(InferenceState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  @override
  Future<void> loadModel() async {
    if (_disposed ||
        _currentState == InferenceState.loading ||
        _currentState == InferenceState.ready) {
      return;
    }

    _lastError = null;
    _setState(InferenceState.loading);

    try {
      if (!await ModelAssets.validateAssets()) {
        throw StateError(
          'Model assets or generated tensor metadata are invalid',
        );
      }
      final metadata = await ModelAssets.loadMetadata();

      final hasHousehold = await ModelAssets.validateHouseholdAssets();
      final result = await _channel
          .invokeMapMethod<String, dynamic>('loadModel', {
            'modelAsset': ModelAssets.modelPath,
            if (hasHousehold)
              'householdModelAsset': ModelAssets.householdModelPath,
          });
      if (result?['loaded'] != true) {
        throw StateError('Native LiteRT runtime did not load the model');
      }

      _inputShape = _intList(result?['inputShape']);
      _outputShape = _intList(result?['outputShape']);
      if (!_validInputShape(_inputShape) || !_validOutputShape(_outputShape)) {
        throw StateError(
          'Unsupported model tensors: input=$_inputShape output=$_outputShape',
        );
      }
      final expectedInputShape = _metadataShape(
        metadata['input_tensor'],
        'input',
      );
      final expectedOutputShape = _metadataShape(
        metadata['output_tensor'],
        'output',
      );
      if (!_sameShape(_inputShape, expectedInputShape) ||
          !_sameShape(_outputShape, expectedOutputShape)) {
        throw StateError(
          'Interpreter tensors do not match generated model metadata',
        );
      }
      if (result?['inputType'] != 'FLOAT32' ||
          result?['outputType'] != 'FLOAT32') {
        throw StateError(
          'This bundled model requires float32 input and output tensors',
        );
      }

      _setState(InferenceState.ready);
    } on PlatformException catch (error) {
      _lastError = error.message ?? error.code;
      _setState(InferenceState.error);
    } on MissingPluginException {
      _lastError = 'Android LiteRT bridge is unavailable';
      _setState(InferenceState.error);
    } catch (error) {
      _lastError = error.toString();
      _setState(InferenceState.error);
    }
  }

  @override
  Future<RawInferenceOutput?> runInference(CameraFrame frame) async {
    if (_disposed || _currentState != InferenceState.ready || _processing) {
      return null;
    }
    if (frame.format != CameraFrameFormat.yuv420 || frame.planes.length < 3) {
      _lastError = 'Camera did not provide three-plane YUV_420_888 data';
      _setState(InferenceState.error);
      return null;
    }

    _processing = true;
    _setState(InferenceState.processing);

    try {
      final stopwatch = Stopwatch()..start();
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'runInference',
        {
          'planes': frame.planes
              .map(
                (plane) => <String, dynamic>{
                  'bytes': plane.bytes,
                  'bytesPerRow': plane.bytesPerRow,
                  'bytesPerPixel': plane.bytesPerPixel,
                },
              )
              .toList(growable: false),
          'width': frame.width,
          'height': frame.height,
          'rotation': frame.rotationDegrees,
          'mirrorHorizontally': frame.isFrontFacing,
        },
      );
      stopwatch.stop();
      _lastInferenceTimeMs =
          (result?['inferenceTimeMs'] as num?)?.toInt() ??
          stopwatch.elapsedMilliseconds;

      final output = result?['output'];
      final outputData = switch (output) {
        Float32List values => values,
        List values => Float32List.fromList(
          values.map((value) => (value as num).toDouble()).toList(),
        ),
        _ => null,
      };
      if (outputData == null) {
        throw StateError('Native LiteRT runtime returned no output tensor');
      }

      final shape = _intList(result?['shape']);
      if (!_validOutputShape(shape) || outputData.length != _product(shape)) {
        throw StateError(
          'Native output does not match the loaded model tensor',
        );
      }

      final houseOutput = result?['householdOutput'];
      final houseOutputData = switch (houseOutput) {
        Float32List values => values,
        List values => Float32List.fromList(
          values.map((value) => (value as num).toDouble()).toList(),
        ),
        _ => null,
      };
      final houseShape = _intList(result?['householdShape']);

      _setState(InferenceState.ready);
      return RawInferenceOutput(
        data: outputData,
        outputShape: shape,
        householdData: houseOutputData,
        householdOutputShape: houseShape.isNotEmpty ? houseShape : null,
        inferenceTimeMs: _lastInferenceTimeMs,
        timestamp: frame.timestamp,
        inputWidth:
            (result?['inputWidth'] as num?)?.toInt() ?? ModelAssets.inputSize,
        inputHeight:
            (result?['inputHeight'] as num?)?.toInt() ?? ModelAssets.inputSize,
        previewWidth: (result?['previewWidth'] as num?)?.toInt(),
        previewHeight: (result?['previewHeight'] as num?)?.toInt(),
        letterboxScale: (result?['letterboxScale'] as num?)?.toDouble() ?? 1,
        letterboxPaddingX:
            (result?['letterboxPaddingX'] as num?)?.toDouble() ?? 0,
        letterboxPaddingY:
            (result?['letterboxPaddingY'] as num?)?.toDouble() ?? 0,
        boxCoordinatesNormalized: ModelAssets.boxCoordinatesNormalized,
      );
    } on PlatformException catch (error) {
      _lastError = error.message ?? error.code;
      _setState(InferenceState.error);
      return null;
    } catch (error) {
      _lastError = error.toString();
      _setState(InferenceState.error);
      return null;
    } finally {
      _processing = false;
    }
  }

  @override
  Future<void> unloadModel() async {
    _processing = false;
    _inputShape = const [];
    _outputShape = const [];
    try {
      await _channel.invokeMethod<void>('dispose');
    } on MissingPluginException {
      // A missing platform bridge owns no native interpreter to release.
    } on PlatformException catch (error) {
      _lastError = error.message ?? error.code;
      if (!_disposed) {
        _setState(InferenceState.error);
      }
      rethrow;
    }
    if (!_disposed) {
      _setState(InferenceState.unloaded);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await unloadModel();
    _disposed = true;
    await _stateController.close();
  }

  bool _validInputShape(List<int> shape) {
    return shape.length == 4 &&
        shape.first == 1 &&
        ((shape[1] == 3 &&
                shape[2] == ModelAssets.inputSize &&
                shape[3] == ModelAssets.inputSize) ||
            (shape[1] == ModelAssets.inputSize &&
                shape[2] == ModelAssets.inputSize &&
                shape[3] == 3));
  }

  bool _validOutputShape(List<int> shape) {
    return shape.length == 3 &&
        shape.first == 1 &&
        shape.contains(ModelAssets.numClasses + 4) &&
        shape.skip(1).every((dimension) => dimension > 0);
  }

  List<int> _intList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => (item as num).toInt()).toList(growable: false);
  }

  int _product(List<int> values) {
    return values.fold(1, (product, value) => product * value);
  }

  List<int> _metadataShape(Object? tensor, String name) {
    if (tensor is! Map<String, dynamic>) {
      throw StateError('Generated $name tensor metadata is missing');
    }
    final shape = _intList(tensor['shape']);
    if (shape.isEmpty) {
      throw StateError('Generated $name tensor shape is missing');
    }
    return shape;
  }

  bool _sameShape(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
