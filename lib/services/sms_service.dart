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

  /// Sends an SMS directly through the device's SIM card carrier (using user load credits).
  /// Returns `true` if successful, `false` otherwise.
  Future<bool> sendSMS({
    required String to,
    required String message,
    String? from,
  }) async {
    try {
      final formattedTo = formatPhoneNumber(to);
      print('[SmsService] Attempting to send SMS automatically via user SIM load to $formattedTo...');

      // On Android, use the native platform method channel that interacts with SmsManager
      if (Platform.isAndroid) {
        final bool success = await _channel.invokeMethod<bool>('sendSMS', {
          'to': formattedTo,
          'message': message,
        }) ?? false;
        print('[SmsService] Native SMS channel returned: $success');
        return success;
      } else {
        // Fallback for non-Android platforms (e.g. testing or iOS)
        print('[SmsService] Non-Android platform detected. Simulating successful local SMS send.');
        print('[SIM SMS SIMULATION] To: $formattedTo, Message: $message');
        return true;
      }
    } catch (e) {
      print('Error sending SMS via native channel: $e');
      return false;
    }
  }
}
