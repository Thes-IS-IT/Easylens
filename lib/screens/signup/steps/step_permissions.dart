import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import 'step_helpers.dart';

// STEP 15: Permissions
class StepPermissions extends StatefulWidget {
  final VoidCallback onContinue;

  const StepPermissions({
    super.key,
    required this.onContinue,
  });

  @override
  State<StepPermissions> createState() => _StepPermissionsState();
}

class _StepPermissionsState extends State<StepPermissions> {
  bool _camera = false;
  bool _microphone = false;
  bool _location = false;
  bool _bluetooth = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: 'Permissions',
          subtitle: 'Allow access to core services for sensors and speech systems.',
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text('Camera Access', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                value: _camera,
                activeColor: AppColors.primaryButton,
                onChanged: (val) => setState(() => _camera = val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text('Microphone Access', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                value: _microphone,
                activeColor: AppColors.primaryButton,
                onChanged: (val) => setState(() => _microphone = val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text('Location Service', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                value: _location,
                activeColor: AppColors.primaryButton,
                onChanged: (val) => setState(() => _location = val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text('Bluetooth Access', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                value: _bluetooth,
                activeColor: AppColors.primaryButton,
                onChanged: (val) => setState(() => _bluetooth = val),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
