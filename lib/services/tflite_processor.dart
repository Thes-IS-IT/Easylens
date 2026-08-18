import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

class TfliteProcessor {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isReady = false;
  
  // Model info
  int _inputSize = 300;
  bool _isInputUint8 = true;
  
  // Output mapping
  int _locIdx = -1;
  int _clsIdx = -1;
  int _scrIdx = -1;
  int _cntIdx = -1;
  int _maxDetections = 10;
  List<List<int>> _outputShapes = [];

  Future<void> init(Uint8List modelBuffer, String labelsContent) async {
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = Interpreter.fromBuffer(modelBuffer, options: options);
      
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      
      _inputSize = inputTensors[0].shape[1];
      _isInputUint8 = inputTensors[0].type.toString().toLowerCase().contains('uint8');
      
      _outputShapes = [];
      _locIdx = -1;
      _clsIdx = -1;
      _scrIdx = -1;
      _cntIdx = -1;

      for (int i = 0; i < outputTensors.length; i++) {
        _outputShapes.add(outputTensors[i].shape);
        final s = outputTensors[i].shape;
        if (s.length == 3 && s.last == 4) {
          _locIdx = i;
          _maxDetections = s[1];
        } else if (s.length == 1 || (s.length == 2 && s[1] == 1)) {
          _cntIdx = i;
        }
      }
      
      for (int i = 0; i < _outputShapes.length; i++) {
        if (i == _locIdx || i == _cntIdx) continue;
        if (_clsIdx == -1) {
          _clsIdx = i;
        } else if (_scrIdx == -1) {
          _scrIdx = i;
        }
      }

      if (_locIdx == -1 || _clsIdx == -1 || _scrIdx == -1 || _cntIdx == -1) {
        if (outputTensors.length >= 4) {
          _locIdx = 0;
          _clsIdx = 1;
          _scrIdx = 2;
          _cntIdx = 3;
          _maxDetections = 10;
          if (outputTensors.isNotEmpty && outputTensors[0].shape.length >= 2) {
            _maxDetections = outputTensors[0].shape[1];
          }
        } else {
          _interpreter?.close();
          _interpreter = null;
          return;
        }
      }
      
      _labels = labelsContent.split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.replaceFirst(RegExp(r'^\d+\s*'), '').trim())
          .toList();
          
      _isReady = true;
      print('[SSD] TFLite Processor ready. Labels count: ${_labels.length}, Input size: $_inputSize');
    } catch (e) {
      print('[SSD] Init error: $e');
    }
  }

  bool get isReady => _isReady;
  int get inputSize => _inputSize;

  /// Converts NV21 camera bytes to a 300×300 RGB Uint8List ready for [runInference].
  /// Applies rotation mapping (90° clockwise for standard Android portrait camera)
  /// so the neural network processes upright images for highly accurate object classifications.
  Uint8List prepareInputFromNv21(Uint8List nv21, int srcWidth, int srcHeight, {int rotationDegrees = 90}) {
    final int targetSize = _inputSize; // 300
    final rgb = Uint8List(targetSize * targetSize * 3);
    final int uvStart = srcWidth * srcHeight;

    final bool isRotated = rotationDegrees == 90 || rotationDegrees == 270;
    final int physW = isRotated ? srcHeight : srcWidth;
    final int physH = isRotated ? srcWidth : srcHeight;

    final double scaleX = physW / targetSize;
    final double scaleY = physH / targetSize;

    int outIdx = 0;
    for (int ty = 0; ty < targetSize; ty++) {
      for (int tx = 0; tx < targetSize; tx++) {
        final int px = (tx * scaleX).toInt();
        final int py = (ty * scaleY).toInt();

        int sx, sy;
        if (rotationDegrees == 90) {
          sx = py;
          sy = srcHeight - px - 1;
        } else if (rotationDegrees == 180) {
          sx = srcWidth - px - 1;
          sy = srcHeight - py - 1;
        } else if (rotationDegrees == 270) {
          sx = srcWidth - py - 1;
          sy = px;
        } else {
          sx = px;
          sy = py;
        }

        sx = sx.clamp(0, srcWidth - 1);
        sy = sy.clamp(0, srcHeight - 1);

        final int yVal = nv21[sy * srcWidth + sx] & 0xFF;
        final int uvCol = (sx >> 1) << 1;
        final int uvIdx = uvStart + (sy >> 1) * srcWidth + uvCol;

        // In standard NV21, V precedes U: [V0, U0, V1, U1...]
        final int vVal = (uvIdx < nv21.length ? nv21[uvIdx] : 128) - 128;
        final int uVal = (uvIdx + 1 < nv21.length ? nv21[uvIdx + 1] : 128) - 128;

        // Fast integer fixed-point YUV to RGB (ITU-R BT.601)
        final int r = (yVal + ((359 * vVal) >> 8)).clamp(0, 255);
        final int g = (yVal - ((88 * uVal + 183 * vVal) >> 8)).clamp(0, 255);
        final int b = (yVal + ((454 * uVal) >> 8)).clamp(0, 255);

        rgb[outIdx++] = r;
        rgb[outIdx++] = g;
        rgb[outIdx++] = b;
      }
    }
    return rgb;
  }

  /// Converts JPG image bytes (e.g. from ESP32-CAM stream) to a 300×300 RGB Uint8List.
  Uint8List prepareInputFromJpg(Uint8List jpgBytes) {
    final int targetSize = _inputSize; // 300
    final rgb = Uint8List(targetSize * targetSize * 3);
    try {
      final img.Image? decoded = img.decodeJpg(jpgBytes);
      if (decoded == null) return rgb;

      final img.Image resized = img.copyResize(decoded, width: targetSize, height: targetSize);

      int idx = 0;
      for (int y = 0; y < targetSize; y++) {
        for (int x = 0; x < targetSize; x++) {
          final pixel = resized.getPixel(x, y);
          rgb[idx++] = pixel.r.toInt();
          rgb[idx++] = pixel.g.toInt();
          rgb[idx++] = pixel.b.toInt();
        }
      }
    } catch (e) {
      print('[SSD] Error decoding JPG input: $e');
    }
    return rgb;
  }

  List<SSDResult> runInference(Uint8List rgbData) {
    if (!_isReady || _interpreter == null) return [];
    
    try {
      final Object input;
      if (!_isInputUint8) {
        final floatData = Float32List(rgbData.length);
        for (int i = 0; i < rgbData.length; i++) {
          floatData[i] = (rgbData[i] - 127.5) / 127.5;
        }
        input = floatData.reshape([1, _inputSize, _inputSize, 3]);
      } else {
        input = rgbData.reshape([1, _inputSize, _inputSize, 3]);
      }
      final outputs = <int, Object>{};
      
      for (int i = 0; i < _outputShapes.length; i++) {
        final shape = _outputShapes[i];
        outputs[i] = List.filled(shape.reduce((a, b) => a * b), 0.0).reshape(shape);
      }
      
      _interpreter!.runForMultipleInputs([input], outputs);
      
      int count = _maxDetections;
      if (_cntIdx >= 0) {
        count = _getScalar(outputs[_cntIdx]!).toInt();
      }
      
      final results = <SSDResult>[];
      for (int i = 0; i < math.min(count, _maxDetections); i++) {
        final double score = _getVal(outputs[_scrIdx]!, i);
        if (score < 0.25) continue; // standard threshold
        
        final int classIdx = _getVal(outputs[_clsIdx]!, i).toInt();
        if (classIdx < 0 || classIdx >= _labels.length) continue;
        
        final name = _labels[classIdx];
        if (name == '???' || name == 'background' || name.isEmpty) continue;
        
        results.add(SSDResult(
          label: name,
          confidence: score,
          classIndex: classIdx,
          yMin: _getBox(outputs[_locIdx]!, i, 0).clamp(0.0, 1.0),
          xMin: _getBox(outputs[_locIdx]!, i, 1).clamp(0.0, 1.0),
          yMax: _getBox(outputs[_locIdx]!, i, 2).clamp(0.0, 1.0),
          xMax: _getBox(outputs[_locIdx]!, i, 3).clamp(0.0, 1.0),
        ));
      }

      if (results.isNotEmpty) {
        print('[SSD] Detected: ${results.map((r) => "${r.label}(${(r.confidence*100).toInt()}%)").join(", ")}');
      }

      return results;
    } catch (e) {
      print('[SSD] Inference error: $e');
      return [];
    }
  }

  double _getScalar(Object t) {
    try {
      if (t is List) {
        var v = t;
        while (v.isNotEmpty) {
          final first = v[0];
          if (first is List) {
            v = first;
          } else {
            return (first as num).toDouble();
          }
        }
      } else if (t is num) {
        return t.toDouble();
      }
    } catch (_) {}
    return 0.0;
  }

  double _getVal(Object t, int i) {
    try {
      if (t is List) {
        if (t.isEmpty) return 0.0;
        final first = t[0];
        if (first is List) {
          if (i < first.length) {
            final val = first[i];
            if (val is List) {
              return (val[0] as num).toDouble();
            }
            return (val as num).toDouble();
          }
        } else {
          if (i < t.length) {
            return (t[i] as num).toDouble();
          }
        }
      } else if (t is num) {
        return t.toDouble();
      }
    } catch (_) {}
    return 0.0;
  }

  double _getBox(Object t, int i, int c) {
    try {
      if (t is List) {
        if (t.isEmpty) return 0.0;
        final first = t[0];
        if (first is List) {
          if (i < first.length) {
            final second = first[i];
            if (second is List) {
              if (c < second.length) {
                return (second[c] as num).toDouble();
              }
            } else {
              return (second as num).toDouble();
            }
          }
        }
      }
    } catch (_) {}
    return 0.0;
  }
  
  void dispose() {
    _interpreter?.close();
  }
}

class SSDResult {
  final String label;
  final double confidence;
  final int classIndex;
  final double yMin, xMin, yMax, xMax;

  SSDResult({
    required this.label,
    required this.confidence,
    required this.classIndex,
    required this.yMin,
    required this.xMin,
    required this.yMax,
    required this.xMax,
  });

  Map<String, dynamic> toMap() => {
    'label': label,
    'conf': confidence,
    'idx': classIndex,
    'y1': yMin, 'x1': xMin, 'y2': yMax, 'x2': xMax,
  };

  factory SSDResult.fromMap(Map<String, dynamic> m) => SSDResult(
    label: m['label'],
    confidence: m['conf'],
    classIndex: m['idx'],
    yMin: m['y1'], xMin: m['x1'], yMax: m['y2'], xMax: m['x2'],
  );
}
