import 'package:flutter_test/flutter_test.dart';
import 'package:easylens/services/rag_service.dart';

void main() {
  group('RAG Service Context Retrieval Tests', () {
    final ragService = RagService();

    test('Should retrieve context for questions about Buddy identity', () {
      final context = ragService.retrieveContext('Who are you, Buddy?');
      expect(context.contains("Buddy's Identity"), isTrue);
      expect(context.contains("golden retriever"), isTrue);
    });

    test('Should retrieve context for safety or companion questions', () {
      final context = ragService.retrieveContext('How to monitor safety in companion mode?');
      expect(context.contains("Companion Guidelines"), isTrue);
      expect(context.contains("caregiver"), isTrue);
    });

    test('Should fall back to default context if no keywords match', () {
      final context = ragService.retrieveContext('What is the weather today?');
      expect(context.contains("vision assistant"), isTrue);
    });
  });
}
