import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/face_registration_service.dart';
import '../../constants/colors.dart';
import '../dashboard/components/custom_navbar.dart';
import '../dashboard/components/buddy_assistant_sheet.dart';
import 'face_registration_screen.dart';
import '../../utils/app_route.dart';

class RegisteredFacesScreen extends StatefulWidget {
  const RegisteredFacesScreen({super.key});

  @override
  State<RegisteredFacesScreen> createState() => _RegisteredFacesScreenState();
}

class _RegisteredFacesScreenState extends State<RegisteredFacesScreen> {
  List<FaceProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await FaceRegistrationService().getAllProfiles();
    if (!mounted) return;
    setState(() {
      _profiles = profiles.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _deleteProfile(FaceProfile p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove "${p.name}"?',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This face profile will be permanently deleted.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FaceRegistrationService().deleteProfile(p.id);
      await _load();
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Registered Faces',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        actions: [
          if (_profiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1B4B),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: Text('Clear All?',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    content: Text(
                      'All registered face profiles will be deleted.',
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: Text('Cancel',
                            style: GoogleFonts.inter(
                                color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        child: Text('Clear All',
                            style: GoogleFonts.inter(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FaceRegistrationService().clearAll();
                  await _load();
                }
              },
            ),
        ],
      ),
      bottomNavigationBar: CustomNavbar(
        currentIndex: 0,
        onTap: (index) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        onEasyLensTap: () {
          BuddyAssistantSheet.show(
            context,
            onNavigate: (screenKey) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Count pill
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.3)),
              ),
              child: Text(
                "${_profiles.length} face${_profiles.length != 1 ? 's' : ''} registered",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ),

            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF7C3AED)))
                  : _profiles.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _profiles.length,
                          itemBuilder: (_, i) =>
                              _buildProfileCard(_profiles[i]),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            AppRoute.to(const FaceRegistrationScreen()),
          );
          await _load();
        },
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: Text('Add Face',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.face_retouching_off_rounded,
            size: 72,
            color: AppColors.textMuted.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No faces registered yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add Face" below to register someone.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(FaceProfile p) {
    final hasImage =
        p.imageLocalPath != null && File(p.imageLocalPath!).existsSync();

    return Dismissible(
      key: Key(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
      ),
      confirmDismiss: (_) async {
        await _deleteProfile(p);
        return false; // We reload manually
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.unselectedBorder),
        ),
        child: Row(
          children: [
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: hasImage
                  ? Image.file(
                      File(p.imageLocalPath!),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          p.name.isNotEmpty
                              ? p.name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            // Name + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 11, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 4),
                      Text(
                        'Registered ${_formatDate(p.registeredAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Delete icon
            IconButton(
              onPressed: () => _deleteProfile(p),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.textMuted.withOpacity(0.7),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
