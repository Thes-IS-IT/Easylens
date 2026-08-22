import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'tflite_processor.dart';

/// Manages the TFLite inference in a background isolate.
/// Handles image processing (YUV to RGB) and SSD inference.
class IsolateRunner {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  final ReceivePort _replyPort = ReceivePort();
  Completer<List<SSDResult>>? _pendingCompleter;
  bool _isReady = false;

  Future<void> init(Uint8List modelBuffer, String labelsContent) async {
    _isolate = await Isolate.spawn(_worker, [
      _receivePort.sendPort,
      modelBuffer,
      labelsContent
    ]);
    
    final res = await _receivePort.first;
    if (res is SendPort) {
      _sendPort = res;
      _isReady = true;

      // Listen on persistent zero-latency reply port
      _replyPort.listen((dynamic data) {
        if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
          if (data is List) {
            final results = data.map((m) => SSDResult.fromMap(m as Map<String, dynamic>)).toList();
            _pendingCompleter!.complete(results);
          } else {
            _pendingCompleter!.complete([]);
          }
          _pendingCompleter = null;
        }
      });

      print('[Isolate] SSD Isolate Worker ready with zero-latency channel');
    } else {
      _isReady = false;
      print('[Isolate] SSD Isolate Worker failed to initialize');
    }
  }

  Future<List<SSDResult>> runInferenceRgb(Uint8List rgbData) async {
    if (!_isReady || _sendPort == null) return [];
    if (_pendingCompleter != null) {
      // Isolate is currently busy executing previous frame, skip this frame to prevent lag queueing
      return [];
    }

    final completer = Completer<List<SSDResult>>();
    _pendingCompleter = completer;

    _sendPort!.send({
      'cmd': 'runRgb',
      'rgb': rgbData,
      'replyTo': _replyPort.sendPort,
    });

    return completer.future;
  }

  Future<List<SSDResult>> runInference({
    required Uint8List y,
    required Uint8List u,
    required Uint8List v,
    required int width,
    required int height,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    required int targetSize,
    required int rotation,
  }) async {
    if (!_isReady || _sendPort == null) return [];

    final response = ReceivePort();
    _sendPort!.send({
      'cmd': 'run',
      'y': y, 'u': u, 'v': v,
      'w': width, 'h': height,
      'yS': yRowStride, 'uvS': uvRowStride, 'uvP': uvPixelStride,
      'tS': targetSize,
      'rot': rotation,
      'replyTo': response.sendPort,
    });

    final dynamic data = await response.first;
    response.close();

    if (data is List) {
      return data.map((m) => SSDResult.fromMap(m as Map<String, dynamic>)).toList();
    }
    return [];
  }

  void close() {
    _sendPort?.send({'cmd': 'close'});
    _isolate?.kill();
    _isReady = false;
  }

  bool get isReady => _isReady;

  static void _worker(List<dynamic> args) async {
    final mainSend = args[0] as SendPort;
    try {
      final modelBuffer = args[1] as Uint8List;
      final labelsContent = args[2] as String;
      
      final processor = TfliteProcessor();
      await processor.init(modelBuffer, labelsContent);
      
      final port = ReceivePort();
      mainSend.send(port.sendPort);
      
      Uint8List? workerRgbBuffer;

      port.listen((msg) async {
        try {
          final cmd = msg['cmd'];
          if (cmd == 'close') {
            processor.dispose();
          } else if (cmd == 'runRgb') {
            final replyTo = msg['replyTo'] as SendPort;
            final Uint8List rgb = msg['rgb'] as Uint8List;
            final results = processor.runInference(rgb);
            replyTo.send(results.map((r) => r.toMap()).toList());
          } else if (cmd == 'run') {
            final replyTo = msg['replyTo'] as SendPort;
            final int tS = msg['tS'];
            final int rot = msg['rot'] ?? 90;
            
            if (workerRgbBuffer == null || workerRgbBuffer!.length != tS * tS * 3) {
              workerRgbBuffer = Uint8List(tS * tS * 3);
            }

            // 1. Process YUV to RGB (with built in rotation mapping)
            final rgb = _yuvToRgb(
              msg['y'], msg['u'], msg['v'], 
              msg['w'], msg['h'], 
              msg['yS'], msg['uvS'], msg['uvP'], 
              tS, rot,
              workerRgbBuffer!,
            );
            
            // 2. Run SSD
            final results = processor.runInference(rgb);
            // 3. Send results as Maps (Classes don't survive isolate transfer)
            replyTo.send(results.map((r) => r.toMap()).toList());
          }
        } catch (e) {
          print('[Isolate Worker Loop] Error: $e');
        }
      });
    } catch (e) {
      print('[Isolate Worker Init] Error: $e');
      mainSend.send(null);
    }
  }

  static Uint8List _yuvToRgb(Uint8List yP, Uint8List uP, Uint8List vP, 
      int w, int h, int yS, int uvS, int uvP, int tS, int rotation, Uint8List rgb) {
    int idx = 0;
    
    // The target is always tS x tS (300x300).
    // We map a destination pixel (px, py) to the source raw sensor pixel (sX, sY).
    
    // If rotated 90 or 270, the physical aspect ratio is height x width.
    final bool isRotated = rotation == 90 || rotation == 270;
    final int physW = isRotated ? h : w;
    final int physH = isRotated ? w : h;
    
    final double scaleX = physW / tS;
    final double scaleY = physH / tS;

    for (int py = 0; py < tS; py++) {
      for (int px = 0; px < tS; px++) {
        // 1. Map target grid (px, py) to physical unscaled coordinates (pX, pY)
        final int pX = (px * scaleX).toInt();
        final int pY = (py * scaleY).toInt();
        
        // 2. Un-rotate physical coordinates to raw sensor coordinates (sX, sY)
        int sX, sY;
        if (rotation == 90) {
          sX = pY;
          sY = h - pX - 1;
        } else if (rotation == 180) {
          sX = w - pX - 1;
          sY = h - pY - 1;
        } else if (rotation == 270) {
          sX = w - pY - 1;
          sY = pX;
        } else { // 0 or default
          sX = pX;
          sY = pY;
        }
        
        // Clamp to prevent out of bounds due to rounding
        sX = sX.clamp(0, w - 1);
        sY = sY.clamp(0, h - 1);

        // 3. Extract YUV values
        final int yOff = sY * yS;
        final int uvROff = (sY >> 1) * uvS;
        
        final int yv = yP[yOff + sX];
        final int uvIdx = uvROff + (sX >> 1) * uvP;
        
        // Safety checks for indices out of range
        final int upVal = uvIdx < uP.length ? uP[uvIdx] : 128;
        final int vpVal = uvIdx < vP.length ? vP[uvIdx] : 128;
        
        final int up = upVal - 128;
        final int vp = vpVal - 128; // U and V planes are typically sub-sampled by 2
        
        // 4. Convert to RGB
        int r = (yv + ((359 * vp) >> 8)).clamp(0, 255);
        int g = (yv - ((88 * up + 183 * vp) >> 8)).clamp(0, 255);
        int b = (yv + ((454 * up) >> 8)).clamp(0, 255);
        
        rgb[idx++] = r;
        rgb[idx++] = g;
        rgb[idx++] = b;
      }
    }
    return rgb;
  }
}
