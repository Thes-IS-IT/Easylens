import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SmsService {
  static const _channel = MethodChannel('com.easylens.easylens/sms');
  final String _apiKey;
  final String _baseUrl;
  final String _deviceName;

  SmsService()
      : _apiKey = dotenv.env['MENSAHERO_API_KEY'] ?? 'PpPmPlrWbbBq3qdNK8UI',
        _baseUrl = dotenv.env['MENSAHERO_BASE_URL'] ?? 'https://mensahero.onrender.com',
        _deviceName = dotenv.env['MENSAHERO_DEVICE_NAME'] ?? 'EasyLens';

  String formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+639') && cleaned.length == 13) {
      return cleaned;
    }
    if (cleaned.startsWith('639') && cleaned.length == 12) {
      return '+$cleaned';
    }
    if (cleaned.startsWith('09') && cleaned.length == 11) {
      return '+63${cleaned.substring(1)}';
    }
    if (cleaned.startsWith('9') && cleaned.length == 10) {
      return '+63$cleaned';
    }
    final digitsOnly = cleaned.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 10 && digitsOnly.startsWith('9')) {
      return '+63$digitsOnly';
    }
    if (digitsOnly.length == 11 && digitsOnly.startsWith('09')) {
      return '+63${digitsOnly.substring(1)}';
    }
    if (digitsOnly.length == 12 && digitsOnly.startsWith('639')) {
      return '+$digitsOnly';
    }
    return cleaned;
  }

  /// Sends an SMS. It dynamically attempts to send directly through the device's SIM card
  /// carrier first (using user load credits). If that fails, is denied, or is not supported (e.g. iOS/simulator),
  /// it automatically falls back to sending via the online MensaHero gateway API.
  Future<bool> sendSMS({
    required String to,
    required String message,
    String? from,
  }) async {
    final formattedTo = formatPhoneNumber(to);
    print('[SmsService] Attempting to send SMS to $formattedTo...');

    // 1. Try native SIM SMS sending first (Android only)
    if (Platform.isAndroid) {
      try {
        print('[SmsService] Trying native SIM SMS load sending...');
        final bool success = await _channel.invokeMethod<bool>('sendSMS', {
          'to': formattedTo,
          'message': message,
        }) ?? false;
        
        if (success) {
          print('[SmsService] Native SIM SMS sent successfully!');
          return true;
        }
        print('[SmsService] Native SIM SMS returned false. Falling back...');
      } catch (e) {
        print('[SmsService] Native SIM SMS error: $e. Falling back to online gateway...');
      }
    }

    // 2. Fallback to online MensaHero gateway API
    print('[SmsService] Attempting online MensaHero API sending to $formattedTo...');
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/messages/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'apiKey': _apiKey,
          'from': _deviceName,
          'to': formattedTo,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[SmsService] Online MensaHero gateway sent SMS successfully.');
        return true;
      } else {
        print('[SmsService] Online MensaHero gateway failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[SmsService] Online MensaHero gateway error: $e');
    }

    return false;
  }
}

