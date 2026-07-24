import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../services/stt_service.dart';

String formatSpokenEmail(String input) {
  try {
    String text = input.trim().toLowerCase();
    if (text.isEmpty) return text;

    // Convert common spoken words/Tagalog terms to email symbols
    text = text
        .replaceAll(RegExp(r'\b(at|ako|et|atsign|at sign)\b', caseSensitive: false), '@')
        .replaceAll(RegExp(r'\b(dot|punto|tuldok)\b', caseSensitive: false), '.')
        .replaceAll(RegExp(r'\s+'), '');

    // Fix common domain misspellings from speech-to-text
    text = text
        .replaceAll('gmailcom', 'gmail.com')
        .replaceAll('yahoocom', 'yahoo.com')
        .replaceAll('hotmailcom', 'hotmail.com')
        .replaceAll('outlookcom', 'outlook.com')
        .replaceAll('icloudcom', 'icloud.com');

    // If user spoke a username without @ (e.g. "parehas" or "arronparejas"), append @gmail.com
    if (!text.contains('@')) {
      text = '$text@gmail.com';
    }

    return text;
  } catch (_) {
    return input.trim().replaceAll(' ', '');
  }
}

/// Helper to parse spoken date into MM / DD / YYYY format (e.g. "January 6, 2005" -> "01 / 06 / 2005")
String formatSpokenBirthday(String input) {
  String text = input.trim().toLowerCase();
  if (text.isEmpty) return text;

  final months = {
    'january': 1, 'jan': 1, 'enero': 1,
    'february': 2, 'feb': 2, 'pabrero': 2, 'pebrero': 2,
    'march': 3, 'mar': 3, 'marso': 3,
    'april': 4, 'apr': 4, 'abril': 4,
    'may': 5, 'mayo': 5,
    'june': 6, 'jun': 6, 'hunyo': 6,
    'july': 7, 'jul': 7, 'hulyo': 7,
    'august': 8, 'aug': 8, 'agosto': 8,
    'september': 9, 'sep': 9, 'sept': 9, 'setyembre': 9,
    'october': 10, 'oct': 10, 'oktubre': 10,
    'november': 11, 'nov': 11, 'nobyembre': 11,
    'december': 12, 'dec': 12, 'disyembre': 12,
  };

  final wordNumbers = {
    'first': 1, '1st': 1, 'one': 1, 'una': 1,
    'second': 2, '2nd': 2, 'two': 2, 'pangalawa': 2,
    'third': 3, '3rd': 3, 'three': 3, 'pangatlo': 3,
    'fourth': 4, '4th': 4, 'four': 4,
    'fifth': 5, '5th': 5, 'five': 5,
    'sixth': 6, '6th': 6, 'six': 6,
    'seventh': 7, '7th': 7, 'seven': 7,
    'eighth': 8, '8th': 8, 'eight': 8,
    'ninth': 9, '9th': 9, 'nine': 9,
    'tenth': 10, '10th': 10, 'ten': 10,
    'eleventh': 11, '11th': 11, 'eleven': 11,
    'twelfth': 12, '12th': 12, 'twelve': 12,
    'thirteenth': 13, '13th': 13, 'thirteen': 13,
    'fourteenth': 14, '14th': 14, 'fourteen': 14,
    'fifteenth': 15, '15th': 15, 'fifteen': 15,
    'sixteenth': 16, '16th': 16, 'sixteen': 16,
    'seventeenth': 17, '17th': 17, 'seventeen': 17,
    'eighteenth': 18, '18th': 18, 'eighteen': 18,
    'nineteenth': 19, '19th': 19, 'nineteen': 19,
    'twentieth': 20, '20th': 20, 'twenty': 20,
    'twenty first': 21, '21st': 21, 'twenty-first': 21,
    'twenty second': 22, '22nd': 22, 'twenty-second': 22,
    'twenty third': 23, '23rd': 23, 'twenty-third': 23,
    'twenty fourth': 24, '24th': 24, 'twenty-fourth': 24,
    'twenty fifth': 25, '25th': 25, 'twenty-fifth': 25,
    'twenty sixth': 26, '26th': 26, 'twenty-sixth': 26,
    'twenty seventh': 27, '27th': 27, 'twenty-seventh': 27,
    'twenty eighth': 28, '28th': 28, 'twenty-eighth': 28,
    'twenty ninth': 29, '29th': 29, 'twenty-ninth': 29,
    'thirtieth': 30, '30th': 30, 'thirty': 30,
    'thirty first': 31, '31st': 31, 'thirty-first': 31,
  };

  int? month;
  months.forEach((key, val) {
    if (text.contains(key)) {
      month = val;
    }
  });

  final yearMatch = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(text);
  int? year = yearMatch != null ? int.tryParse(yearMatch.group(0)!) : null;

  int? day;
  final dayMatches = RegExp(r'\b([0-3]?[0-9])(st|nd|rd|th)?\b').allMatches(text);
  for (var m in dayMatches) {
    final numVal = int.tryParse(m.group(1)!);
    if (numVal != null && numVal >= 1 && numVal <= 31 && numVal != year && numVal != month) {
      day = numVal;
      break;
    }
  }

  if (day == null) {
    wordNumbers.forEach((key, val) {
      if (text.contains(key) && val >= 1 && val <= 31 && val != month) {
        day = val;
      }
    });
  }

  if (month != null && day != null && year != null) {
    final mStr = month.toString().padLeft(2, '0');
    final dStr = day.toString().padLeft(2, '0');
    return '$mStr / $dStr / $year';
  }

  final allDigits = text.replaceAll(RegExp(r'\D+'), ' ').trim().split(RegExp(r'\s+'));
  if (allDigits.length >= 3) {
    final m = int.tryParse(allDigits[0]);
    final d = int.tryParse(allDigits[1]);
    final y = int.tryParse(allDigits[2]);
    if (m != null && d != null && y != null && m >= 1 && m <= 12 && d >= 1 && d <= 31 && y >= 1900) {
      return '${m.toString().padLeft(2, '0')} / ${d.toString().padLeft(2, '0')} / $y';
    }
  }

  return input;
}

/// Helper to sanitize spoken input based on expected input type
String formatSpokenText(String input, {TextInputType? keyboardType, bool isEmail = false, bool isPhone = false, bool isCode = false, bool isBirthday = false}) {
  String text = input.trim();
  if (text.isEmpty) return text;

  if (isBirthday) {
    return formatSpokenBirthday(text);
  }

  if (isEmail || keyboardType == TextInputType.emailAddress) {
    return formatSpokenEmail(text);
  }

  if (isPhone || isCode || keyboardType == TextInputType.phone || keyboardType == TextInputType.number) {
    // Convert word numbers to digit string
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final wordToDigit = {
      'zero': '0', 'oh': '0',
      'one': '1', 'won': '1',
      'two': '2', 'to': '2', 'too': '2',
      'three': '3',
      'four': '4', 'for': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8', 'ate': '8',
      'nine': '9',
    };

    StringBuffer digits = StringBuffer();
    for (var w in words) {
      if (wordToDigit.containsKey(w)) {
        digits.write(wordToDigit[w]);
      } else {
        final cleanDigits = w.replaceAll(RegExp(r'\D'), '');
        digits.write(cleanDigits);
      }
    }

    String result = digits.toString();
    if (isPhone || keyboardType == TextInputType.phone) {
      if (result.length > 11) {
        result = result.substring(0, 11);
      }
    } else if (isCode) {
      if (result.length > 4) {
        result = result.substring(0, 4);
      }
    }
    return result;
  }

  return text;
}

/// Mic Icon Button intended for TextField suffixIcon or inline use
class VoiceMicIconButton extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool isEmail;
  final bool isPhone;
  final bool isCode;

  const VoiceMicIconButton({
    super.key,
    required this.controller,
    this.onChanged,
    this.keyboardType,
    this.isEmail = false,
    this.isPhone = false,
    this.isCode = false,
  });

  @override
  State<VoiceMicIconButton> createState() => _VoiceMicIconButtonState();
}

class _VoiceMicIconButtonState extends State<VoiceMicIconButton> with SingleTickerProviderStateMixin {
  bool _isListening = false;
  Timer? _silenceTimer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 2), () {
      _stopListening();
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
    });

    _resetSilenceTimer();

    await SttService().startListening(
      onResult: (rawText, isFinal) {
        _resetSilenceTimer();

        final formatted = formatSpokenText(
          rawText,
          keyboardType: widget.keyboardType,
          isEmail: widget.isEmail,
          isPhone: widget.isPhone,
          isCode: widget.isCode,
        );

        if (formatted.isNotEmpty) {
          widget.controller.text = formatted;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: formatted.length),
          );
          widget.onChanged?.call(formatted);
        }

        if (isFinal) {
          _stopListening();
        }
      },
      onListeningStateChanged: (listening) {
        if (!listening && mounted) {
          _silenceTimer?.cancel();
          setState(() {
            _isListening = false;
          });
        }
      },
    );
  }

  Future<void> _stopListening() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    await SttService().stopListening((_) {});
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final color = _isListening
              ? Color.lerp(Colors.redAccent, Colors.red, _animController.value)!
              : AppColors.textMuted;
          final scale = _isListening ? 1.0 + (_animController.value * 0.2) : 1.0;

          return Transform.scale(
            scale: scale,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isListening ? Colors.red.withOpacity(0.12) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_outlined,
                  color: _isListening ? Colors.redAccent : color,
                  size: 22,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Large Circular Mic Button for steps with prominent speech recognition UI
class VoiceMicBigButton extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String label;
  final TextInputType? keyboardType;

  const VoiceMicBigButton({
    super.key,
    required this.controller,
    this.onChanged,
    required this.label,
    this.keyboardType,
  });

  @override
  State<VoiceMicBigButton> createState() => _VoiceMicBigButtonState();
}

class _VoiceMicBigButtonState extends State<VoiceMicBigButton> with SingleTickerProviderStateMixin {
  bool _isListening = false;
  Timer? _silenceTimer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 2), () {
      _stopListening();
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
    });

    _resetSilenceTimer();

    await SttService().startListening(
      onResult: (rawText, isFinal) {
        _resetSilenceTimer();

        final formatted = formatSpokenText(rawText, keyboardType: widget.keyboardType);
        if (formatted.isNotEmpty) {
          widget.controller.text = formatted;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: formatted.length),
          );
          widget.onChanged?.call(formatted);
        }

        if (isFinal) {
          _stopListening();
        }
      },
      onListeningStateChanged: (listening) {
        if (!listening && mounted) {
          _silenceTimer?.cancel();
          setState(() {
            _isListening = false;
          });
        }
      },
    );
  }

  Future<void> _stopListening() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    await SttService().stopListening((_) {});
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final scale = _isListening ? 1.0 + (_animController.value * 0.08) : 1.0;
                final borderColor = _isListening ? Colors.redAccent : AppColors.primaryButton;
                final iconColor = _isListening ? Colors.redAccent : AppColors.primaryButton;
                final bgColor = _isListening ? Colors.red.withOpacity(0.08) : Colors.transparent;

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: _isListening ? 3.5 : 2.5),
                      color: bgColor,
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.25),
                                blurRadius: 16,
                                spreadRadius: 4,
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: 52,
                      color: iconColor,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _isListening ? 'Listening... (auto-off in 2s)' : widget.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
              color: _isListening ? Colors.redAccent : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
