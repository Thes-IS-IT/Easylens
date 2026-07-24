import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../constants/colors.dart';
import '../../../l10n/signup_strings.dart';
import 'step_helpers.dart';

// STEP 19: Your SOS Contact
class StepSosContact extends StatefulWidget {
  final String name;
  final String phone;
  final String relationship;
  final String language;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<String> onRelationshipChanged;
  final VoidCallback onFinish;

  const StepSosContact({
    super.key,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.language,
    required this.onNameChanged,
    required this.onPhoneChanged,
    required this.onRelationshipChanged,
    required this.onFinish,
  });

  @override
  State<StepSosContact> createState() => _StepSosContactState();
}

class _StepSosContactState extends State<StepSosContact> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _relController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _phoneController = TextEditingController(text: widget.phone);
    _relController = TextEditingController(text: widget.relationship);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relController.dispose();
    super.dispose();
  }

  /// Strips all non-digit characters, converts +63, and trims to 11 digits.
  String _sanitizePhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    }
    return digits.length > 11 ? digits.substring(0, 11) : digits;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: SignupL10n.t('sos_title', widget.language),
          subtitle: SignupL10n.t('sos_subtitle', widget.language),
        ),
        const SizedBox(height: 24),

        // Import from Contacts button
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: AppColors.primaryButtonText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                // 1. Request permission so FlutterContacts can fetch contact properties
                try {
                  await FlutterContacts.permissions.request(PermissionType.read);
                } catch (_) {}

                // 2. Open native platform contact picker
                final picked = await FlutterContacts.native.showPicker();
                if (picked != null) {
                  // 3. Fetch full contact details with phone properties
                  Contact? fullContact;
                  final contactId = picked.id;
                  if (contactId != null && contactId.isNotEmpty) {
                    try {
                      fullContact = await FlutterContacts.get(
                        contactId,
                        properties: {ContactProperty.phone, ContactProperty.name},
                      );
                    } catch (e) {
                      print('Error fetching contact details: $e');
                    }
                  }
                  fullContact ??= picked;

                  final String displayName = fullContact.displayName ?? '';
                  final String firstName = fullContact.name?.first ?? '';
                  final String lastName = fullContact.name?.last ?? '';

                  final String name = displayName.isNotEmpty
                      ? displayName
                      : ('$firstName $lastName').trim();

                  String phone = '';
                  if (fullContact.phones.isNotEmpty) {
                    final numStr = fullContact.phones.firstWhere(
                      (p) => p.number.trim().isNotEmpty,
                      orElse: () => fullContact!.phones.first,
                    ).number;
                    phone = _sanitizePhone(numStr);
                  }

                  // 4. Fallback search if phone is still empty
                  if (phone.isEmpty && name.isNotEmpty) {
                    try {
                      final allContacts = await FlutterContacts.getAll(
                        properties: {ContactProperty.phone, ContactProperty.name},
                      );
                      for (final c in allContacts) {
                        if (c.id == picked.id || (c.displayName ?? '').toLowerCase() == name.toLowerCase()) {
                          if (c.phones.isNotEmpty) {
                            phone = _sanitizePhone(c.phones.first.number);
                            break;
                          }
                        }
                      }
                    } catch (_) {}
                  }

                  setState(() {
                    _nameController.text = name;
                    _phoneController.text = phone;
                  });
                  widget.onNameChanged(name);
                  widget.onPhoneChanged(phone);
                }
              } catch (e) {
                print('Native Contact Picker Error: $e');
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Failed to import contact. Please enter manually.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            icon: const Icon(Icons.phone_callback_outlined, size: 20),
            label: Text(
              SignupL10n.t('sos_import', widget.language),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Divider row
        Center(
          child: Text(
            SignupL10n.t('sos_or_manual', widget.language),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Their full name field
        _InputLabel(label: SignupL10n.t('sos_their_name', widget.language)),
        const SizedBox(height: 6),
        _SosTextField(
          controller: _nameController,
          onChanged: widget.onNameChanged,
          icon: Icons.person_outline,
          keyboardType: TextInputType.name,
        ),

        const SizedBox(height: 14),

        // Their phone number field — digits only, max 11 characters
        _InputLabel(label: SignupL10n.t('sos_their_phone', widget.language)),
        const SizedBox(height: 6),
        _SosTextField(
          controller: _phoneController,
          onChanged: widget.onPhoneChanged,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          isPhone: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,       // no letters or symbols
            LengthLimitingTextInputFormatter(11),         // max 11 digits
          ],
        ),

        const SizedBox(height: 14),

        // Relationship field
        _InputLabel(label: SignupL10n.t('sos_relationship', widget.language)),
        const SizedBox(height: 6),
        _SosTextField(
          controller: _relController,
          onChanged: widget.onRelationshipChanged,
          icon: Icons.favorite_border,
          keyboardType: TextInputType.text,
        ),

        const SizedBox(height: 36),

        // Finish Setup button
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: AppColors.primaryButtonText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              try {
                widget.onFinish();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Something went wrong. Please try again.'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              }
            },
            child: Text(
              SignupL10n.t('sos_finish', widget.language),
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

/// All-caps label above each input field
class _InputLabel extends StatelessWidget {
  final String label;
  const _InputLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Pill-shaped filled text field with prefix icon and mic button
class _SosTextField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final TextInputType keyboardType;
  final bool isPhone;
  final List<TextInputFormatter>? inputFormatters;

  const _SosTextField({
    required this.controller,
    required this.onChanged,
    required this.icon,
    required this.keyboardType,
    this.isPhone = false,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.primaryText),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.lightBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColors.unselectedBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColors.primaryButton, width: 1.5),
        ),
      ),
    );
  }
}
