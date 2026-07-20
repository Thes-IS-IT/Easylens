import 'package:flutter/material.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

// STEP 2: Who is this for?
class StepPersona extends StatelessWidget {
  final bool isForMyself;
  final String language;
  final ValueChanged<bool> onChanged;

  const StepPersona({
    super.key,
    required this.isForMyself,
    required this.language,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('persona_title', language),
          subtitle: SignupL10n.t('persona_subtitle', language),
        ),
        const SizedBox(height: 32),
        OptionCard(
          title: SignupL10n.t('persona_myself', language),
          isSelected: isForMyself,
          icon: Icons.person_outline,
          onTap: () => onChanged(true),
        ),
        const SizedBox(height: 16),
        OptionCard(
          title: SignupL10n.t('persona_someone_else', language),
          isSelected: !isForMyself,
          icon: Icons.group_outlined,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}
