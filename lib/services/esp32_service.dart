// lib/services/esp32_service.dart
// Real ESP32-CAM WiFi connectivity service for EasyLens.
//
// The ESP32 runs as a WiFi Access Point (SSID: "EasyLens-Camera", open).
// The phone connects to that AP, then streams MJPEG from:
//   http://192.168.4.1:81/stream
// Flash LED toggle:
//   GET http://192.168.4.1:81/led?val=1   (on)
//   GET http://192.168.4.1:81/led?val=0   (off)

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';

class Esp32Service extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final Esp32Service _instance = Esp32Service._internal();
  factory Esp32Service() => _instance;
  Esp32Service._internal();

  // ── Default endpoints (from firmware esp32_cam_wifi_ap.ino) ─────────────
  static const String defaultStreamUrl = 'http://192.168.4.1:81/stream';
  static const String defaultBaseUrl = 'http://192.168.4.1:81';
  static const String defaultSsid = 'EasyLens-Camera';

  static const String _prefStreamUrl = 'esp32_stream_url';

  // ── State ─────────────────────────────────────────────────────────────────
  String _streamUrl = defaultStreamUrl;
  String get streamUrl => _streamUrl;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String _statusMessage = 'Not connected';
  String get statusMessage => _statusMessage;

  bool _flashOn = false;
  bool get flashOn => _flashOn;

  // Live MJPEG frame bytes
  Uint8List? _currentFrame;
  Uint8List? get currentFrame => _currentFrame;

  StreamSubscription? _streamSub;
  final List<int> _buffer = [];
  http.Client? _httpClient;

  // ── Initialization ───────────────────────────────────────────────────────
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefStreamUrl);
    if (saved != null) {
      _streamUrl = saved;
    }
  }

  Future<void> saveStreamUrl(String url) async {
    _streamUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefStreamUrl, url);
    notifyListeners();
  }

  // ── Connection ──────────────────────────────────────────────────────────

  /// Connect to the ESP32-CAM MJPEG stream.
  Future<bool> connect({String? url}) async {
    if (_isConnecting) return false;

    final target = url ?? _streamUrl;
    await disconnect(silent: true);

    _isConnecting = true;
    _statusMessage = 'Connecting to $target...';
    notifyListeners();

    try {
      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(target));
      request.headers['Accept'] = 'multipart/x-mixed-replace';

      final response = await _httpClient!.send(request).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      if (response.statusCode == 200) {
        _isConnected = true;
        _isConnecting = false;
        _statusMessage = 'Connected ✓';
        await saveStreamUrl(target);
        await NotificationService().pushConnectionAlert(true);
        notifyListeners();

        _buffer.clear();
        _streamSub = response.stream.listen(
          (chunk) {
            _buffer.addAll(chunk);
            _extractFrames();
          },
          onError: (e) {
            debugPrint('[Esp32Service] Stream error: $e');
            _handleDisconnect('Stream error. Retrying...');
          },
          onDone: () {
            debugPrint('[Esp32Service] Stream ended.');
            _handleDisconnect('Stream disconnected. Retrying...');
          },
        );
        return true;
      } else {
        _handleDisconnect('HTTP ${response.statusCode}. Check URL.');
        return false;
      }
    } on TimeoutException {
      _handleDisconnect('Connection timed out. Is the device on?');
      return false;
    } catch (e) {
      _handleDisconnect('Cannot reach device. Join "EasyLens-Camera" WiFi first.');
      return false;
    }
  }

  /// Disconnect cleanly.
  Future<void> disconnect({bool silent = false}) async {
    final wasConnected = _isConnected;
    await _streamSub?.cancel();
    _streamSub = null;
    _httpClient?.close();
    _httpClient = null;
    _buffer.clear();
    _isConnected = false;
    _isConnecting = false;
    _currentFrame = null;
    _flashOn = false;
    _statusMessage = 'Disconnected';
    if (!silent) {
      if (wasConnected) {
        await NotificationService().pushConnectionAlert(false);
      }
      notifyListeners();
    }
  }

  // ── Frame Extraction (same logic as prototype) ───────────────────────────

  void _extractFrames() {
    while (true) {
      final start = _indexOf(_buffer, [0xFF, 0xD8]); // JPEG SOI
      if (start == -1) {
        if (_buffer.length > 4096) _buffer.clear(); // prevent unbounded growth
        break;
      }
      final end = _indexOf(_buffer, [0xFF, 0xD9], from: start + 2); // JPEG EOI
      if (end == -1) break;

      final frame = Uint8List.fromList(_buffer.sublist(start, end + 2));
      _buffer.removeRange(0, end + 2);
      _currentFrame = frame;
      notifyListeners();
    }
  }

  int _indexOf(List<int> haystack, List<int> needle, {int from = 0}) {
    outer:
    for (int i = from; i <= haystack.length - needle.length; i++) {
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  // ── Auto-reconnect on disconnect ─────────────────────────────────────────
  void _handleDisconnect(String msg) {
    _isConnected = false;
    _isConnecting = false;
    _statusMessage = msg;
    _currentFrame = null;
    notifyListeners();
    // Auto-retry after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (!_isConnected && !_isConnecting) {
        connect();
      }
    });
  }

  // ── LED Flash Control ─────────────────────────────────────────────────────

  Future<void> toggleFlash() async {
    if (!_isConnected) return;
    final newVal = _flashOn ? 0 : 1;
    try {
      final base = _streamUrl.replaceAll('/stream', '');
      await http.get(Uri.parse('$base/led?val=$newVal'))
          .timeout(const Duration(seconds: 2));
      _flashOn = !_flashOn;
      notifyListeners();
    } catch (e) {
      debugPrint('[Esp32Service] LED toggle failed: $e');
    }
  }

  Future<void> setFlash(bool on) async {
    if (!_isConnected || _flashOn == on) return;
    try {
      final base = _streamUrl.replaceAll('/stream', '');
      await http.get(Uri.parse('$base/led?val=${on ? 1 : 0}'))
          .timeout(const Duration(seconds: 2));
      _flashOn = on;
      notifyListeners();
    } catch (e) {
      debugPrint('[Esp32Service] setFlash failed: $e');
    }
  }

  // ── Quick ping to test reachability ──────────────────────────────────────
  Future<bool> ping(String url) async {
    try {
      final baseUrl = url.contains('/stream')
          ? url.replaceAll('/stream', '')
          : url.replaceAll(':81', ':81');
      // Try hitting the stream endpoint with a HEAD-like request (short timeout)
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(url));
      final res = await client.send(req).timeout(const Duration(seconds: 3));
      client.close();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    disconnect(silent: true);
    super.dispose();
  }
}
