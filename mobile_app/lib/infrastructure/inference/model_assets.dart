import 'dart:convert';

import 'package:flutter/services.dart';

class ModelAssets {
  static const modelPath = 'assets/models/yolov8n_float32.tflite';
  static const labelsPath = 'assets/models/coco_labels.txt';
  static const metadataPath = 'assets/models/model_metadata.json';

  static const householdModelPath =
      'assets/models/household_yolov8n_float32.tflite';
  static const householdLabelsPath = 'assets/models/openimages_labels.txt';
  static const householdMetadataPath =
      'assets/models/household_model_metadata.json';

  static const int inputSize = 320;
  static const int numClasses = 80;
  static const int householdNumClasses = 601;
  static const bool boxCoordinatesNormalized = true;

  static Future<List<String>> loadLabels() async {
    final data = await rootBundle.loadString(labelsPath);
    return data
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static Future<List<String>> loadHouseholdLabels() async {
    final data = await rootBundle.loadString(householdLabelsPath);
    return data
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static Future<Map<String, dynamic>> loadMetadata() async {
    final data = await rootBundle.loadString(metadataPath);
    return json.decode(data) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> loadHouseholdMetadata() async {
    final data = await rootBundle.loadString(householdMetadataPath);
    return json.decode(data) as Map<String, dynamic>;
  }

  static Future<bool> validateAssets() async {
    try {
      final labels = await loadLabels();
      if (labels.length != numClasses) return false;

      final metadata = await loadMetadata();
      if (metadata['classes'] != numClasses) return false;
      if (metadata['input_size'] != inputSize) return false;
      if (metadata['box_coordinates'] !=
          'normalized_xywh_relative_to_letterboxed_input') {
        return false;
      }

      final input = metadata['input_tensor'] as Map<String, dynamic>?;
      final output = metadata['output_tensor'] as Map<String, dynamic>?;
      if (input == null || output == null) return false;
      if (input['type'] != 'float32' || output['type'] != 'float32') {
        return false;
      }

      final modelData = await rootBundle.load(modelPath);
      if (modelData.lengthInBytes == 0) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> validateHouseholdAssets() async {
    try {
      final labels = await loadHouseholdLabels();
      if (labels.length != householdNumClasses) return false;

      final metadata = await loadHouseholdMetadata();
      if (metadata['classes'] != householdNumClasses) return false;
      if (metadata['input_size'] != inputSize) return false;

      final modelData = await rootBundle.load(householdModelPath);
      if (modelData.lengthInBytes == 0) return false;

      return true;
    } catch (_) {
      return false;
    }
  }
}
