import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for submitting feedback directly to a Notion Database via Notion API.
class NotionService {
  static final NotionService _instance = NotionService._internal();
  factory NotionService() => _instance;
  NotionService._internal();

  /// Gets the Notion API token from .env
  String get _apiKey => dotenv.env['NOTION_API_KEY'] ?? '';

  /// Gets the Notion Database ID from .env
  String get _databaseId => dotenv.env['NOTION_DATABASE_ID'] ?? '';

  /// Returns true if Notion integration is properly configured in .env
  bool get isConfigured {
    final key = _apiKey.trim();
    final dbId = _databaseId.trim();
    return key.isNotEmpty && dbId.isNotEmpty && key != 'YOUR_NOTION_API_KEY' && dbId != 'YOUR_NOTION_DATABASE_ID';
  }

  /// Submits feedback to the configured Notion Database.
  ///
  /// Expected Notion Database Properties:
  /// - `User ID` (Title / Text)
  /// - `Name` (Text)
  /// - `Email` (Email / Text)
  /// - `Subject` (Select / Text)
  /// - `Rating` (Number)
  /// - `Comment` (Rich Text)
  /// - `Timestamp` (Date / Text)
  Future<bool> submitFeedbackToNotion({
    required String userId,
    required String displayName,
    required String email,
    required String subject,
    required int rating,
    required String comment,
    DateTime? timestamp,
  }) async {
    if (!isConfigured) {
      if (kDebugMode) {
        print('NotionService: NOTION_API_KEY or NOTION_DATABASE_ID missing in .env. Skipping Notion submit.');
      }
      return false;
    }

    final createdAt = timestamp ?? DateTime.now();

    try {
      final url = Uri.parse('https://api.notion.com/v1/pages');
      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Notion-Version': '2022-06-28',
        'Content-Type': 'application/json',
      };

      final body = {
        'parent': {
          'database_id': _databaseId,
        },
        'properties': {
          'User ID': {
            'title': [
              {
                'text': {'content': userId}
              }
            ]
          },
          'Name': {
            'rich_text': [
              {
                'text': {'content': displayName}
              }
            ]
          },
          'Email': {
            'email': email.contains('@') ? email : 'anonymous@easylens.com'
          },
          'Subject': {
            'select': {'name': subject.isEmpty ? 'Other' : subject}
          },
          'Rating': {
            'number': rating
          },
          'Comment': {
            'rich_text': [
              {
                'text': {'content': comment}
              }
            ]
          },
          'Timestamp': {
            'date': {'start': createdAt.toIso8601String()}
          }
        }
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          print('NotionService: Successfully saved feedback entry to Notion!');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('NotionService: Failed to submit to Notion. Status ${response.statusCode}: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('NotionService Error: $e');
      }
      return false;
    }
  }
}
