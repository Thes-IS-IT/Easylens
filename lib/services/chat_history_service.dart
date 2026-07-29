import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent storage service for Buddy AI Chat messages (shared between Local LLM & Online Gemini)
class ChatHistoryService {
  static final ChatHistoryService _instance = ChatHistoryService._internal();
  factory ChatHistoryService() => _instance;
  ChatHistoryService._internal();

  static const String _storageKey = 'easylens_shared_chat_messages_v1';
  static const int _maxSavedMessages = 60;

  /// Loads stored conversation history turns from local disk.
  Future<List<Map<String, dynamic>>> loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        return decoded.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return {
            'text': map['text'] as String? ?? '',
            'isUser': map['isUser'] as bool? ?? false,
            'timestamp': map['timestamp'] as String? ?? DateTime.now().toIso8601String(),
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('[ChatHistoryService] Error loading chat history: $e');
    }
    return [];
  }

  /// Persists current conversation history turns to local disk.
  Future<void> saveMessages(List<Map<String, dynamic>> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only up to _maxSavedMessages to maintain optimal speed and memory
      final slice = messages.length > _maxSavedMessages
          ? messages.sublist(messages.length - _maxSavedMessages)
          : messages;

      final sanitized = slice.map((m) => {
        'text': m['text'] as String? ?? '',
        'isUser': m['isUser'] as bool? ?? false,
        'timestamp': m['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      }).toList();

      final jsonStr = jsonEncode(sanitized);
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('[ChatHistoryService] Error saving chat history: $e');
    }
  }

  /// Clears stored chat history.
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('[ChatHistoryService] Error clearing chat history: $e');
    }
  }
}
