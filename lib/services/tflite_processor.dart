import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

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
      
      print('[SSD] Output tensors:');
      for (int i = 0; i < outputTensors.length; i++) {
        print('[SSD Output Tensor $i] shape=${outputTensors[i].shape}, type=${outputTensors[i].type}');
      }
      
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
          print('[SSD] Shape-based indexing failed. Falling back to standard order (0, 1, 2, 3).');
          _locIdx = 0;
          _clsIdx = 1;
          _scrIdx = 2;
          _cntIdx = 3;
          _maxDetections = 10;
          if (outputTensors.isNotEmpty && outputTensors[0].shape.length >= 2) {
            _maxDetections = outputTensors[0].shape[1];
          }
        } else {
          print('[SSD] Model has ${outputTensors.length} outputs — not a valid SSD model. Aborting init.');
          _interpreter?.close();
          _interpreter = null;
          return;
        }
      }
      print('[SSD] Mapped output indexes: loc=$_locIdx, cls=$_clsIdx, scr=$_scrIdx, cnt=$_cntIdx');
      
      _labels = labelsContent.split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.replaceFirst(RegExp(r'^\d+\s*'), '').trim())
          .toList();
          
      _isReady = true;
      print('[SSD] TFLite Processor ready. Input size: $_inputSize');
    } catch (e) {
      print('[SSD] Init error: $e');
    }
  }

  bool get isReady => _isReady;
  int get inputSize => _inputSize;

  /// Converts NV21 camera bytes to a 300×300 RGB Uint8List ready for [runInference].
  /// Performs downsampling inline without the `image` package.
  Uint8List prepareInputFromNv21(Uint8List nv21, int srcWidth, int srcHeight) {
    final int targetSize = _inputSize; // 300
    final rgb = Uint8List(targetSize * targetSize * 3);
    final int uvStart = srcWidth * srcHeight;

    for (int ty = 0; ty < targetSize; ty++) {
      final int sy = (ty * srcHeight) ~/ targetSize;
      for (int tx = 0; tx < targetSize; tx++) {
        final int sx = (tx * srcWidth) ~/ targetSize;

        // Y plane
        final int yVal = nv21[sy * srcWidth + sx] & 0xFF;

        // UV plane (interleaved V, U) — NV21 layout
        final int uvRow = sy >> 1;
        final int uvCol = (sx >> 1) << 1; // even-aligned
        final int uvIdx = uvStart + uvRow * srcWidth + uvCol;
        final int v = (uvIdx < nv21.length ? nv21[uvIdx] : 128) & 0xFF;
        final int u = (uvIdx + 1 < nv21.length ? nv21[uvIdx + 1] : 128) & 0xFF;

        // YUV → RGB
        int r = (yVal + 1.370705 * (v - 128)).round().clamp(0, 255);
        int g = (yVal - 0.337633 * (u - 128) - 0.698001 * (v - 128)).round().clamp(0, 255);
        int b = (yVal + 1.732446 * (u - 128)).round().clamp(0, 255);

        final int outIdx = (ty * targetSize + tx) * 3;
        rgb[outIdx] = r;
        rgb[outIdx + 1] = g;
        rgb[outIdx + 2] = b;
      }
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
      double maxScore = 0.0;
      String maxLabel = 'none';

      for (int i = 0; i < math.min(count, _maxDetections); i++) {
        final double score = _getVal(outputs[_scrIdx]!, i);
        if (score > maxScore) {
          maxScore = score;
          final int tempIdx = _getVal(outputs[_clsIdx]!, i).toInt();
          if (tempIdx >= 0 && tempIdx < _labels.length) maxLabel = _labels[tempIdx];
        }

        if (score < 0.15) continue; // standard threshold
        
        final int classIdx = _getVal(outputs[_clsIdx]!, i).toInt();
        if (classIdx <= 0 || classIdx >= _labels.length) continue;
        
        final name = _labels[classIdx];
        if (name == '???' || name.isEmpty) continue;
        
        results.add(SSDResult(
          label: name,
          confidence: score,
          classIndex: classIdx,
          yMin: _getBox(outputs[_locIdx]!, i, 0),
          xMin: _getBox(outputs[_locIdx]!, i, 1),
          yMax: _getBox(outputs[_locIdx]!, i, 2),
          xMax: _getBox(outputs[_locIdx]!, i, 3),
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
        while (v is List && v.isNotEmpty) {
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
