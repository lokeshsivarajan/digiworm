import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/disease_result.dart';

class DiseaseDetectionService {
  Interpreter? _interpreter;
  List<String>? _labels;

  // Default disease info mapping (fallback)
  static const Map<String, Map<String, String>> _diseaseInfo = {
    'healthy': {
      'description': 'The plant appears to be healthy with no visible signs of disease.',
      'treatment': 'Continue regular care with proper watering, fertilization, and monitoring.',
    },
    'apple_scab': {
      'description': 'A fungal disease that causes dark, scabby lesions on leaves and fruit.',
      'treatment': 'Apply fungicide sprays during early spring. Remove infected leaves and improve air circulation.',
    },
    'bacterial_spot': {
      'description': 'Bacterial infection causing small, dark spots with yellow halos on leaves.',
      'treatment': 'Use copper-based bactericides. Avoid overhead watering and improve drainage.',
    },
    'early_blight': {
      'description': 'Fungal disease causing brown spots with concentric rings on older leaves.',
      'treatment': 'Apply fungicides containing chlorothalonil or copper. Remove affected plant debris.',
    },
    'late_blight': {
      'description': 'Serious fungal disease causing water-soaked lesions that turn brown and black.',
      'treatment': 'Use preventive fungicides. Ensure good air circulation and avoid wet foliage.',
    },
    'leaf_spot': {
      'description': 'Various fungal or bacterial infections causing circular spots on leaves.',
      'treatment': 'Remove infected leaves, improve air circulation, and apply appropriate fungicides.',
    },
  };

  Future<void> loadModel() async {
    try {
      // Load the actual model from assets
      _interpreter = await Interpreter.fromAsset('assets/models/plant_disease_model.tflite');
      print('✅ Model loaded successfully');
      
      // Load labels from your labels.txt file
      _labels = await _loadLabelsFromFile();
      print('✅ Labels loaded: ${_labels?.length} classes');
      
    } catch (e) {
      print('❌ Model loading failed: $e');
      throw Exception('Failed to load model: $e');
    }
  }

  Future<List<String>> _loadLabelsFromFile() async {
    try {
      final labelsData = await rootBundle.loadString('assets/models/labels.txt');
      return labelsData.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } catch (e) {
      print('❌ Labels loading failed: $e');
      // Return empty list if labels.txt not found
      return [];
    }
  }

  Future<DiseaseResult> detectDisease(File imageFile) async {
    try {
      if (_interpreter == null) {
        throw Exception('Model not loaded. Call loadModel() first.');
      }

      // Preprocess the image
      final processedImage = await _preprocessImage(imageFile);
      
      // Run model inference
      return await _runModelInference(processedImage);
      
    } catch (e) {
      throw Exception('Disease detection failed: $e');
    }
  }

  Future<Float32List> _preprocessImage(File imageFile) async {
    try {
      // Read and decode image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize image to model input size (224x224 is standard)
      image = img.copyResize(image, width: 224, height: 224);

      // Convert to Float32List and normalize to [0, 1]
      final imageData = Float32List(1 * 224 * 224 * 3);
      int pixelIndex = 0;

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = image.getPixel(x, y);
          
          // Normalize pixel values to [0, 1] range
          imageData[pixelIndex++] = img.getRed(pixel) / 255.0;
          imageData[pixelIndex++] = img.getGreen(pixel) / 255.0;
          imageData[pixelIndex++] = img.getBlue(pixel) / 255.0;
        }
      }

      return imageData;
    } catch (e) {
      throw Exception('Image preprocessing failed: $e');
    }
  }

  Future<DiseaseResult> _runModelInference(Float32List processedImage) async {
    try {
      if (_interpreter == null) {
        throw Exception('Model not loaded');
      }

      // Get model input/output details
      final inputTensor = _interpreter!.getInputTensors().first;
      final outputTensor = _interpreter!.getOutputTensors().first;
      
      print('📊 Input shape: ${inputTensor.shape}');
      print('📊 Output shape: ${outputTensor.shape}');

      // Prepare input tensor [1, 224, 224, 3]
      final input = processedImage.reshape([1, 224, 224, 3]);
      
      // Prepare output tensor - adjust size based on your model's output
      final outputSize = outputTensor.shape.reduce((a, b) => a * b);
      final output = List.filled(outputSize, 0.0).reshape([1, outputSize]);

      // Run inference
      _interpreter!.run(input, output);

      // Process results
      final predictions = output[0] as List<double>;
      final maxIndex = predictions.indexOf(predictions.reduce((a, b) => a > b ? a : b));
      final confidence = predictions[maxIndex];

      print('🎯 Prediction: Class $maxIndex, Confidence: ${(confidence * 100).toStringAsFixed(2)}%');

      // Get disease name from labels
      String diseaseName = 'Unknown Disease';
      if (_labels != null && maxIndex < _labels!.length) {
        diseaseName = _labels![maxIndex];
      }

      // Get disease info (fallback to generic info if not found)
      final diseaseKey = diseaseName.toLowerCase().replaceAll(' ', '_');
      final diseaseInfo = _diseaseInfo[diseaseKey] ?? {
        'description': 'Disease detected. Please consult with agricultural expert for detailed information.',
        'treatment': 'Recommended to seek professional agricultural advice for proper treatment.',
      };

      return DiseaseResult(
        diseaseName: diseaseName,
        description: diseaseInfo['description']!,
        treatment: diseaseInfo['treatment']!,
        confidence: confidence,
      );

    } catch (e) {
      throw Exception('Model inference failed: $e');
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}

// Extension to reshape Float32List for tensor operations
extension Float32ListReshape on Float32List {
  List reshape(List<int> shape) {
    if (shape.length == 4) {
      // Reshape to [batch, height, width, channels]
      return [this];
    } else if (shape.length == 2) {
      // Reshape to [batch, classes]  
      final result = <List<double>>[];
      final rowSize = shape[1];
      
      for (int i = 0; i < length; i += rowSize) {
        result.add(sublist(i, i + rowSize).cast<double>());
      }
      return result;
    }
    throw ArgumentError('Unsupported reshape dimensions');
  }
}