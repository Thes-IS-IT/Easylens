import 'dart:async';
import 'package:flutter/material.dart';
import 'tts_service.dart';
import 'stt_service.dart';
import 'settings_service.dart';

class NavigationVoiceAssistant {
  static Future<void> activateSearchAssistant({
    required BuildContext context,
    required Future<List<Map<String, dynamic>>> Function(String query) onQueryDiscovered,
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

    // Await async search execution so HTTP request & spatial filter complete
    final results = await onQueryDiscovered(finalQuery);

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
      final name = place['name'] ?? 'Destination';
      final dist = place['dist'] ?? '';
      final time = place['time'] ?? '';
      
      final speech = isTagalog
          ? "Nahanap ang $name, $dist ang layo, humigit-kumulang $time biyahe. Nais mo bang simulan ang nabigasyon?"
          : "Found $name, $dist away, $time travel time. Would you like to start navigation?";
      
      await TtsService().speakAwait(speech);
      onPlaceConfirmed(place);
      return;
    }

    // Present up to 5 distinct branch options dynamically
    final count = results.length > 5 ? 5 : results.length;
    final sb = StringBuffer();
    sb.write(isTagalog
        ? "May nahanap akong $count na lokasyon para sa '$finalQuery'. "
        : "Found $count locations for '$finalQuery'. ");

    for (int i = 0; i < count; i++) {
      final name = results[i]['name'] ?? 'Place';
      final dist = results[i]['dist'] ?? '';
      final numWord = "${i + 1}";

      if (dist.isNotEmpty) {
        sb.write(isTagalog
            ? "Sabihin ang $numWord para sa $name, $dist ang layo. "
            : "Say $numWord for $name, $dist away. ");
      } else {
        sb.write(isTagalog
            ? "Sabihin ang $numWord para sa $name. "
            : "Say $numWord for $name. ");
      }
    }
    sb.write(isTagalog
        ? "Alin sa mga ito ang nais mo?"
        : "Which option would you like?");

    await TtsService().speakAwait(sb.toString());
    await Future.delayed(const Duration(milliseconds: 300));

    // Listen for user's option choice (e.g., "1", "Jollibee Sindalan", "two")
    String choiceInput = "";
    final choiceCompleter = Completer<String>();

    await SttService().startListening(
      onListeningStateChanged: (_) {},
      onResult: (text, isFinal) {
        if (TtsService().isSpeaking || TtsService().isSelfEcho(text)) return;
        if (text.trim().isNotEmpty) {
          choiceInput = text.trim();
          if (isFinal && !choiceCompleter.isCompleted) {
            choiceCompleter.complete(choiceInput);
          }
        }
      },
    );

    Timer(const Duration(seconds: 6), () {
      if (!choiceCompleter.isCompleted) {
        choiceCompleter.complete(choiceInput);
      }
    });

    final userChoice = (await choiceCompleter.future).toLowerCase().trim();
    await SttService().stopListening((_) {});

    int selectedIndex = -1;
    if (userChoice.contains('1') || userChoice.contains('one') || userChoice.contains('first') || userChoice.contains('una')) {
      selectedIndex = 0;
    } else if (userChoice.contains('2') || userChoice.contains('two') || userChoice.contains('second') || userChoice.contains('pangalawa')) {
      selectedIndex = 1;
    } else if (userChoice.contains('3') || userChoice.contains('three') || userChoice.contains('third') || userChoice.contains('pangatlo')) {
      selectedIndex = 2;
    } else if (userChoice.contains('4') || userChoice.contains('four') || userChoice.contains('fourth') || userChoice.contains('apat')) {
      selectedIndex = 3;
    } else if (userChoice.contains('5') || userChoice.contains('five') || userChoice.contains('fifth') || userChoice.contains('lima')) {
      selectedIndex = 4;
    } else {
      for (int i = 0; i < count; i++) {
        final pName = (results[i]['name'] as String? ?? '').toLowerCase();
        if (pName.isNotEmpty && userChoice.contains(pName)) {
          selectedIndex = i;
          break;
        }
      }
    }

    if (selectedIndex >= 0 && selectedIndex < results.length) {
      final selectedPlace = results[selectedIndex];
      final selName = selectedPlace['name'] ?? 'Destination';
      final confirmSpeech = isTagalog
          ? "Pinili ang $selName. Sinisimulan ang nabigasyon."
          : "Selected $selName. Starting navigation.";
      TtsService().speak(confirmSpeech);
      onPlaceConfirmed(selectedPlace);
    }
  }
}
