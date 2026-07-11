import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'rag_service.dart';


class JournalService {
  static final JournalService _instance = JournalService._internal();

  factory JournalService() {
    return _instance;
  }

  JournalService._internal();

  Future<String> get _journalsDirectoryPath async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/journals';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<File> get _todayFile async {
    final dirPath = await _journalsDirectoryPath;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    return File('$dirPath/journal_$todayStr.md');
  }

  /// Appends conversation to the daily journal file.
  Future<void> appendToDailyJournal(String userMessage, String buddyResponse) async {
    try {
      final file = await _todayFile;
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      // Clean the response by stripping [NAVIGATE: ...] tag for cleaner logs S01
      final cleanBuddyResponse = buddyResponse.replaceAll(RegExp(r'\[NAVIGATE:[^\]]+\]'), '').trim();

      if (!await file.exists()) {
        await file.writeAsString('''# Buddy's Journal - ${DateTime.now().toIso8601String().split('T')[0]}

## Buddy's Insights & Notes
*No insights recorded yet for today.*

## Conversation Logs
''');
      }

      final logEntry = '''
### Chat Log at $timeStr
- **User**: $userMessage
- **Buddy**: $cleanBuddyResponse
''';

      await file.writeAsString(logEntry, mode: FileMode.append);
      print('[Journal] Appended conversation log to ${file.path}');
    } catch (e) {
      print('[Journal] Error appending to journal: $e');
    }
  }

  /// Queries Gemini/Gemma to generate insights from the last exchange
  /// and updates the daily journal file.
  Future<void> generateAndAddInsight(String userMessage, String buddyResponse) async {
    try {
      final cleanBuddyResponse = buddyResponse.replaceAll(RegExp(r'\[NAVIGATE:[^\]]+\]'), '').trim();

      final prompt = '''
You are Buddy, the friendly visual assistant dog mascot.
Analyze the following single exchange with the user:
User: "$userMessage"
Buddy: "$cleanBuddyResponse"

Generate a single bullet point (starting with a dash "-") in first person ("I") describing what you learned about the user (e.g. preferences, mobility aids used, tasks they are working on, feelings, or needs).
Keep the response extremely short, concise, and under 20 words.
Example: "- I learned that Arron needs help finding sharp objects and prefers haptic feedback."
Return ONLY the bullet point and nothing else.
''';

      final insight = await RagService.executeWithApiKeyFallback((apiKey) async {
        final model = GenerativeModel(
          model: 'gemini-3.5-flash',
          apiKey: apiKey,
        );
        final response = await model.generateContent([Content.text(prompt)]);
        return response.text?.trim() ?? '';
      });
      
      if (insight.startsWith('-')) {
        await _insertInsightIntoTodayFile(insight);
      }
    } catch (e) {
      print('[Journal] Error generating insight: $e');
    }
  }

  Future<void> _insertInsightIntoTodayFile(String newInsight) async {
    try {
      final file = await _todayFile;
      if (!await file.exists()) {
        final todayStr = DateTime.now().toIso8601String().split('T')[0];
        await file.writeAsString('''# Buddy's Journal - $todayStr

## Buddy's Insights & Notes
$newInsight

## Conversation Logs
''');
        return;
      }

      String content = await file.readAsString();
      const insightsHeader = '## Buddy\'s Insights & Notes';
      
      if (content.contains(insightsHeader)) {
        final parts = content.split(insightsHeader);
        if (parts.length > 1) {
          final rest = parts[1];
          // We find where the next section starts, or end of file
          final nextSectionIndex = rest.indexOf('##');
          String insightsSection = nextSectionIndex != -1 ? rest.substring(0, nextSectionIndex) : rest;
          String remainingSection = nextSectionIndex != -1 ? rest.substring(nextSectionIndex) : '';

          insightsSection = insightsSection.trim();
          if (insightsSection.contains('*No insights recorded yet for today.*')) {
            insightsSection = newInsight;
          } else {
            insightsSection = '$insightsSection\n$newInsight';
          }

          content = '${parts[0]}$insightsHeader\n$insightsSection\n\n$remainingSection';
          await file.writeAsString(content);
          print('[Journal] Inserted new insight into ${file.path}');
        }
      }
    } catch (e) {
      print('[Journal] Error inserting insight: $e');
    }
  }

  /// Lists all journals, returns file maps sorted descending by date.
  Future<List<Map<String, dynamic>>> getJournalsList() async {
    try {
      final dirPath = await _journalsDirectoryPath;
      final dir = Directory(dirPath);
      if (!await dir.exists()) return [];

      final files = await dir.list().toList();
      final List<Map<String, dynamic>> list = [];

      for (var entity in files) {
        if (entity is File && entity.path.endsWith('.md')) {
          final fileName = entity.path.split('/').last;
          // Extract date from journal_YYYY-MM-DD.md
          final match = RegExp(r'journal_(\d{4}-\d{2}-\d{2})\.md').firstMatch(fileName);
          if (match != null) {
            final dateStr = match.group(1)!;
            list.add({
              'date': dateStr,
              'path': entity.path,
              'name': fileName,
              'file': entity,
            });
          }
        }
      }

      list.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
      return list;
    } catch (e) {
      print('[Journal] Error listing journals: $e');
      return [];
    }
  }

  /// Reads journal content.
  Future<String> readJournalContent(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      print('[Journal] Error reading journal file: $e');
    }
    return '';
  }

  /// Scans past journals to supply context for RAG.
  Future<List<String>> getJournalContextForQuery(String query) async {
    final List<String> contexts = [];
    try {
      final journals = await getJournalsList();
      // Look at the last 1 day of journals to avoid bloating the context and causing OOM crashes
      final recentJournals = journals.take(1).toList();

      final results = await Future.wait(recentJournals.map((journal) async {
        final file = journal['file'] as File;
        final date = journal['date'] as String;
        final content = await file.readAsString();

        final List<String> localContexts = [];

        // 1. Always extract the Insights & Notes section
        if (content.contains('## Buddy\'s Insights & Notes')) {
          final parts = content.split('## Buddy\'s Insights & Notes');
          if (parts.length > 1) {
            final rest = parts[1];
            final nextSecIndex = rest.indexOf('##');
            final insights = nextSecIndex != -1 ? rest.substring(0, nextSecIndex) : rest;
            final cleanInsights = insights.trim();
            if (cleanInsights.isNotEmpty && !cleanInsights.contains('No insights recorded')) {
              localContexts.add('On $date, Buddy learned:\n$cleanInsights');
            }
          }
        }

        // 2. If the user query is asking about past conversations, scan logs
        final lowercaseQuery = query.toLowerCase();
        if (lowercaseQuery.contains('what did i') ||
            lowercaseQuery.contains('we talked about') ||
            lowercaseQuery.contains('preferences') ||
            lowercaseQuery.contains('earlier') ||
            lowercaseQuery.contains('yesterday') ||
            lowercaseQuery.contains('before') ||
            lowercaseQuery.contains('last time')) {
          if (content.contains('## Conversation Logs')) {
            final parts = content.split('## Conversation Logs');
            if (parts.length > 1) {
              final logs = parts[1].trim();
              if (logs.isNotEmpty) {
                localContexts.add('Conversation log on $date:\n$logs');
              }
            }
          }
        }
        return localContexts;
      }));

      for (var res in results) {
        contexts.addAll(res);
      }
    } catch (e) {
      print('[Journal] Error getting journal context: $e');
    }
    return contexts;
  }
}
