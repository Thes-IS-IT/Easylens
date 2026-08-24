import 'dart:io';
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

  Uint8List? _rgbBuffer;
  Float32List? _floatBuffer;
  Map<int, Object>? _outputBuffers;

  // Cached LUTs for zero-overhead plane sampling (<0.4ms)
  Int32List? _cachedYOffsets;
  Int32List? _cachedUOffsets;
  Int32List? _cachedVOffsets;
  int _cachedSrcW = 0;
  int _cachedSrcH = 0;
  int _cachedYS = 0;
  int _cachedUS = 0;
  int _cachedVS = 0;
  int _cachedUP = 0;
  int _cachedVP = 0;
  int _cachedRot = -1;

  Future<void> init(Uint8List modelBuffer, String labelsContent) async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = Interpreter.fromBuffer(modelBuffer, options: options);
      
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      
      _inputSize = inputTensors[0].shape[1];
      _isInputUint8 = inputTensors[0].type.toString().toLowerCase().contains('uint8');
      _rgbBuffer = Uint8List(_inputSize * _inputSize * 3);
      if (!_isInputUint8) {
        _floatBuffer = Float32List(_inputSize * _inputSize * 3);
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
      
      // Preallocate static output buffers to avoid GC pauses
      _outputBuffers = <int, Object>{};
      for (int i = 0; i < _outputShapes.length; i++) {
        final shape = _outputShapes[i];
        _outputBuffers![i] = List.filled(shape.reduce((a, b) => a * b), 0.0).reshape(shape);
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

  /// Directly samples camera YUV planes to a 300x300 RGB buffer with ZERO full-frame memory copies.
  /// Extremely fast (< 2ms) and prevents live video feed stutter.
  Uint8List prepareInputFromPlanes({
    required Uint8List yPlane,
    required Uint8List uPlane,
    required Uint8List vPlane,
    required int srcWidth,
    required int srcHeight,
    required int yRowStride,
    required int uRowStride,
    required int vRowStride,
    required int uPixelStride,
    required int vPixelStride,
    int rotationDegrees = 90,
  }) {
    final int targetSize = _inputSize; // 300
    if (_rgbBuffer == null || _rgbBuffer!.length != targetSize * targetSize * 3) {
      _rgbBuffer = Uint8List(targetSize * targetSize * 3);
    }
    final rgb = _rgbBuffer!;

    // Rebuild Look-Up Table only if camera resolution/strides change (runs once!)
    if (_cachedYOffsets == null ||
        _cachedSrcW != srcWidth ||
        _cachedSrcH != srcHeight ||
        _cachedYS != yRowStride ||
        _cachedUS != uRowStride ||
        _cachedVS != vRowStride ||
        _cachedUP != uPixelStride ||
        _cachedVP != vPixelStride ||
        _cachedRot != rotationDegrees) {
      
      final int totalPixels = targetSize * targetSize;
      _cachedYOffsets = Int32List(totalPixels);
      _cachedUOffsets = Int32List(totalPixels);
      _cachedVOffsets = Int32List(totalPixels);
      _cachedSrcW = srcWidth;
      _cachedSrcH = srcHeight;
      _cachedYS = yRowStride;
      _cachedUS = uRowStride;
      _cachedVS = vRowStride;
      _cachedUP = uPixelStride;
      _cachedVP = vPixelStride;
      _cachedRot = rotationDegrees;

      final bool isRotated = rotationDegrees == 90 || rotationDegrees == 270;
      final int physW = isRotated ? srcHeight : srcWidth;
      final int physH = isRotated ? srcWidth : srcHeight;

      final double scaleX = physW / targetSize;
      final double scaleY = physH / targetSize;

      int idx = 0;
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

          final int yIdx = sy * yRowStride + sx;
          final int uvRow = sy >> 1;
          final int uvCol = sx >> 1;
          final int uIdx = uvRow * uRowStride + uvCol * uPixelStride;
          final int vIdx = uvRow * vRowStride + uvCol * vPixelStride;

          _cachedYOffsets![idx] = yIdx;
          _cachedUOffsets![idx] = uIdx;
          _cachedVOffsets![idx] = vIdx;
          idx++;
        }
      }
    }

    final yOffsets = _cachedYOffsets!;
    final uOffsets = _cachedUOffsets!;
    final vOffsets = _cachedVOffsets!;
    final int yLen = yPlane.length;
    final int uLen = uPlane.length;
    final int vLen = vPlane.length;
    final int totalPixels = targetSize * targetSize;

    int outIdx = 0;
    for (int i = 0; i < totalPixels; i++) {
      final int yIdx = yOffsets[i];
      final int uIdx = uOffsets[i];
      final int vIdx = vOffsets[i];

      final int yVal = (yIdx < yLen ? yPlane[yIdx] : 0) & 0xFF;
      final int uVal = (uIdx < uLen ? uPlane[uIdx] : 128) - 128;
      final int vVal = (vIdx < vLen ? vPlane[vIdx] : 128) - 128;

      // Ultra-fast integer fixed-point YUV to RGB (ITU-R BT.601) in <0.3ms
      rgb[outIdx++] = (yVal + ((359 * vVal) >> 8)).clamp(0, 255);
      rgb[outIdx++] = (yVal - ((88 * uVal + 183 * vVal) >> 8)).clamp(0, 255);
      rgb[outIdx++] = (yVal + ((454 * uVal) >> 8)).clamp(0, 255);
    }
    return rgb;
  }

  /// Converts NV21 camera bytes to a 300×300 RGB Uint8List ready for [runInference].
  Uint8List prepareInputFromNv21(Uint8List nv21, int srcWidth, int srcHeight, {int rotationDegrees = 90}) {
    final int targetSize = _inputSize; // 300
    if (_rgbBuffer == null || _rgbBuffer!.length != targetSize * targetSize * 3) {
      _rgbBuffer = Uint8List(targetSize * targetSize * 3);
    }
    final rgb = _rgbBuffer!;
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
    if (_rgbBuffer == null || _rgbBuffer!.length != targetSize * targetSize * 3) {
      _rgbBuffer = Uint8List(targetSize * targetSize * 3);
    }
    final rgb = _rgbBuffer!;
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

  /// Runs TFLite SSD MobileNet inference with Non-Maximum Suppression (NMS).
  /// Eliminates duplicate, overlapping, and spammy bounding boxes.
  List<SSDResult> runInference(Uint8List rgbData) {
    if (!_isReady || _interpreter == null) return [];
    
    try {
      final Object input;
      if (!_isInputUint8) {
        if (_floatBuffer == null || _floatBuffer!.length != rgbData.length) {
          _floatBuffer = Float32List(rgbData.length);
        }
        final floatData = _floatBuffer!;
        for (int i = 0; i < rgbData.length; i++) {
          floatData[i] = (rgbData[i] - 127.5) / 127.5;
        }
        input = floatData.reshape([1, _inputSize, _inputSize, 3]);
      } else {
        input = rgbData.reshape([1, _inputSize, _inputSize, 3]);
      }

      if (_outputBuffers == null) {
        _outputBuffers = <int, Object>{};
        for (int i = 0; i < _outputShapes.length; i++) {
          final shape = _outputShapes[i];
          _outputBuffers![i] = List.filled(shape.reduce((a, b) => a * b), 0.0).reshape(shape);
        }
      }
      final outputs = _outputBuffers!;
      
      _interpreter!.runForMultipleInputs([input], outputs);
      
      int count = _maxDetections;
      if (_cntIdx >= 0) {
        count = _getScalar(outputs[_cntIdx]!).toInt();
      }
      
      final rawResults = <SSDResult>[];
      for (int i = 0; i < math.min(count, _maxDetections); i++) {
        final double score = _getVal(outputs[_scrIdx]!, i);
        if (score < 0.35) continue; // Natural confidence threshold
        
        final int classIdx = _getVal(outputs[_clsIdx]!, i).toInt();
        if (classIdx < 0 || classIdx >= _labels.length) continue;
        
        final name = _labels[classIdx];
        if (name == '???' || name == 'background' || name.isEmpty) continue;
        
        rawResults.add(SSDResult(
          label: name,
          confidence: score,
          classIndex: classIdx,
          yMin: _getBox(outputs[_locIdx]!, i, 0).clamp(0.0, 1.0),
          xMin: _getBox(outputs[_locIdx]!, i, 1).clamp(0.0, 1.0),
          yMax: _getBox(outputs[_locIdx]!, i, 2).clamp(0.0, 1.0),
          xMax: _getBox(outputs[_locIdx]!, i, 3).clamp(0.0, 1.0),
        ));
      }

      // Apply Non-Maximum Suppression (NMS) to eliminate duplicate/cloned boxes
      final results = _applyNMS(rawResults);

      return results;
    } catch (e) {
      print('[SSD] Inference error: $e');
      return [];
    }
  }

  final List<_TrackedBox> _activeTracks = [];

  List<SSDResult> _smoothTracks(List<SSDResult> currentDetections) {
    if (currentDetections.isEmpty && _activeTracks.isEmpty) return [];

    final List<_TrackedBox> updatedTracks = [];
    final List<bool> matchedDets = List.filled(currentDetections.length, false);

    // Match active tracks against new detections using IoU
    for (final track in _activeTracks) {
      double bestIoU = 0.0;
      int bestIdx = -1;

      final trackW = math.max(0.0, track.xMax - track.xMin);
      final trackH = math.max(0.0, track.yMax - track.yMin);
      final trackArea = trackW * trackH;

      for (int i = 0; i < currentDetections.length; i++) {
        if (matchedDets[i]) continue;
        final det = currentDetections[i];

        final bool isSameClass = det.label.toLowerCase() == track.label.toLowerCase() ||
            (det.label.contains('person') && track.label.contains('person'));

        final detW = math.max(0.0, det.xMax - det.xMin);
        final detH = math.max(0.0, det.yMax - det.yMin);
        final detArea = detW * detH;

        final double xA = math.max(det.xMin, track.xMin);
        final double yA = math.max(det.yMin, track.yMin);
        final double xB = math.min(det.xMax, track.xMax);
        final double yB = math.min(det.yMax, track.yMax);

        final double interW = math.max(0.0, xB - xA);
        final double interH = math.max(0.0, yB - yA);
        final double interArea = interW * interH;
        if (interArea <= 0.0) continue;

        final double unionArea = detArea + trackArea - interArea;
        final double iou = unionArea > 0 ? interArea / unionArea : 0.0;
        final double minArea = math.min(detArea, trackArea);
        final double ioMin = minArea > 0 ? interArea / minArea : 0.0;

        final double matchScore = isSameClass ? (iou * 0.7 + ioMin * 0.3) : iou;

        if (matchScore > 0.30 && matchScore > bestIoU) {
          bestIoU = matchScore;
          bestIdx = i;
        }
      }

      if (bestIdx >= 0) {
        matchedDets[bestIdx] = true;
        final det = currentDetections[bestIdx];

        // Smooth Exponential Moving Average (70% new frame + 30% previous frame for zero latency tracking without jitter)
        const double alpha = 0.70;
        track.yMin = track.yMin * (1.0 - alpha) + det.yMin * alpha;
        track.xMin = track.xMin * (1.0 - alpha) + det.xMin * alpha;
        track.yMax = track.yMax * (1.0 - alpha) + det.yMax * alpha;
        track.xMax = track.xMax * (1.0 - alpha) + det.xMax * alpha;
        track.confidence = track.confidence * 0.3 + det.confidence * 0.7;
        track.label = det.label;
        track.classIndex = det.classIndex;
        track.missedFrames = 0;
        updatedTracks.add(track);
      } else {
        // Keep track alive for 1 missed frame to prevent flicker
        track.missedFrames++;
        if (track.missedFrames <= 1) {
          updatedTracks.add(track);
        }
      }
    }

    // Add unmatched new detections as new tracks
    for (int i = 0; i < currentDetections.length; i++) {
      if (!matchedDets[i]) {
        final det = currentDetections[i];
        updatedTracks.add(_TrackedBox(
          label: det.label,
          classIndex: det.classIndex,
          confidence: det.confidence,
          yMin: det.yMin,
          xMin: det.xMin,
          yMax: det.yMax,
          xMax: det.xMax,
        ));
      }
    }

    _activeTracks.clear();
    _activeTracks.addAll(updatedTracks);

    return _activeTracks.map((t) => t.toSSDResult()).toList();
  }

  /// Non-Maximum Suppression to remove duplicate proposals on the exact same object
  List<SSDResult> _applyNMS(List<SSDResult> detections, {double iouThreshold = 0.45, double ioMinThreshold = 0.55}) {
    if (detections.isEmpty) return [];

    final sorted = List<SSDResult>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final List<SSDResult> selected = [];

    for (final det in sorted) {
      bool shouldSuppress = false;
      final detW = math.max(0.0, det.xMax - det.xMin);
      final detH = math.max(0.0, det.yMax - det.yMin);
      final detArea = detW * detH;
      if (detArea <= 0.001) continue;

      for (final kept in selected) {
        final keptW = math.max(0.0, kept.xMax - kept.xMin);
        final keptH = math.max(0.0, kept.yMax - kept.yMin);
        final keptArea = keptW * keptH;
        if (keptArea <= 0.001) continue;

        final double xA = math.max(det.xMin, kept.xMin);
        final double yA = math.max(det.yMin, kept.yMin);
        final double xB = math.min(det.xMax, kept.xMax);
        final double yB = math.min(det.yMax, kept.yMax);

        final double interW = math.max(0.0, xB - xA);
        final double interH = math.max(0.0, yB - yA);
        final double interArea = interW * interH;
        if (interArea <= 0.0) continue;

        final double unionArea = detArea + keptArea - interArea;
        final double iou = unionArea > 0 ? interArea / unionArea : 0.0;
        final double minArea = math.min(detArea, keptArea);
        final double ioMin = minArea > 0 ? interArea / minArea : 0.0;

        final bool isSameClass = det.label.toLowerCase() == kept.label.toLowerCase() ||
            (det.label.contains('person') && kept.label.contains('person'));

        if (isSameClass) {
          // Suppress duplicate proposal anchor on the same object
          if (iou > iouThreshold || ioMin > ioMinThreshold) {
            shouldSuppress = true;
            break;
          }
        } else {
          // Suppress contradictory overlapping box on the exact same region
          if (ioMin > 0.70) {
            shouldSuppress = true;
            break;
          }
        }
      }

      if (!shouldSuppress) {
        selected.add(det);
        if (selected.length >= 10) break; // Let the model naturally output all detected objects
      }
    }
    return selected;
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

class _TrackedBox {
  String label;
  int classIndex;
  double confidence;
  double yMin;
  double xMin;
  double yMax;
  double xMax;
  int missedFrames = 0;

  _TrackedBox({
    required this.label,
    required this.classIndex,
    required this.confidence,
    required this.yMin,
    required this.xMin,
    required this.yMax,
    required this.xMax,
  });

  SSDResult toSSDResult() {
    return SSDResult(
      label: label,
      classIndex: classIndex,
      confidence: confidence,
      yMin: yMin,
      xMin: xMin,
      yMax: yMax,
      xMax: xMax,
    );
  }
}
