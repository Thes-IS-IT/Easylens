import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SmsService {
  final String _apiKey;
  final String _baseUrl;

  SmsService()
      : _apiKey = dotenv.env['MENSAHERO_API_KEY'] ?? 'PpPmPlrWbbBq3qdNK8UI',
        _baseUrl = dotenv.env['MENSAHERO_BASE_URL'] ?? 'https://mensahero.onrender.com';

  /// Sends an SMS via the MensaHero SMS Gateway.
  /// Returns `true` if successful, `false` otherwise.
  Future<bool> sendSMS({
    required String to,
    required String message,
    String from = 'EasyLens',
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/messages/create');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'apiKey': _apiKey,
          'from': from,
          'to': to,
          'message': message,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('SMS sent successfully to $to');
        return true;
      } else {
        print('Failed to send SMS. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }
}
