import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../services/stt_service.dart';

/// Helper to sanitize spoken input based on expected input type
String formatSpokenText(String input, {TextInputType? keyboardType, bool isEmail = false, bool isPhone = false, bool isCode = false}) {
  String text = input.trim();
  if (text.isEmpty) return text;

  if (isEmail || keyboardType == TextInputType.emailAddress) {
    text = text.toLowerCase()
        .replaceAll(' at ', '@')
        .replaceAll(' at', '@')
        .replaceAll('at ', '@')
        .replaceAll(' dot ', '.')
        .replaceAll(' dot', '.')
        .replaceAll('dot ', '.')
        .replaceAll(' ', '');
    return text;
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
