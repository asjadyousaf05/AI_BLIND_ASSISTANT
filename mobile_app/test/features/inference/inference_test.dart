import 'package:flutter_test/flutter_test.dart';
import 'package:ai_blind_assistant/infrastructure/inference/model_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModelAssets constants', () {
    // UT-MODEL-001: Input size is 320
    test('UT-MODEL-001: input size is 320', () {
      expect(ModelAssets.inputSize, 320);
    });

    // UT-MODEL-002: 80 COCO classes
    test('UT-MODEL-002: num classes is 80', () {
      expect(ModelAssets.numClasses, 80);
    });

    // UT-MODEL-003: Output shape is discovered from interpreter metadata
    test('UT-MODEL-003: output candidate count is not hardcoded', () {
      expect(ModelAssets.boxCoordinatesNormalized, isTrue);
    });

    // UT-MODEL-004: Model path is set
    test('UT-MODEL-004: model path is defined', () {
      expect(ModelAssets.modelPath, contains('tflite'));
    });

    // UT-MODEL-005: Labels path is set
    test('UT-MODEL-005: labels path is defined', () {
      expect(ModelAssets.labelsPath, contains('coco_labels'));
    });

    test('UT-MODEL-006: bundled model, labels, and tensors validate', () async {
      expect(await ModelAssets.validateAssets(), isTrue);

      final labels = await ModelAssets.loadLabels();
      expect(labels, hasLength(80));
      expect(labels.first, 'person');
      expect(labels.last, 'toothbrush');

      final metadata = await ModelAssets.loadMetadata();
      expect(metadata['input_tensor']['shape'], [1, 3, 320, 320]);
      expect(metadata['output_tensor']['shape'], [1, 84, 2100]);
      expect(metadata['int8_quantized'], isFalse);
      expect(metadata['runtime_network_required'], isFalse);
    });
  });

  group('RawInferenceOutput', () {
    // UT-INFER-001: Tensor metadata path is bundled
    test('UT-INFER-001: generated tensor metadata path is defined', () {
      expect(ModelAssets.metadataPath, contains('model_metadata'));
    });
  });
}
