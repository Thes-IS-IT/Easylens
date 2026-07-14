import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'journal_service.dart';
import 'settings_service.dart';
import 'firebase_service.dart';


class KnowledgeItem {
  final String title;
  final String content;
  final List<String> keywords;

  KnowledgeItem({
    required this.title,
    required this.content,
    required this.keywords,
  });

  bool get isTagalogItem {
    final titleLower = title.toLowerCase();
    final contentLower = content.toLowerCase();
    // Common Tagalog/Filipino stop words
    final tagalogWords = ['ang', 'mga', 'ng', 'sa', 'si', 'ni', 'para', 'na', 'tampok', 'gabay', 'paggamit', 'pagkakakilanlan', 'isinasalin'];
    for (var word in tagalogWords) {
      if (titleLower.contains(RegExp('\\b$word\\b')) || contentLower.contains(RegExp('\\b$word\\b'))) {
        return true;
      }
    }
    return false;
  }
}

class RagService {
  static final RagService _instance = RagService._internal();
  factory RagService() => _instance;
  RagService._internal();

  bool _gemmaInitialized = false;
  bool _isGemmaModelInstalled = false;

  // Cached TF-IDF engines split by language to prevent cross-language context leakage
  TfidfEngine? _cachedEngineEnglish;
  TfidfEngine? _cachedEngineFilipino;
  bool _engineDirty = true;

  List<KnowledgeItem> _localKnowledgeBase = [
    KnowledgeItem(
      title: "Buddy's Identity",
      content: "Buddy is a loyal golden retriever dog who wears a blue cap and blue collar shirt. He serves as an on-device vision assistant for the EasyLens app, helping users explore their environments and identify items.",
      keywords: ["who are you", "buddy", "identity", "dog", "mascot", "easylens"],
    ),
    KnowledgeItem(
      title: "Companion Guidelines",
      content: "Companion mode allows family members or caregivers to monitor safety. Ensure object labels with high hazard levels (e.g., sharp objects, hot liquids) trigger audio alerts. Keep communication clear, concise, and highly accessible.",
      keywords: ["companion", "safety", "caregiver", "instructions", "monitoring"],
    ),
    KnowledgeItem(
      title: "Google ML Kit Features",
      content: "Google ML Kit Image Labeling runs on-device, offering instant image classification of general objects (like chairs, computers, plants, cups) with high confidence scores.",
      keywords: ["ml kit", "image labeling", "classification", "features", "how does ml kit work"],
    ),
    KnowledgeItem(
      title: "MobileNetV2 Object Detector",
      content: "The MobileNetV2 SSD model detects 80 classes of objects from the MS-COCO dataset. It outlines bounding boxes in real-time to locate objects like persons, cars, cups, dogs, and bottles.",
      keywords: ["mobilenet", "object detection", "bounding boxes", "detection", "coco"],
    ),
    KnowledgeItem(
      title: "Firebase Services",
      content: "EasyLens uses Firebase Auth for secure, password-less or credential-based signup/login, and Firebase Storage to save user preference configurations and captured analytics reports.",
      keywords: ["firebase", "auth", "storage", "database", "save", "signup"],
    ),
  ];
  
  // In-memory inverted index database mapping keywords to items for O(1) query lookups S01
  final Map<String, List<KnowledgeItem>> _invertedIndex = {};

  Future<void> loadKnowledgeBase() async {
    try {
      final jsonText = await rootBundle.loadString('assets/models/buddy_knowledge.json');
      final List<dynamic> data = jsonDecode(jsonText);
      _localKnowledgeBase = data.map((item) => KnowledgeItem(
        title: item['title'] ?? '',
        content: item['content'] ?? '',
        keywords: List<String>.from(item['keywords'] ?? []),
      )).toList();

      // Index knowledge items by lowercase keywords
      _invertedIndex.clear();
      for (var item in _localKnowledgeBase) {
        for (var kw in item.keywords) {
          final cleanKw = kw.toLowerCase().trim();
          if (cleanKw.isNotEmpty) {
            _invertedIndex.putIfAbsent(cleanKw, () => []).add(item);
          }
        }
      }
      // Mark engine dirty so it gets rebuilt on next query S01
      _engineDirty = true;
      _cachedEngineEnglish = null;
      _cachedEngineFilipino = null;
      print('[RAG] Loaded ${_localKnowledgeBase.length} knowledge items and built inverted index database.');
    } catch (e) {
      print('[RAG] Error loading knowledge JSON asset: $e. Falling back to default list.');
      _invertedIndex.clear();
      for (var item in _localKnowledgeBase) {
        for (var kw in item.keywords) {
          final cleanKw = kw.toLowerCase().trim();
          if (cleanKw.isNotEmpty) {
            _invertedIndex.putIfAbsent(cleanKw, () => []).add(item);
          }
        }
      }
      _engineDirty = true;
      _cachedEngineEnglish = null;
      _cachedEngineFilipino = null;
    }
  }

  bool get isGemmaReady => _gemmaInitialized && _isGemmaModelInstalled;

  Future<bool> checkGemmaModelExists() async {
    final path = await _getLocalModelPath();
    if (path != null) {
      final file = File(path);
      return file.existsSync() && file.lengthSync() > 100000000;
    }
    return false;
  }

  Future<bool> downloadGemmaModel(void Function(double progress) onProgress) async {
    final savePath = await _getDynamicSavePath();
    final file = File(savePath);
    await file.parent.create(recursive: true);

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse('https://huggingface.co/vba01/gemma-2b-it-gpu-int4/resolve/main/gemma-2b-it-gpu-int4.bin'));
      final response = await client.send(request).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final totalLength = response.contentLength ?? 1354301440;
        int downloadedLength = 0;

        final sink = file.openWrite();
        await response.stream.forEach((chunk) {
          sink.add(chunk);
          downloadedLength += chunk.length;
          onProgress(downloadedLength / totalLength);
        });
        await sink.close();
        _isGemmaModelInstalled = true;
        return true;
      } else {
        print('[RAG] Download failed with status: ${response.statusCode}');
        if (await file.exists()) {
          await file.delete();
        }
        return false;
      }
    } catch (e) {
      print('[RAG] Actual download failed or offline: $e');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      return false;
    }
  }

  Future<String> _getDynamicSavePath() async {
    if (Platform.isAndroid) {
      final extDirs = await getExternalStorageDirectories();
      if (extDirs != null && extDirs.isNotEmpty) {
        return "${extDirs.first.path}/model.bin";
      }
    }
    final appDir = await getApplicationSupportDirectory();
    return "${appDir.path}/model.bin";
  }

  Future<void> extractModelFromAssets() async {
    try {
      final savePath = await _getDynamicSavePath();
      final file = File(savePath);
      
      if (await file.exists()) {
        final size = await file.length();
        if (size > 100000000) {
          print('[RAG] Model already extracted at $savePath.');
          return;
        }
      }

      print('[RAG] Checking if model is bundled in assets...');
      final byteData = await rootBundle.load('assets/models/model.bin');
      print('[RAG] Extracting model from assets to $savePath (first launch setup)...');
      await file.parent.create(recursive: true);
      
      final buffer = byteData.buffer;
      await file.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );
      print('[RAG] Model extraction complete!');
    } catch (e) {
      print('[RAG] Model asset not found or extraction skipped: $e');
    }
  }

  Future<void> initializeGemma() async {
    await loadKnowledgeBase();
    await extractModelFromAssets();
    try {
      final modelPath = await _getLocalModelPath();
      if (modelPath != null) {
        await _ensureGemmaInitialized(modelPath);
        // Warm up and load model weight files into memory S01
        await FlutterGemma.getActiveModel(maxTokens: 1024);
        print("[Gemma] Real on-device engine initialized and warmed up successfully from $modelPath.");
      }
    } catch (e) {
      print("[Gemma] Pre-init failed: $e");
    }
  }

  Future<String?> _getLocalModelPath() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return null;
    }
    final dynamicPath = await _getDynamicSavePath();
    if (File(dynamicPath).existsSync()) {
      return dynamicPath;
    }
    final paths = [
      "/storage/emulated/0/Android/data/com.company.easylens/files/model.bin",
      "/sdcard/Android/data/com.company.easylens/files/model.bin",
      "/storage/emulated/0/Download/model.bin",
      "/sdcard/Download/model.bin",
    ];
    for (var path in paths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  Future<void>? _gemmaInitFuture;

  Future<void> _ensureGemmaInitialized(String modelPath) async {
    if (_gemmaInitialized) return;
    _gemmaInitFuture ??= () async {
      try {
        await FlutterGemma.initialize();
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
        ).fromFile(modelPath).install();
        _gemmaInitialized = true;
        _isGemmaModelInstalled = true;
      } catch (e) {
        _gemmaInitFuture = null; // Allow retry on error
        rethrow;
      }
    }();
    await _gemmaInitFuture;
  }

  dynamic _gemmaSession;

  void clearGemmaSession() {
    _gemmaSession = null;
    print("[Gemma] Local session cleared.");
  }

  Future<String> _queryGemmaOffline(String prompt, {String? systemInstruction}) async {
    try {
      final modelPath = await _getLocalModelPath();
      if (modelPath == null) {
        return generateSmartLocalResponse(prompt);
      }

      await _ensureGemmaInitialized(modelPath).timeout(const Duration(seconds: 8));

      final model = await FlutterGemma.getActiveModel(maxTokens: 1024);
      final session = await model.createSession();
      final finalPrompt = systemInstruction != null
          ? "<start_of_turn>user\nInstruction: $systemInstruction\n\n$prompt<end_of_turn>\n<start_of_turn>model\n"
          : "<start_of_turn>user\n$prompt<end_of_turn>\n<start_of_turn>model\n";
      await session.addQueryChunk(Message(text: finalPrompt, isUser: true));
      
      final response = await session.getResponse().timeout(const Duration(seconds: 5));
      if (response == null) return "No response from offline local model.";
      return response
          .replaceAll('<start_of_turn>user', '')
          .replaceAll('<start_of_turn>model', '')
          .replaceAll('<start_of_turn>', '')
          .replaceAll('<end_of_turn>', '')
          .trim();
    } catch (e) {
      return "Local Gemma LLM failed: $e";
    }
  }

  Stream<String> _queryGemmaOfflineStream(
    String prompt, {
    String? systemInstruction,
    List<Map<String, dynamic>>? history,
  }) async* {
    final modelPath = await _getLocalModelPath();
    if (modelPath == null) {
      yield generateSmartLocalResponse(prompt);
      return;
    }

    final controller = StreamController<String>();

    Future.microtask(() async {
      try {
        await _ensureGemmaInitialized(modelPath).timeout(const Duration(seconds: 8));

        final model = await FlutterGemma.getActiveModel(maxTokens: 1024);
        final session = await model.createSession();

        // Replay prior turns so Gemma maintains conversation memory S01
        if (history != null && history.isNotEmpty) {
          int startIndex = 0;
          // Gemma chat sessions must start with a user message (isUser: true)
          while (startIndex < history.length && history[startIndex]['isUser'] != true) {
            startIndex++;
          }
          for (int i = startIndex; i < history.length; i++) {
            final msg = history[i];
            final msgText = (msg['text'] as String? ?? '').trim();
            if (msgText.isEmpty) continue;
            // Strip navigation tags from assistant messages before feeding back
            final cleanText = msgText.replaceAll(RegExp(r'\[NAVIGATE:.*?\]'), '').trim();
            if (cleanText.isEmpty) continue;
            
            final formattedHistoryText = msg['isUser'] == true
                ? "<start_of_turn>user\n$cleanText<end_of_turn>"
                : "<start_of_turn>model\n$cleanText<end_of_turn>";
 
            await session.addQueryChunk(
              Message(text: formattedHistoryText, isUser: msg['isUser'] == true),
            );
          }
        }

        // Add the current user query prepended with the system instruction
        final finalPrompt = systemInstruction != null
            ? "<start_of_turn>user\nInstruction: $systemInstruction\n\n$prompt<end_of_turn>\n<start_of_turn>model\n"
            : "<start_of_turn>user\n$prompt<end_of_turn>\n<start_of_turn>model\n";
        await session.addQueryChunk(Message(text: finalPrompt, isUser: true));

        // 5-second timeout on the response stream
        final responseStream = session.getResponseAsync().timeout(
          const Duration(seconds: 5),
          onTimeout: (sink) {
            sink.close();
          },
        );

        await for (final token in responseStream) {
          if (token != null) {
            final cleaned = token
                .replaceAll('<start_of_turn>user', '')
                .replaceAll('<start_of_turn>model', '')
                .replaceAll('<start_of_turn>', '')
                .replaceAll('<end_of_turn>', '');
            if (cleaned.isNotEmpty) {
              controller.add(cleaned);
            }
          }
        }
      } catch (e) {
        // Silently swallow — outer askBuddyStream fallback guard handles empty output S01
        debugPrint('[Gemma] Stream error (fallback will handle): $e');
      } finally {
        controller.close();
      }
    });

    yield* controller.stream;
  }

  Stream<String> _queryGeminiOnlineStream(
    String prompt, {
    String? systemInstruction,
    List<Map<String, dynamic>>? history,
  }) async* {
    final List<String> keys = [];
    final userKey = SettingsService().geminiApiKey.trim();
    if (userKey.isNotEmpty) {
      keys.add(userKey);
    }
    keys.addAll(getGeminiApiKeys());

    if (keys.isEmpty) {
      yield "No Gemini API keys found. Please set one in Settings.";
      return;
    }

    for (var key in keys) {
      try {
        final model = GenerativeModel(
          model: 'gemini-3.5-flash',
          apiKey: key.trim(),
          systemInstruction: systemInstruction != null ? Content.system(systemInstruction) : null,
        );

        final List<Content> chatHistory = [];
        if (history != null && history.isNotEmpty) {
          for (final msg in history) {
            final isUser = msg['isUser'] == true;
            final text = (msg['text'] as String? ?? '').trim();
            if (text.isEmpty) continue;
            // Clean up navigation tags before sending to chat history
            final cleanText = isUser ? text : text.replaceAll(RegExp(r'\[NAVIGATE:[^\]]+\]'), '').trim();
            if (cleanText.isEmpty) continue;
            
            chatHistory.add(Content(
              isUser ? 'user' : 'model',
              [TextPart(cleanText)],
            ));
          }
        }

        final chat = model.startChat(history: chatHistory);
        final responseStream = chat.sendMessageStream(Content.text(prompt));
        
        await for (final chunk in responseStream) {
          final token = chunk.text;
          if (token != null) {
            yield token;
          }
        }
        
        // Successfully streamed response, exit key loop
        return;
      } catch (e) {
        debugPrint('[Gemini Online Stream] Error with key: $e');
        // Fall through to try the next key
      }
    }
    
    yield "Connection error with Gemini. Please check your network.";
  }

  String _getOllamaBaseUrl() {
    if (Platform.isAndroid) {
      return "http://10.0.2.2:11434";
    }
    return "http://localhost:11434";
  }

  Future<String> _queryLocalOllama(String prompt) async {
    final baseUrl = _getOllamaBaseUrl();
    try {
      final tagsResponse = await http
          .get(Uri.parse("$baseUrl/api/tags"))
          .timeout(const Duration(seconds: 2));
      
      if (tagsResponse.statusCode != 200) {
        throw Exception("Ollama server code ${tagsResponse.statusCode}");
      }

      final tagsData = jsonDecode(tagsResponse.body);
      final List modelsList = tagsData['models'] ?? [];
      if (modelsList.isEmpty) {
        throw Exception("No models installed in Ollama.");
      }

      final availableNames = modelsList.map((m) => m['name'].toString()).toList();
      String selectedModel = availableNames.first;
      const preferredModels = [
        "llama3.2:latest",
        "gemma2:2b",
        "qwen2.5:0.5b",
        "gemma3:4b",
        "qwen2.5-coder:7b",
        "gemma4:latest"
      ];
      for (var pref in preferredModels) {
        if (availableNames.contains(pref)) {
          selectedModel = pref;
          break;
        }
      }

      final generateUrl = Uri.parse("$baseUrl/api/generate");
      final response = await http.post(
        generateUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "model": selectedModel,
          "prompt": prompt,
          "stream": false,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return resData['response']?.toString().trim() ?? "Empty response from Local LLM.";
      } else {
        return "Local LLM Error: HTTP ${response.statusCode}";
      }
    } catch (e) {
      return "Local LLM connection failed: $e";
    }
  }

  // A lightweight keyword-based RAG search using inverted index database mapping
  String retrieveContext(String query) {
    final cleanQuery = query.toLowerCase();
    final List<String> matchedContents = [];
    final Set<KnowledgeItem> uniqueMatches = {};

    // Tokenize query words
    final words = cleanQuery.split(RegExp(r'[\s,.\-!?]+'));
    for (var word in words) {
      if (word.length < 2) continue; // Skip very short tokens to avoid false positives

      // 1. Direct O(1) keyword index lookup
      if (_invertedIndex.containsKey(word)) {
        uniqueMatches.addAll(_invertedIndex[word]!);
      }

      // 2. Substring keyword matches
      for (var key in _invertedIndex.keys) {
        if (key.contains(word) || word.contains(key)) {
          uniqueMatches.addAll(_invertedIndex[key]!);
        }
      }
    }

    final lang = SettingsService().selectedLanguage;
    final isUserFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

    final filteredMatches = uniqueMatches.where((item) => item.isTagalogItem == isUserFilipino);
    for (var item in filteredMatches) {
      matchedContents.add("[${item.title}]: ${item.content}");
    }

    if (matchedContents.isEmpty) {
      return "Buddy is the EasyLens vision assistant. Provide helpful, short answers to describe items or environments.";
    }

    // Limit matched contents to at most 2 items S01 to avoid prompt bloat and OOM crashes
    final limitedMatches = matchedContents.take(2).toList();
    return limitedMatches.join("\n\n");
  }

  Future<String> retrieveContextAsync(String query) async {
    try {
      final lang = SettingsService().selectedLanguage;
      final isUserFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

      if (isUserFilipino) {
        if (_cachedEngineFilipino == null || _engineDirty) {
          final freshEngine = TfidfEngine();
          for (var item in _localKnowledgeBase) {
            if (item.isTagalogItem) {
              freshEngine.addDocument(item.title, item.content, 'knowledge');
            }
          }
          freshEngine.calculateIdfs();
          _cachedEngineFilipino = freshEngine;
          _engineDirty = false;
          print('[RAG] Static Tagalog TF-IDF engine cached.');
        }
      } else {
        if (_cachedEngineEnglish == null || _engineDirty) {
          final freshEngine = TfidfEngine();
          for (var item in _localKnowledgeBase) {
            if (!item.isTagalogItem) {
              freshEngine.addDocument(item.title, item.content, 'knowledge');
            }
          }
          freshEngine.calculateIdfs();
          _cachedEngineEnglish = freshEngine;
          _engineDirty = false;
          print('[RAG] Static English TF-IDF engine cached.');
        }
      }

      final targetEngine = isUserFilipino ? _cachedEngineFilipino : _cachedEngineEnglish;
      final knowledgeMatches = targetEngine != null ? targetEngine.search(query, limit: 2) : <RagDocument>[];

      // 3. Query dynamic journals using a separate tiny temporary engine S01
      final List<RagDocument> journalMatches = [];
      try {
        final journalSegments = await JournalService().getRecentJournalsContent(7);
        if (journalSegments.isNotEmpty) {
          final journalEngine = TfidfEngine();
          for (var segment in journalSegments) {
            final title = segment['title'] ?? '';
            final content = segment['content'] ?? '';
            final source = segment['source'] ?? 'journal';
            journalEngine.addDocument(title, content, source);
          }
          journalEngine.calculateIdfs();
          journalMatches.addAll(journalEngine.search(query, limit: 2));
        }
      } catch (je) {
        print('[RAG] Journal search skipped: $je');
      }

      // 4. Format and combine results S01
      final List<String> knowledgeParts = [];
      for (var doc in knowledgeMatches) {
        knowledgeParts.add("[${doc.title}]: ${doc.content}");
      }

      final List<String> journalParts = [];
      for (var doc in journalMatches) {
        journalParts.add("[${doc.title}]: ${doc.content}");
      }

      final List<String> resultBlocks = [];
      if (knowledgeParts.isNotEmpty) {
        resultBlocks.add(knowledgeParts.join("\n\n"));
      }
      if (journalParts.isNotEmpty) {
        resultBlocks.add("[Buddy's Memory/Past Journals]:\n${journalParts.join("\n\n")}");
      }

      if (resultBlocks.isNotEmpty) {
        var contextText = resultBlocks.join("\n\n");
        // Safe token ceiling for Gemma 2B S01
        if (contextText.length > 450) {
          contextText = "${contextText.substring(0, 440)}... [truncated]";
        }
        return contextText;
      }
      
      return "EasyLens is a visual assistive app built at Holy Angel University. Buddy is the friendly Golden Retriever AI guide dog mascot.";
    } catch (e) {
      print('[RAG] Error in TF-IDF context retrieval: $e');
    }
    return retrieveContext(query);
  }

  void _logToJournal(String question, String answer) {
    if (question.contains("You are Buddy")) return;
    Future.microtask(() async {
      final js = JournalService();
      await js.appendToDailyJournal(question, answer);
      await js.generateAndAddInsight(question, answer);
    });
  }



  String _getSystemInstruction(String userName, String mobilityAid) {
    return "You are Buddy, the friendly Golden Retriever guide dog mascot of the EasyLens app. "
        "EasyLens was built as a CS thesis at Holy Angel University (HAU) by developer Arron Kian Parejas and team. "
        "The user's name is $userName. The user's mobility aid is $mobilityAid. "
        "Keep your response warm, friendly, helpful, and very short (under 2 sentences). "
        "Use the provided Context (which includes both EasyLens knowledge base info and the user's personal memories/journals) to answer the Question directly.";
  }

  String _buildUserPrompt(String rawQuestion, String context) {
    if (rawQuestion.contains("scanned nearby:")) {
      final regExp = RegExp(r"scanned nearby:\s*'(.*)'", caseSensitive: false);
      final match = regExp.firstMatch(rawQuestion);
      final scannedText = match != null ? match.group(1) : rawQuestion;
      return "scanned nearby: '$scannedText'";
    }
    
    if (context.isEmpty) {
      return rawQuestion;
    }
    
    return "Context:\n$context\n\nQuestion:\n$rawQuestion";
  }

  bool _isOffTopicForVisualAssistance(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return false;

    // If it contains visual/assistive/navigational keywords, it's ON-topic
    final visualKeywords = {
      'see', 'look', 'front', 'around', 'scanned', 'read', 'text', 'sign', 
      'label', 'hazard', 'object', 'obstacle', 'person', 'people', 'face', 
      'path', 'navigate', 'go to', 'where', 'find', 'locate', 'buddy', 'guide',
      'nakakita', 'nakikita', 'tingnan', 'harap', 'paligid', 'basahin', 'teksto',
      'babala', 'bagay', 'tao', 'mukha', 'daan', 'pumunta', 'nasaan', 'hanapin'
    };
    for (var vk in visualKeywords) {
      if (lower.contains(vk)) return false;
    }

    // 1. Math check (contains math operators between digits or math keywords)
    final mathPattern = RegExp(r'\d+\s*[\+\-\*\/=]\s*\d+');
    if (mathPattern.hasMatch(lower)) return true;

    final mathKeywords = {
      'calculate', 'solve', 'equation', 'arithmetic', 'algebra', 'calculus', 
      'multiplication', 'division', 'addition', 'subtraction', 'square root',
      'plus', 'minus', 'divided by', 'times', 'multiplied by', 'equals'
    };
    for (var keyword in mathKeywords) {
      if (lower.contains(keyword)) return true;
    }

    // Check for raw math expressions like "1 + 1"
    final rawMathPattern = RegExp(r'^\s*[\d\s+\-*/()=]+$');
    if (rawMathPattern.hasMatch(lower) && 
        (lower.contains('+') || lower.contains('-') || lower.contains('*') || lower.contains('/') || lower.contains('='))) {
      return true;
    }

    // 2. Programming/Tech off-topic keywords
    final techKeywords = {
      'write code', 'coding', 'programming', 'javascript', 'python', 'html', 
      'css', 'java', 'c++', 'c#', 'react', 'flutter code', 'software development'
    };
    for (var keyword in techKeywords) {
      if (lower.contains(keyword)) return true;
    }

    // 3. General knowledge / Trivia off-topic keywords
    final triviaKeywords = {
      'capital of', 'who is the president', 'historical facts', 'tell me a story about',
      'recipe for', 'how to cook', 'define photosynthesis', 'speed of light', 
      'distance to the moon', 'tell me a joke', 'who directed the movie'
    };
    for (var keyword in triviaKeywords) {
      if (lower.contains(keyword)) return true;
    }

    return false;
  }

  String _getOffTopicRejectionMessage(String lang) {
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    if (isFilipino) {
      return "Woof! Disenyo po ako para tumulong sa may mga kapansanan sa paningin at pag-navigate. Hindi ko po kayo matutulungan sa mga pangkalahatang tanong, math, o trivia.";
    }
    return "Woof! I'm designed specifically to assist with visual impairment and navigation. I cannot help with general queries, math, or trivia.";
  }

  Future<String> askBuddy(String question) async {
    String rawQuestion = question;
    String userName = "User";
    String mobilityAid = "None";

    if (question.contains("User Info:")) {
      final nameMatch = RegExp(r"Name is '([^']+)'").firstMatch(question);
      if (nameMatch != null) userName = nameMatch.group(1) ?? "User";
      
      final aidMatch = RegExp(r"using mobility aid '([^']+)'").firstMatch(question);
      if (aidMatch != null) mobilityAid = aidMatch.group(1) ?? "None";
      
      final questionMatch = RegExp(r"Question:\s*(.*)\s*Buddy:", caseSensitive: false, dotAll: true).firstMatch(question);
      if (questionMatch != null) {
        rawQuestion = questionMatch.group(1)?.trim() ?? question;
      }
    }

    final lang = SettingsService().selectedLanguage;
    if (_isOffTopicForVisualAssistance(rawQuestion)) {
      return _getOffTopicRejectionMessage(lang);
    }

    final lowerQ = rawQuestion.toLowerCase();
    final isConversational = rawQuestion.length < 30 &&
        !lowerQ.contains("reports") &&
        !lowerQ.contains("scanned") &&
        !lowerQ.contains("nearby") &&
        !lowerQ.contains("labels") &&
        !lowerQ.contains("visual");

    final context = isConversational ? "" : await retrieveContextAsync(rawQuestion);
    final userPrompt = _buildUserPrompt(rawQuestion, context);
    final systemPrompt = _getSystemInstruction(userName, mobilityAid);
    final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');
    final modelPath = await _getLocalModelPath();

    String responseText = "";

    if (isFilipino) {
      // Use Online Gemini for Filipino/Tagalog language S01
      responseText = await askBuddyGemini(rawQuestion, userName, mobilityAid);
    } else {
      // Use Local Gemma for English S01
      if (modelPath != null) {
        responseText = await _queryGemmaOffline(userPrompt, systemInstruction: systemPrompt);
      } else {
        responseText = generateSmartLocalResponse(rawQuestion);
      }
    }

    _logToJournal(rawQuestion, responseText);
    return responseText;
  }

  Stream<String> askBuddyStream(
    String question, {
    String userName = 'User',
    List<Map<String, dynamic>>? history,
  }) async* {
    // Read user context from settings directly S01
    final rawQuestion = question.trim();
    final lang = SettingsService().selectedLanguage;
    if (_isOffTopicForVisualAssistance(rawQuestion)) {
      yield _getOffTopicRejectionMessage(lang);
      return;
    }
    final mobilityAid = SettingsService().selectedMobilityAid.isNotEmpty
        ? SettingsService().selectedMobilityAid
        : 'None';

    final lowerQ = rawQuestion.toLowerCase().trim();
    // Only skip RAG for pure one-word greetings — everything else runs TF-IDF retrieval S01
    const pureGreetings = {'hi', 'hello', 'hey', 'thanks', 'ok', 'okay', 'bye', 'good morning', 'good evening', 'good night', 'good afternoon'};
    final isGreeting = pureGreetings.contains(lowerQ);

    final context = isGreeting ? "" : await retrieveContextAsync(rawQuestion);
    final userPrompt = _buildUserPrompt(rawQuestion, context);
    final systemPrompt = _getSystemInstruction(userName, mobilityAid);

    final useLocal = SettingsService().useLocalAI;
    final modelPath = await _getLocalModelPath();
 
    final StringBuffer buf = StringBuffer();
    bool yieldedAnything = false;
    try {
      if (useLocal) {
        await for (final token in _queryGemmaOfflineStream(
          userPrompt,
          systemInstruction: systemPrompt,
          history: history,
        )) {
          buf.write(token);
          yield token;
          yieldedAnything = true;
        }
      } else {
        await for (final token in _queryGeminiOnlineStream(
          userPrompt,
          systemInstruction: systemPrompt,
          history: history,
        )) {
          buf.write(token);
          yield token;
          yieldedAnything = true;
        }
      }
    } catch (_) {}

    final response = buf.toString().trim();
    final printable = response.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    final isError = response.toLowerCase().contains('no gemini api key') ||
        response.toLowerCase().contains('connection error') ||
        response.toLowerCase().contains('failed to') ||
        response.toLowerCase().contains('error with key');
    
    if (!yieldedAnything || printable.length < 5 || isError) {
      yield generateSmartLocalResponse(rawQuestion);
    } else {
      _logToJournal(rawQuestion, response);
    }
  }

  Future<String> askBuddyLocalOnly(String question) async {
    final lang = SettingsService().selectedLanguage;
    if (_isOffTopicForVisualAssistance(question)) {
      return _getOffTopicRejectionMessage(lang);
    }
    final lowerQ = question.toLowerCase();
    final isConversational = question.length < 30 &&
        !lowerQ.contains("reports") &&
        !lowerQ.contains("scanned") &&
        !lowerQ.contains("nearby") &&
        !lowerQ.contains("labels") &&
        !lowerQ.contains("visual");

    final context = isConversational ? "" : await retrieveContextAsync(question);
    final userPrompt = _buildUserPrompt(question, context);
    final systemPrompt = _getSystemInstruction("User", "None");

    final modelPath = await _getLocalModelPath();
    if (modelPath != null) {
      try {
        return await _queryGemmaOffline(userPrompt, systemInstruction: systemPrompt);
      } catch (_) {
        return generateSmartLocalResponse(question);
      }
    }
    return generateSmartLocalResponse(question);
  }

  String generateSmartLocalResponse(String question) {
    final lowerQ = question.toLowerCase().trim();
    final user = FirebaseService().currentUser;
    final name = user?.displayName ?? "friend";
    final aid = SettingsService().selectedMobilityAid.isNotEmpty
        ? SettingsService().selectedMobilityAid
        : "None";

    final lang = SettingsService().selectedLanguage;
    final isUserFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

    // 0. Curated questions and answers
    if (lowerQ.contains("scan nearby objects") || lowerQ.contains("detect objects") || lowerQ.contains("identify objects") || lowerQ.contains("recognize objects")) {
      return isUserFilipino
          ? "Buddy: Aw! Buksan ang camera screen, piliin ang Object Detection, at tutukuyin ko ang mga bagay sa paligid mo. I-tap ang screen para marinig kung ano ang nasa harap mo, arf!"
          : "Buddy: Arf! Open the camera screen, select Object Detection, and I will identify objects around you. Tap the screen to hear what is in front of you, woof!";
    }
    if (lowerQ.contains("read text") || lowerQ.contains("scan text") || lowerQ.contains("ocr") || lowerQ.contains("read signs") || lowerQ.contains("read labels")) {
      return isUserFilipino
          ? "Buddy: Arf! Pumunta sa Camera Screen at piliin ang Text Scanner (OCR). Babasahin ko ang mga karatula, libro, at label nang malakas para sa iyo, aw aw!"
          : "Buddy: Woof! Go to the Camera Screen and select Text Scanner (OCR). I will read signs, books, and labels aloud for you, arf!";
    }
    if (lowerQ.contains("add a face") || lowerQ.contains("register a face") || lowerQ.contains("face registration") || lowerQ.contains("register face")) {
      return isUserFilipino
          ? "Buddy: Aw! Pumunta sa Settings at i-tap ang Face Registration. Maaari kang kumuha ng larawan para irehistro ang mukha upang makilala ko sila mamaya, arf!"
          : "Buddy: Arf! Navigate to Settings and tap Face Registration. You can snap a photo to register a face so I can recognize them later, woof!";
    }
    if (lowerQ.contains("gps navigation") || lowerQ.contains("how to navigate") || lowerQ.contains("audio directions") || lowerQ.contains("turn-by-turn") || lowerQ.contains("directions")) {
      return isUserFilipino
          ? "Buddy: Arf! Buksan ang Nav screen, i-type o sabihin ang iyong pupuntahan, at bibigyan kita ng direksyon bawat liko upang gabayan ka nang ligtas, aw aw!"
          : "Buddy: Woof! Open the Nav screen, type or speak your destination, and I will give you turn-by-turn audio directions to guide you safely, arf!";
    }
    if (lowerQ.contains("enable gemini") || lowerQ.contains("use gemini") || lowerQ.contains("gemini api") || lowerQ.contains("advanced feature") || lowerQ.contains("enable advanced")) {
      return isUserFilipino
          ? "Buddy: Aw! Opo! Maaari mong paganahin ang Gemini sa pamamagitan ng paglalagay ng iyong API key sa Settings. Sa ilalim ng AI Settings, maaari kang magpalipat-lipat sa Gemini para sa advanced na kakayahan at Local AI para sa offline na paggamit, arf!"
          : "Buddy: Arf! Yes! You can enable Gemini by entering your API key in Settings. Under AI Settings, you can switch between Gemini for advanced capabilities and Local AI for offline use, woof!";
    }
    if (lowerQ.contains("what is easylens") || lowerQ.contains("about easylens")) {
      return isUserFilipino
          ? "Buddy: Ang EasyLens ay isang assistive app na dinisenyo sa Holy Angel University upang tulungan ang mga taong may kapansanan sa paningin na mag-navigate at makilala ang mga bagay sa kanilang paligid, arf!"
          : "Buddy: EasyLens is an assistive app designed at Holy Angel University to help visually impaired individuals navigate and recognize things around them, arf!";
    }
    if (lowerQ.contains("mobility aids") || lowerQ.contains("mobility aid") || lowerQ.contains("wheelchair") || lowerQ.contains("cane")) {
      return isUserFilipino
          ? "Buddy: Arf! Sinusuportahan namin ang mga walking cane, wheelchair, at gabay na aso. Maaari mong piliin ang iyong mobility aid sa settings profile, aw aw!"
          : "Buddy: Woof! We support walking canes, wheelchairs, and guide dogs. You can select your mobility aid in the settings profile, arf!";
    }

    // 1. Identity & Name questions
    if (lowerQ.contains("name") || lowerQ.contains("who am i") || lowerQ.contains("know me")) {
      return isUserFilipino
          ? "Buddy: Aw aw! Oo naman, kilala kita! Ikaw si $name, at gumagamit ka ng $aid. Paano kita matutulungan ngayon, arf!"
          : "Buddy: Woof! Yes, I know you! You are $name, and you are using the $aid mobility aid. How can I help you today, arf!";
    }
    if (lowerQ.contains("who are you") || lowerQ.contains("your name") || lowerQ.contains("who is buddy") || lowerQ.contains("breed") || lowerQ.contains("dog")) {
      return isUserFilipino
          ? "Buddy: Arf! Ako si Buddy, ang magiliw na Golden Retriever mascot at AI guide dog ng EasyLens app. Aw aw!"
          : "Buddy: Arf! I'm Buddy, the friendly Golden Retriever mascot and AI guide dog for the EasyLens app. Woof!";
    }

    // 2. Creators & Thesis questions
    if (lowerQ.contains("who made") || lowerQ.contains("developer") || lowerQ.contains("created") || lowerQ.contains("thesis") || lowerQ.contains("author") || lowerQ.contains("architect") || lowerQ.contains("design") || lowerQ.contains("team") || lowerQ.contains("members")) {
      return isUserFilipino
          ? "Buddy: Aw aw! Ang EasyLens ay binuo ng pangkat ng mga mag-aaral ng Computer Science sa Holy Angel University: Arron Kian Parejas, Jian Kalel Marquez, Graciella Mhervie Jimenez, at Jenica Sarah Tongol, arf!"
          : "Buddy: Woof! EasyLens was developed by a team of 4th-year Computer Science students at Holy Angel University: Arron Kian Parejas, Jian Kalel Marquez, Graciella Mhervie Jimenez, and Jenica Sarah Tongol, arf!";
    }

    // 3. Greeting questions
    if (lowerQ == "hi" || lowerQ == "hello" || lowerQ == "hey" || lowerQ.contains("kamusta") || lowerQ.contains("kumusta")) {
      return isUserFilipino
          ? "Buddy: Aw aw! Kumusta si $name! Handa na akong tulungan kang mag-navigate o sumagot ng mga tanong tungkol sa EasyLens, arf!"
          : "Buddy: Woof! Hi $name! I'm ready to help you navigate or answer questions about EasyLens, arf!";
    }

    // 4. Emergency / SOS questions
    if (lowerQ.contains("sos") || lowerQ.contains("emergency") || lowerQ.contains("help")) {
      return isUserFilipino
          ? "Buddy: Arf! Kung kailangan mo ng tulong, i-tap ang SOS button para ipadala agad ang iyong lokasyon sa iyong caregiver! [NAVIGATE: emergency]"
          : "Buddy: Arf! If you need help, tap the SOS button to send your GPS coordinates to your caregiver contact immediately! [NAVIGATE: emergency]";
    }

    // 5. Navigation target guides
    if (lowerQ.contains("go to") || lowerQ.contains("navigate") || lowerQ.contains("where is") || lowerQ.contains("how to walk")) {
      if (lowerQ.contains("hau") || lowerQ.contains("holy angel")) {
        return isUserFilipino
            ? "Buddy: Ang Holy Angel University ay nasa Angeles City, Pampanga. Maaari kitang gabayan doon! [NAVIGATE: nav]"
            : "Buddy: Holy Angel University is at Angeles City, Pampanga (GPS: 15.1325, 120.5901). I can navigate you there! [NAVIGATE: nav]";
      }
      if (lowerQ.contains("auf") || lowerQ.contains("angeles university")) {
        return isUserFilipino
            ? "Buddy: Ang Angeles University Foundation ay nasa MacArthur Highway, Angeles City. [NAVIGATE: nav]"
            : "Buddy: Angeles University Foundation is along MacArthur Highway, Angeles City. [NAVIGATE: nav]";
      }
      if (lowerQ.contains("sm") || lowerQ.contains("clark")) {
        return isUserFilipino
            ? "Buddy: Ang SM City Clark ay nasa M.A. Roxas Highway, Clark Freeport Zone. [NAVIGATE: nav]"
            : "Buddy: SM City Clark is at M.A. Roxas Highway, Clark Freeport Zone. [NAVIGATE: nav]";
      }
      if (lowerQ.contains("nepo")) {
        return isUserFilipino
            ? "Buddy: Ang Nepo Mall ay nasa St. Joseph Street, Angeles City. [NAVIGATE: nav]"
            : "Buddy: Nepo Mall is located at St. Joseph Street, Angeles City. [NAVIGATE: nav]";
      }
    }

    // 6. RAG Fallback search in knowledge base S01
    final cleanQuery = lowerQ.replaceAll(RegExp(r'[^\w\s]'), '');
    final words = cleanQuery.split(RegExp(r'\s+'));
    KnowledgeItem? bestMatch;
    int bestScore = 0;

    for (var item in _localKnowledgeBase) {
      if (item.isTagalogItem != isUserFilipino) {
        continue;
      }
      int score = 0;
      for (var kw in item.keywords) {
        if (lowerQ.contains(kw.toLowerCase())) {
          score += 4;
        }
      }
      for (var word in words) {
        if (word.length > 2 && item.content.toLowerCase().contains(word)) {
          score += 1;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

    if (bestMatch != null && bestScore > 1) {
      // Keep it under 2 sentences to stay in character
      final sentences = bestMatch.content.split(RegExp(r'(?<=[.!?])\s+'));
      final summary = sentences.take(2).join(" ");
      return isUserFilipino
          ? "Buddy: Aw! Ayon sa aking database: $summary Arf!"
          : "Buddy: Woof! According to my database: $summary Arf!";
    }

    return isUserFilipino
        ? "Buddy: Aw aw! Nakikita ko ang malinaw na daan sa unahan. Sabihin mo lang kung nais mong ilarawan ko ang paligid, mag-navigate, o mag-set up ng emergency alert, arf!"
        : "Buddy: Arf! I see a clear pathway ahead. Let me know if you want me to describe the scene, navigate somewhere, or set up emergency alerts, woof!";
  }

  /// Builds a Tagalog-language Gemma prompt.
  /// Writing the entire prompt in Filipino forces Gemma's instruction-tuned
  /// model to mirror the language and respond in Tagalog.
  String _buildFilipinoPrompt(String userQuestion, String userName, String mobilityAid) {
    return """
Ikaw si Buddy, ang tapat na golden retriever na gabay ng EasyLens app.
Lagi kang sumasagot sa wikang Filipino/Tagalog — hindi ka gumagamit ng Ingles.
Ikaw ay masaya, matulungin, at maaasahan tulad ng isang aso.
Pangalan ng gumagamit: $userName. Gamit niya: $mobilityAid.

Mga utos ng navigation — isama sa DULO ng iyong sagot (opsyonal):
[NAVIGATE: home] — para sa Home screen
[NAVIGATE: nav] — para sa Audio Navigation
[NAVIGATE: hardware] — para sa EasyLens Camera/Sensor
[NAVIGATE: text] — para sa Text Scanner
[NAVIGATE: objects] — para sa Object Detector
[NAVIGATE: emergency] — para sa SOS Emergency
[NAVIGATE: settings] — para sa Settings
[NAVIGATE: notifications] — para sa Mga Abiso
[NAVIGATE: contacts] — para sa Mga Kontak

Halimbawa ng tamang sagot:
Tanong: Kumusta ka?
Buddy: Mabuti naman, $userName! Masaya akong makita ka ngayon. 🐾 Paano kita matutulungan?

Tanong: $userQuestion
Buddy:""";
  }

  /// Sends a question to Gemma using a fully Filipino prompt so the model
  /// responds in Tagalog. Falls back to the offline instructions if the model
  /// file is not present on the device.
  Future<String> askBuddyFilipino(String question, String userName, String mobilityAid) async {
    final promptText = _buildFilipinoPrompt(question, userName, mobilityAid);
    final modelPath = await _getLocalModelPath();
    if (modelPath != null) {
      return await _queryGemmaOffline(promptText);
    } else {
      // Fallback 1: Online Gemini
      final onlineRes = await askBuddyGemini(question, userName, mobilityAid);
      if (onlineRes.isNotEmpty &&
          !onlineRes.contains("Hindi available") &&
          !onlineRes.contains("May problema")) {
        return onlineRes;
      }
      
      // Fallback 2: Dynamic local RAG response generator in Filipino
      final context = retrieveContext(question);
      final greetings = [
        "Aw aw! Ako si Buddy! 🐾",
        "Arf! Heto ang alam ko tungkol diyan: 🐶",
        "Kumusta! Bilang iyong gabay, narito ang impormasyon: 🐾",
        "Aw aw! Heto ang sagot ko sa iyo: 🐕"
      ];
      final randomGreeting = greetings[DateTime.now().millisecond % greetings.length];
      
      if (context.startsWith("Buddy is the EasyLens")) {
        return "$randomGreeting Ako si Buddy, ang iyong tapat na gabay! Matutulungan kita sa pag-navigate, pagbasa ng teksto, at pagkilala ng mga bagay o mukha gamit ang camera. Sabihin mo lang kung saan natin gusto pumunta! 🐾";
      } else {
        return "$randomGreeting Mula sa aking kaalaman:\n\n$context\n\nSana ay nakatulong ito sa iyo! 🐾";
      }
    }
  }

  static List<String> getGeminiApiKeys() {
    final List<String> keys = [];
    final k1 = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    final k2 = dotenv.env['GEMINI_API_KEY2']?.trim() ?? '';
    final k3 = dotenv.env['GEMINI_API_KEY3']?.trim() ?? '';
    final k4 = dotenv.env['GEMINI_API_KEY4']?.trim() ?? '';

    if (k1.isNotEmpty) keys.add(k1);
    if (k2.isNotEmpty) keys.add(k2);
    if (k3.isNotEmpty) keys.add(k3);
    if (k4.isNotEmpty) keys.add(k4);
    return keys;
  }

  static Future<T> executeWithApiKeyFallback<T>(Future<T> Function(String apiKey) apiCall) async {
    final List<String> keys = [];
    final userKey = SettingsService().geminiApiKey.trim();
    if (userKey.isNotEmpty) {
      keys.add(userKey);
    }
    keys.addAll(getGeminiApiKeys());

    if (keys.isEmpty) {
      throw Exception('No Gemini API keys found. Please set one in Settings or environment variables.');
    }
    
    Object? lastError;
    for (var key in keys) {
      try {
        return await apiCall(key.trim());
      } catch (e) {
        final maskedKey = key.length > 4 ? '...${key.substring(key.length - 4)}' : '...';
        print('[RagService] API Call failed with key $maskedKey: $e');
        lastError = e;
      }
    }
    throw lastError ?? Exception('All Gemini API keys failed.');
  }

  /// Translates an English Gemma response to Filipino using Gemini API.
  /// Preserves any [NAVIGATE: x] tags so app routing still works after translation.
  Future<String> translateToFilipino(String englishText) async {
    try {
      // Extract [NAVIGATE: x] tag before translating so it isn't mangled
      final navRegex = RegExp(r'\[NAVIGATE:[^\]]+\]', caseSensitive: false);
      final navMatch = navRegex.firstMatch(englishText);
      final navTag = navMatch?.group(0) ?? '';
      final textOnly = englishText.replaceAll(navRegex, '').trim();

      final prompt = 'Translate the following text to Filipino/Tagalog. '
          'Keep the same friendly, enthusiastic tone. '
          'Do NOT translate proper nouns like app names. '
          'Return ONLY the translated text, nothing else.\n\n'
          'Text: $textOnly';

      final translated = await executeWithApiKeyFallback((apiKey) async {
        final model = GenerativeModel(
          model: 'gemini-3.5-flash',
          apiKey: apiKey,
        );
        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);
        return response.text?.trim() ?? textOnly;
      });

      // Reattach navigation tag at the end if it existed
      return navTag.isNotEmpty ? '$translated $navTag' : translated;
    } catch (e) {
      print('[Translation] Failed: $e');
      return englishText; // fallback to English on error
    }
  }

  /// Sends a message directly to Gemini API. Dynamically checks the language setting S01
  /// to provide system instructions and output in the requested language (Tagalog/English).
  Future<String> askBuddyGemini(String question, String userName, String mobilityAid) async {
    try {
      final lang = SettingsService().selectedLanguage;
      final isFilipino = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

      final systemInstructionText = isFilipino
          ? 'Ikaw si Buddy, ang tapat at masayang golden retriever na gabay ng EasyLens app. '
            'Lagi kang sumasagot sa wikang Filipino/Tagalog — huwag kang gumamit ng Ingles. '
            'Ikaw ay palaging masaya, matulungin, at maaasahan. '
            'Pangalan ng gumagamit: $userName. Gumagamit siya ng: $mobilityAid. '
            'Magsagot nang maikli at malinaw (2-3 pangungusap lang). '
            'Kung kailangang mag-navigate sa isang screen, idagdag ang isa sa mga tag na ito sa DULO ng iyong sagot:\n'
            '[NAVIGATE: home] — Home screen\n'
            '[NAVIGATE: nav] — Audio Navigation\n'
            '[NAVIGATE: hardware] — EasyLens Camera/Sensor\n'
            '[NAVIGATE: text] — Text Scanner\n'
            '[NAVIGATE: objects] — Object Detector\n'
            '[NAVIGATE: emergency] — SOS Emergency\n'
            '[NAVIGATE: settings] — Settings\n'
            '[NAVIGATE: notifications] — Mga Abiso\n'
            '[NAVIGATE: contacts] — Mga Kontak\n'
            '[NAVIGATE: journal] — Talaarawan ni Buddy'
          : 'You are Buddy, the loyal and friendly golden retriever guide dog mascot of the EasyLens app. '
            'Always reply in English. '
            'You are always happy, helpful, and reliable. '
            'User\'s name: $userName. Using mobility aid: $mobilityAid. '
            'Keep your responses short and clear (2-3 sentences max). '
            'If you need to navigate to a screen, append exactly one of these tags to the END of your answer:\n'
            '[NAVIGATE: home] — Home screen\n'
            '[NAVIGATE: nav] — Audio Navigation\n'
            '[NAVIGATE: hardware] — EasyLens Camera/Sensor\n'
            '[NAVIGATE: text] — Text Scanner\n'
            '[NAVIGATE: objects] — Object Detector\n'
            '[NAVIGATE: emergency] — SOS Emergency\n'
            '[NAVIGATE: settings] — Settings\n'
            '[NAVIGATE: notifications] — Notifications\n'
            '[NAVIGATE: contacts] — Contacts\n'
            '[NAVIGATE: journal] — Buddy\'s Journal';

      final responseText = await executeWithApiKeyFallback((apiKey) async {
        final model = GenerativeModel(
          model: 'gemini-3.5-flash',
          apiKey: apiKey,
          systemInstruction: Content.system(systemInstructionText),
        );
        final content = [Content.text(question)];
        final response = await model.generateContent(content);
        return response.text?.trim() ?? (isFilipino ? 'Walang natanggap na sagot.' : 'No response received.');
      });
      
      _logToJournal(question, responseText);
      return responseText;
    } catch (e) {
      print('[Gemini Online] Error: $e');
      final isFilipino = SettingsService().selectedLanguage.toLowerCase().contains('tagalog') || 
                         SettingsService().selectedLanguage.toLowerCase().contains('filipino');
      return isFilipino
          ? 'May problema sa koneksyon. Subukan muli mamaya.'
          : 'Connection error. Please try again later.';
    }
  }

  Future<String> askBuddyOnlineGemini(String prompt) async {
    try {
      return await executeWithApiKeyFallback((apiKey) async {
        final model = GenerativeModel(
          model: 'gemini-3.5-flash',
          apiKey: apiKey,
        );
        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);
        return response.text?.trim() ?? "";
      });
    } catch (e) {
      print('[Gemini Online] Error: $e');
      return "";
    }
  }

  String generateSmartFallback(String question) {
    final context = retrieveContext(question);
    final greetings = [
      "Woof! Buddy here! 🐾",
      "Arf! I'd love to help you with that! 🐶",
      "Hello! As your vision companion, here is what I know: 🐾",
      "Hi there! Buddy is on it! 🐕"
    ];
    final randomGreeting = greetings[DateTime.now().millisecond % greetings.length];

    if (context.startsWith("Buddy is the EasyLens")) {
      return "$randomGreeting I'm Buddy, your local vision assistant. I help you navigate safely, read text signs, and recognize objects or faces in real time! How can I assist you today?";
    } else {
      return "$randomGreeting Based on my database:\n\n$context\n\nHope that helps! Let me know if you want me to navigate there or launch any scanner! 🐾";
    }
  }

  Future<void> simulateModelInstall() async {
    _isGemmaModelInstalled = true;
  }
}

class _Mutex {
  Future<void> _last = Future.value();

  Future<T> protect<T>(Future<T> Function() criticalSection) {
    final completer = Completer<void>();
    final next = _last.then((_) => criticalSection()).whenComplete(() {
      completer.complete();
    });
    _last = completer.future;
    return next;
  }
}

class RagDocument {
  final String title;
  final String content;
  final String source; // 'knowledge', 'journal_insight', 'journal_log'
  final Map<String, double> termFrequencies;

  RagDocument({
    required this.title,
    required this.content,
    required this.source,
    required this.termFrequencies,
  });
}

class TfidfEngine {
  final List<RagDocument> documents = [];
  final Map<String, double> idfs = {};
  
  static final Set<String> stopWords = {
    'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an', 'and', 'any', 'are', 'arent', 'as', 'at',
    'be', 'because', 'been', 'before', 'being', 'below', 'between', 'both', 'but', 'by', 'can', 'cant', 'cannot',
    'could', 'couldnt', 'did', 'didnt', 'do', 'does', 'doesnt', 'doing', 'dont', 'down', 'during', 'each', 'few',
    'for', 'from', 'further', 'had', 'hadnt', 'has', 'hasnt', 'have', 'havent', 'having', 'he', 'hed', 'hell',
    'hes', 'her', 'here', 'heres', 'hers', 'herself', 'him', 'himself', 'his', 'how', 'hows', 'i', 'id', 'ill',
    'im', 'ive', 'if', 'in', 'into', 'is', 'isnt', 'it', 'its', 'itself', 'lets', 'me', 'more', 'most', 'mustnt',
    'my', 'myself', 'no', 'nor', 'not', 'of', 'off', 'on', 'once', 'only', 'or', 'other', 'ought', 'our', 'ours',
    'ourselves', 'out', 'over', 'own', 'same', 'shannt', 'she', 'shed', 'shell', 'shes', 'should', 'shouldnt',
    'so', 'some', 'such', 'than', 'that', 'thats', 'the', 'their', 'theirs', 'them', 'themselves', 'then',
    'there', 'theres', 'these', 'they', 'theyd', 'theyll', 'theyre', 'theyve', 'this', 'those', 'through', 'to',
    'too', 'under', 'until', 'up', 'very', 'was', 'wasnt', 'we', 'wed', 'well', 'were', 'weve', 'werent', 'what',
    'whats', 'when', 'whens', 'where', 'wheres', 'which', 'while', 'who', 'whos', 'whom', 'why', 'whys', 'with',
    'wont', 'would', 'wouldnt', 'you', 'youd', 'youll', 'youre', 'youve', 'your', 'yours', 'yourself', 'yourselves'
  };

  List<String> tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty && !stopWords.contains(token))
        .toList();
  }

  void addDocument(String title, String content, String source) {
    final tokens = tokenize('$title $content');
    if (tokens.isEmpty) return;

    final Map<String, int> termCounts = {};
    for (var token in tokens) {
      termCounts[token] = (termCounts[token] ?? 0) + 1;
    }

    final Map<String, double> tfs = {};
    final totalTerms = tokens.length.toDouble();
    termCounts.forEach((term, count) {
      tfs[term] = count / totalTerms;
    });

    documents.add(RagDocument(
      title: title,
      content: content,
      source: source,
      termFrequencies: tfs,
    ));
  }

  void calculateIdfs() {
    idfs.clear();
    final numDocs = documents.length.toDouble();
    if (numDocs == 0) return;

    final Map<String, int> docCounts = {};
    for (var doc in documents) {
      for (var term in doc.termFrequencies.keys) {
        docCounts[term] = (docCounts[term] ?? 0) + 1;
      }
    }

    docCounts.forEach((term, count) {
      idfs[term] = math.log(1.0 + (numDocs / count.toDouble()));
    });
  }

  List<RagDocument> search(String query, {int limit = 2}) {
    final queryTokens = tokenize(query);
    if (queryTokens.isEmpty || documents.isEmpty) {
      return [];
    }

    final Map<String, int> queryCounts = {};
    for (var token in queryTokens) {
      queryCounts[token] = (queryCounts[token] ?? 0) + 1;
    }
    final Map<String, double> queryTfs = {};
    final totalQueryTerms = queryTokens.length.toDouble();
    queryCounts.forEach((term, count) {
      queryTfs[term] = count / totalQueryTerms;
    });

    final List<MapEntry<RagDocument, double>> scoredDocs = [];

    for (var doc in documents) {
      double dotProduct = 0.0;
      double queryNorm = 0.0;
      double docNorm = 0.0;

      final uniqueTerms = {...queryTfs.keys, ...doc.termFrequencies.keys};

      for (var term in uniqueTerms) {
        final idf = idfs[term] ?? 0.0;
        final qVal = (queryTfs[term] ?? 0.0) * idf;
        final dVal = (doc.termFrequencies[term] ?? 0.0) * idf;

        dotProduct += qVal * dVal;
        queryNorm += qVal * qVal;
        docNorm += dVal * dVal;
      }

      double similarity = 0.0;
      if (queryNorm > 0 && docNorm > 0) {
        similarity = dotProduct / (math.sqrt(queryNorm) * math.sqrt(docNorm));
      }

      scoredDocs.add(MapEntry(doc, similarity));
    }

    scoredDocs.sort((a, b) => b.value.compareTo(a.value));

    return scoredDocs
        .where((entry) => entry.value > 0.0)
        .map((entry) => entry.key)
        .take(limit)
        .toList();
  }
}
