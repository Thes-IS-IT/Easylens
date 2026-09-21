import 'dart:typed_data';
import 'package:image/image.dart' as img;

class YuvData {
  final Uint8List yBytes;
  final Uint8List uBytes;
  final Uint8List vBytes;
  final int width;
  final int height;
  final int yRowStride;
  final int uRowStride;
  final int vRowStride;
  final int uPixelStride;
  final int vPixelStride;

  YuvData({
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.width,
    required this.height,
    required this.yRowStride,
    required this.uRowStride,
    required this.vRowStride,
    required this.uPixelStride,
    required this.vPixelStride,
  });
}

Uint8List convertYuvToNv21(YuvData data) {
  final width = data.width;
  final height = data.height;
  final yBuffer = data.yBytes;

  final numPixels = width * height;
  final nv21 = Uint8List(numPixels + (width * height ~/ 2));

  int idY = 0;
  for (int row = 0; row < height; row++) {
    nv21.setRange(idY, idY + width, yBuffer, row * data.yRowStride);
    idY += width;
  }

  final int uvWidth = width ~/ 2;
  final int uvHeight = height ~/ 2;
  final int uPixelStride = data.uPixelStride;
  final int vPixelStride = data.vPixelStride;
  final int uRowStride = data.uRowStride;
  final int vRowStride = data.vRowStride;

  int idUV = numPixels;
  for (int row = 0; row < uvHeight; row++) {
    for (int col = 0; col < uvWidth; col++) {
      nv21[idUV++] = data.vBytes[row * vRowStride + col * vPixelStride];
      nv21[idUV++] = data.uBytes[row * uRowStride + col * uPixelStride];
    }
  }
  return nv21;
}

// Top-level function required by Flutter's compute() isolate.
// Renamed from _nv21ToJpegInIsolate (was file-private) to be accessible
// from hardware_screen.dart after extraction. Logic is 100% identical.
Uint8List? nv21ToJpegInIsolate(Map<String, dynamic> params) {
  try {
    final Uint8List nv21 = params['nv21'];
    final int width = params['width'];
    final int height = params['height'];

    final img.Image image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int yValue = nv21[yIndex] & 0xff;
        image.setPixelRgb(x, y, yValue, yValue, yValue);
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 75));
  } catch (_) {
    return null;
  }
}
