import 'dart:async';
import 'package:flutter/material.dart';
import 'tts_service.dart';
import 'stt_service.dart';
import 'settings_service.dart';

class NavigationVoiceAssistant {
  static Future<void> activateSearchAssistant({
    required BuildContext context,
    required Function(String query) onQueryDiscovered,
    required List<Map<String, dynamic>> Function() getSearchResults,
    required Function(Map<String, dynamic> place) onPlaceConfirmed,
  }) async {
    final lang = SettingsService().selectedLanguage;
    final isTagalog = lang.toLowerCase().contains('tagalog') || lang.toLowerCase().contains('filipino');

    final prompt = isTagalog
        ? "Anong lugar ang nais mong hanapin?"
        : "What destination would you like to search for?";

    await TtsService().speakAwait(prompt);
    await Future.delayed(const Duration(milliseconds: 500));

    String recognizedQuery = "";
    final completer = Completer<String>();

    await SttService().startListening(
      onListeningStateChanged: (_) {},
      onResult: (text, isFinal) {
        if (TtsService().isSpeaking || TtsService().isSelfEcho(text)) return;
        if (text.trim().isNotEmpty) {
          recognizedQuery = text.trim();
          if (isFinal && !completer.isCompleted) {
            completer.complete(recognizedQuery);
          }
        }
      },
    );

    // Timeout safety for 5 seconds of listening
    Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete(recognizedQuery);
      }
    });

    final finalQuery = await completer.future;
    await SttService().stopListening((_) {});

    if (finalQuery.trim().isEmpty) {
      TtsService().speak(isTagalog ? "Hindi narinig ang lugar." : "No destination heard.");
      return;
    }

    onQueryDiscovered(finalQuery);
    await Future.delayed(const Duration(milliseconds: 800));

    final results = getSearchResults();
    if (results.isEmpty) {
      TtsService().speak(
        isTagalog
            ? "Paumanhin, walang nahanap na lugar para sa '$finalQuery'."
            : "Sorry, no places found for '$finalQuery'.",
      );
      return;
    }

    if (results.length == 1) {
      final place = results.first;
      onPlaceConfirmed(place);
      return;
    }

    final count = results.length > 5 ? 5 : results.length;
    final sb = StringBuffer();
    sb.write(isTagalog
        ? "May nahanap akong $count na lugar. "
        : "I found $count places. ");
    for (int i = 0; i < count; i++) {
      sb.write("${i + 1}: ${results[i]['name']}. ");
    }
    sb.write(isTagalog
        ? "Mangyaring pumili sa screen o sabihin ang numero."
        : "Please tap a place on screen or say the number.");

    TtsService().speak(sb.toString());
  }
}
