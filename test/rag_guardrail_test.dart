import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easylens/services/rag_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    
    // Mock path_provider channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  group('RagService Guardrails & Fallbacks Test', () {
    test('Test Off-Topic Math Filter Rejection', () async {
      final response = await RagService().askBuddyLocalOnly("what is 1+1?");
      expect(response, contains("designed specifically to assist with visual impairment"));
    });

    test('Test Off-Topic Trivia Filter Rejection', () async {
      final response = await RagService().askBuddyLocalOnly("who is the president of the United States?");
      expect(response, contains("cannot help with general queries, math, or trivia"));
    });

    test('Test Whitelisted Visual Assistant Query Pass', () async {
      final response = await RagService().askBuddyLocalOnly("read this text on the sign");
      expect(response, isNot(contains("designed specifically to assist with visual impairment")));
    });

    test('Test Curated Q&As: What is EasyLens', () async {
      final response = await RagService().askBuddyLocalOnly("what is EasyLens?");
      expect(response, contains("assistive app designed at Holy Angel University"));
    });

    test('Test Curated Q&As: How to read text', () async {
      final response = await RagService().askBuddyLocalOnly("how to read text?");
      expect(response, contains("Text Scanner (OCR)"));
    });

    test('Test Curated Q&As: How to register face', () async {
      final response = await RagService().askBuddyLocalOnly("how to register a face?");
      expect(response, contains("Face Registration"));
    });

    test('Test Curated Q&As: How to use this app', () async {
      final response = await RagService().askBuddyLocalOnly("How to use this app?");
      expect(response, contains("Swipe horizontally to switch"));
    });
  });
}
