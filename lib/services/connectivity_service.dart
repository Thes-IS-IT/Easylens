import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service that monitors whether the app currently has active internet connectivity.
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal() {
    _startMonitoring();
  }

  bool _isOnline = true;
  bool _isChecking = false;
  Timer? _pollingTimer;

  bool get isOnline => _isOnline;
  bool get isChecking => _isChecking;
  String get statusText => _isOnline ? 'Online' : 'Offline';

  void _startMonitoring() {
    // Initial check
    checkConnectivity();
    // Periodic check every 12 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      checkConnectivity();
    });
  }

  /// Manually trigger a connectivity check
  Future<bool> checkConnectivity() async {
    if (_isChecking) return _isOnline;
    _isChecking = true;

    bool result = false;
    try {
      // 1. First fast check: lookup DNS for google.com
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 2500));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        result = true;
      }
    } catch (_) {
      // 2. Fallback check: HTTP 204 endpoint
      try {
        final response = await http
            .get(Uri.parse('https://clients3.google.com/generate_204'))
            .timeout(const Duration(milliseconds: 2500));
        result = response.statusCode == 204 || response.statusCode == 200;
      } catch (_) {
        result = false;
      }
    }

    _isChecking = false;
    if (_isOnline != result) {
      _isOnline = result;
      notifyListeners();
    }
    return _isOnline;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
