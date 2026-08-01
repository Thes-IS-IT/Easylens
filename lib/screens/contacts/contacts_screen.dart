import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/emergency_contact_service.dart';
import '../../services/firebase_service.dart';
import '../../services/sms_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../../widgets/screen_tutorial_card.dart';

class Contact {
  String name;
  String phone;
  String relationship;
  bool isActive;

  Contact({
    required this.name,
    required this.phone,
    required this.relationship,
    this.isActive = true,
  });
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    EmergencyContactService().addListener(_onContactsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'contacts',
        titleKey: 'tutorial_contacts_title',
        descriptionKey: 'tutorial_contacts_desc',
        mascotAsset: 'assets/Mascots/05 Welcome.gif',
      );
    });
  }

  @override
  void dispose() {
    EmergencyContactService().removeListener(_onContactsChanged);
    super.dispose();
  }

  void _onContactsChanged() {
    _loadContacts();
  }

  String _sanitizePhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    }
    return digits.length > 11 ? digits.substring(0, 11) : digits;
  }

  Future<void> _importContactFromPhone() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_contacts.length >= 3) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Maximum limit of 3 emergency contacts reached. Please delete an existing contact first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      try {
        await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
      } catch (_) {}

      final picked = await fc.FlutterContacts.native.showPicker();
      if (picked != null) {
        fc.Contact? fullContact;
        final contactId = picked.id;
        if (contactId != null && contactId.isNotEmpty) {
          try {
            fullContact = await fc.FlutterContacts.get(
              contactId,
              properties: {fc.ContactProperty.phone, fc.ContactProperty.name},
            );
          } catch (_) {}
        }
        fullContact ??= picked;

        final displayName = fullContact.displayName ?? '';
        final firstName = fullContact.name?.first ?? '';
        final lastName = fullContact.name?.last ?? '';
        final name = displayName.isNotEmpty
            ? displayName
            : ('$firstName $lastName').trim();

        String rawPhone = '';
        if (fullContact.phones.isNotEmpty) {
          final numStr = fullContact.phones.firstWhere(
            (p) => p.number.trim().isNotEmpty,
            orElse: () => fullContact!.phones.first,
          ).number;
          rawPhone = numStr;
        }

        if (rawPhone.isEmpty && name.isNotEmpty) {
          try {
            final allContacts = await fc.FlutterContacts.getAll(
              properties: {fc.ContactProperty.phone, fc.ContactProperty.name},
            );
            for (final c in allContacts) {
              if ((c.displayName ?? '').toLowerCase() == name.toLowerCase() && c.phones.isNotEmpty) {
                rawPhone = c.phones.first.number;
                break;
              }
            }
          } catch (_) {}
        }

        final normPhone = EmergencyContactService.normalizePhoneNumber(rawPhone);

        if (normPhone.isEmpty || !EmergencyContactService.isValidPHPhoneNumber(normPhone)) {
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Selected contact does not have a valid 11-digit Philippine mobile number.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final newShared = SharedEmergencyContact(
          name: name.isNotEmpty ? name : 'Imported Contact',
          phone: normPhone,
          relationship: 'Friend',
          isActive: true,
        );

        final saved = await EmergencyContactService().saveContact(newShared);
        if (!saved) {
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Maximum limit of 3 emergency contacts reached.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final user = FirebaseService().currentUser;
        if (user != null) {
          try {
            await FirebaseService().syncContactToCloud(user.uid, newShared.toJson());
          } catch (_) {}
        }

        await _loadContacts();

        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Imported contact: $name ($normPhone)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Import contact error: $e');
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not access phone contacts. Please check permissions in Settings.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadContacts() async {
    final list = await EmergencyContactService().getContacts();
    if (mounted) {
      setState(() {
        _contacts.clear();
        _contacts.addAll(list.map((c) => Contact(
              name: c.name,
              phone: c.phone,
              relationship: c.relationship,
              isActive: c.isActive,
            )));
      });
    }
  }

  Future<void> _deleteContact(int index) async {
    if (index >= 0 && index < _contacts.length) {
      final phone = _contacts[index].phone;
      await EmergencyContactService().deleteContact(phone);
      await _loadContacts();
    }
  }

  void _showAddContactModal() {
    if (_contacts.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum limit of 3 emergency contacts reached. Please delete an existing contact first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

    String? nameError;
    String? phoneError;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.2), // Dim barrier overlay
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curveAnim = CurvedAnimation(parent: anim1, curve: Curves.easeOutQuad);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curveAnim),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Blurred background filter S01
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 36.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Form Header block
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF002663),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person_add_alt_1,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add Contact',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    'Emergency contact details',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Full Name input
                          Text(
                            'FULL NAME',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              hintText: 'Enter name',
                              errorText: nameError,
                              prefixIcon: const Icon(Icons.person_outline),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onChanged: (_) {
                              if (nameError != null) {
                                setModalState(() => nameError = null);
                              }
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Phone Number input
                          Text(
                            'PHONE NUMBER',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'Enter number (e.g. 09171234567)',
                              errorText: phoneError,
                              prefixIcon: const Icon(Icons.phone_outlined),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onChanged: (_) {
                              if (phoneError != null) {
                                setModalState(() => phoneError = null);
                              }
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Relationship input
                          Text(
                            'RELATIONSHIP (E.G. FAMILY)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: relationshipController,
                            decoration: InputDecoration(
                              hintText: 'Enter relationship',
                              prefixIcon: const Icon(Icons.favorite_border),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryButton,
                                      foregroundColor: AppColors.primaryButtonText,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    onPressed: () async {
                                      final rawName = nameController.text.trim();
                                      final rawPhone = phoneController.text.trim();

                                      String? nErr;
                                      String? pErr;

                                      if (rawName.isEmpty) {
                                        nErr = 'Please enter full name';
                                      }
                                      if (rawPhone.isEmpty) {
                                        pErr = 'Please enter phone number';
                                      } else if (!EmergencyContactService.isValidPHPhoneNumber(rawPhone)) {
                                        pErr = 'Please enter a valid 11-digit Philippine number (e.g. 09171234567)';
                                      }

                                      if (nErr != null || pErr != null) {
                                        setModalState(() {
                                          nameError = nErr;
                                          phoneError = pErr;
                                        });
                                        return;
                                      }

                                      final phone = EmergencyContactService.normalizePhoneNumber(rawPhone);
                                      final rel = relationshipController.text.trim().isNotEmpty
                                          ? relationshipController.text.trim()
                                          : 'Family';

                                      final contact = SharedEmergencyContact(
                                        name: rawName,
                                        phone: phone,
                                        relationship: rel,
                                        isActive: true,
                                      );

                                      final saved = await EmergencyContactService().saveContact(contact);

                                      if (!saved) {
                                        setModalState(() {
                                          phoneError = 'Maximum limit of 3 emergency contacts reached.';
                                        });
                                        return;
                                      }

                                      final user = FirebaseService().currentUser;
                                      if (user != null) {
                                        try {
                                          await FirebaseService().syncContactToCloud(user.uid, contact.toJson());
                                        } catch (_) {}
                                      }

                                      await _loadContacts();
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    child: Text(
                                      'Add Contact',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditContactModal(Contact c) {
    final nameController = TextEditingController(text: c.name);
    final phoneController = TextEditingController(text: c.phone);
    final relationshipController = TextEditingController(text: c.relationship);
    final originalPhone = c.phone;

    String? nameError;
    String? phoneError;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.2),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curveAnim = CurvedAnimation(parent: anim1, curve: Curves.easeOutQuad);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curveAnim),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 36.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF002663),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit Contact',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    'Update emergency contact details',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          Text(
                            'FULL NAME',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              hintText: 'Enter name',
                              errorText: nameError,
                              prefixIcon: const Icon(Icons.person_outline),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onChanged: (_) {
                              if (nameError != null) {
                                setModalState(() => nameError = null);
                              }
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            'PHONE NUMBER',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'Enter number (e.g. 09171234567)',
                              errorText: phoneError,
                              prefixIcon: const Icon(Icons.phone_outlined),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onChanged: (_) {
                              if (phoneError != null) {
                                setModalState(() => phoneError = null);
                              }
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            'RELATIONSHIP (E.G. FAMILY)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: relationshipController,
                            decoration: InputDecoration(
                              hintText: 'Enter relationship',
                              prefixIcon: const Icon(Icons.favorite_border),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryButton,
                                      foregroundColor: AppColors.primaryButtonText,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    onPressed: () async {
                                      final rawName = nameController.text.trim();
                                      final rawPhone = phoneController.text.trim();

                                      String? nErr;
                                      String? pErr;

                                      if (rawName.isEmpty) {
                                        nErr = 'Please enter full name';
                                      }
                                      if (rawPhone.isEmpty) {
                                        pErr = 'Please enter phone number';
                                      } else if (!EmergencyContactService.isValidPHPhoneNumber(rawPhone)) {
                                        pErr = 'Please enter a valid 11-digit Philippine number (e.g. 09171234567)';
                                      }

                                      if (nErr != null || pErr != null) {
                                        setModalState(() {
                                          nameError = nErr;
                                          phoneError = pErr;
                                        });
                                        return;
                                      }

                                      final newPhone = EmergencyContactService.normalizePhoneNumber(rawPhone);
                                      final rel = relationshipController.text.trim().isNotEmpty
                                          ? relationshipController.text.trim()
                                          : 'Family';

                                      final updatedContact = SharedEmergencyContact(
                                        name: rawName,
                                        phone: newPhone,
                                        relationship: rel,
                                        isActive: c.isActive,
                                      );

                                      // If phone changed, delete old phone from cloud first
                                      final normOriginal = EmergencyContactService.normalizePhoneNumber(originalPhone);
                                      if (normOriginal != newPhone) {
                                        final user = FirebaseService().currentUser;
                                        if (user != null) {
                                          try {
                                            await FirebaseService().deleteContactFromCloud(user.uid, originalPhone);
                                          } catch (_) {}
                                        }
                                      }

                                      await EmergencyContactService().updateContact(
                                        originalPhone,
                                        updatedContact,
                                      );

                                      final user = FirebaseService().currentUser;
                                      if (user != null) {
                                        try {
                                          await FirebaseService().syncContactToCloud(user.uid, updatedContact.toJson());
                                        } catch (_) {}
                                      }

                                      await _loadContacts();
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    child: Text(
                                      'Save Changes',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Floating Pill Back Button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 95,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chevron_left, color: AppColors.primaryText, size: 24),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 2. Contacts Screen Header
              Text(
                'Contacts',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryText,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 3. Inner Container holding local profiles card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Local profiles',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Emergency Contacts (${_contacts.length}/3)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    if (_contacts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final c = _contacts[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${c.phone} • ${c.relationship}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (c.isActive)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Active',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF3B82F6),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                  onPressed: () => _showEditContactModal(c),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  onPressed: () => _deleteContact(index),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 4. Import from Contacts Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                          foregroundColor: AppColors.primaryButtonText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.0),
                    ),
                  ),
                  onPressed: _importContactFromPhone,
                  icon: const Icon(Icons.phone_outlined, size: 20),
                  label: Text(
                    'Import from Contacts',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 5. Add Person Manually Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryText,
                    backgroundColor: AppColors.lightBackground,
                    side: BorderSide(color: AppColors.cardBorder, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.0),
                    ),
                  ),
                  onPressed: _showAddContactModal,
                  icon: Icon(Icons.person_add_alt_1_outlined, size: 20, color: AppColors.primaryText),
                  label: Text(
                    'Add Person Manually',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
