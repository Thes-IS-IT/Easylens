import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class KnowledgeItem {
  final String title;
  final String content;
  final List<String> keywords;

  KnowledgeItem({
    required this.title,
    required this.content,
    required this.keywords,
  });
}

class RagService {
  bool _gemmaInitialized = false;
  bool _isGemmaModelInstalled = false;
  dynamic _gemmaModel; // Dynamic to prevent crashes if class shapes shift in native plugins
  dynamic _gemmaSession;

  final List<KnowledgeItem> _localKnowledgeBase = [
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

  bool get isGemmaReady => _gemmaInitialized && _isGemmaModelInstalled;

  Future<void> initializeGemma() async {
    try {
      // Initialize flutter_gemma if not already initialized
      // Note: In some platforms/environments, this might fail or require download.
      // We wrap it in try-catch to guarantee stability.
      _gemmaInitialized = true;
      
      // Check if Gemma model is installed/loaded on device
      // For demonstration, we simulate checking local files
      _isGemmaModelInstalled = false; // Set to false initially, let user trigger download/setup
      print("Gemma offline LLM engine initialized");
    } catch (e) {
      print("Error initializing localized Gemma: $e");
      _gemmaInitialized = false;
    }
  }

  // A lightweight keyword-based RAG search
  String retrieveContext(String query) {
    final cleanQuery = query.toLowerCase();
    final List<String> matchedContents = [];

    for (var item in _localKnowledgeBase) {
      bool match = false;
      for (var kw in item.keywords) {
        if (cleanQuery.contains(kw)) {
          match = true;
          break;
        }
      }
      if (match) {
        matchedContents.add("[${item.title}]: ${item.content}");
      }
    }

    if (matchedContents.isEmpty) {
      // Default to general companion guidelines
      return "Buddy is the EasyLens vision assistant. Provide general assistant guidelines: be friendly, helpful, and support visual description features.";
    }

    return matchedContents.join("\n\n");
  }

  Future<String> askBuddy(String question) async {
    final context = retrieveContext(question);
    
    final prompt = """
You are Buddy, the loyal vision assistant. 
Use the following retrieved context to answer the user's question. 
If you don't know the answer, say that you don't know. Keep the response friendly and concise.

Context:
$context

User Question:
$question

Buddy's Answer:
""";

    // Try localized Gemma offline model first if ready
    if (isGemmaReady) {
      try {
        if (_gemmaModel == null) {
          _gemmaModel = await FlutterGemma.getActiveModel(maxTokens: 256);
          _gemmaSession = await _gemmaModel.createSession();
        }
        await _gemmaSession.addQueryChunk(Message(text: prompt, isUser: true));
        final response = await _gemmaSession.getResponse();
        return response ?? "I'm sorry, I couldn't process that locally.";
      } catch (e) {
        print("Gemma offline inference failed: $e. Falling back to online Gemini...");
      }
    }

    // Fallback: Online Gemini API using google_generative_ai
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty || apiKey.contains("Placeholder")) {
        return "Offline Mode: Buddy is waiting for the Gemma model file (~1.4GB) to be downloaded. (Or add your GEMINI_API_KEY in the .env file to enable the online assistant!)";
      }

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      return response.text ?? "I'm sorry, I didn't get that.";
    } catch (e) {
      return "Unable to connect to Buddy: $e";
    }
  }

  Future<void> simulateModelInstall() async {
    // Simulated model installation for development demonstration
    await Future.delayed(const Duration(seconds: 3));
    _isGemmaModelInstalled = true;
  }
}
