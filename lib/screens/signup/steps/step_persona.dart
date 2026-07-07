import 'package:flutter/material.dart';
import 'step_helpers.dart';

// STEP 1: Who is this for?
class StepPersona extends StatelessWidget {
  final bool isForMyself;
  final ValueChanged<bool> onChanged;

  const StepPersona({
    super.key,
    required this.isForMyself,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Who is this for?',
          subtitle: 'Select to customize instructions for you or a companion.',
        ),
        const SizedBox(height: 32),
        OptionCard(
          title: 'Myself',
          isSelected: isForMyself,
          icon: Icons.person_outline,
          onTap: () => onChanged(true),
        ),
        const SizedBox(height: 16),
        OptionCard(
          title: 'Someone Else',
          isSelected: !isForMyself,
          icon: Icons.group_outlined,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}
