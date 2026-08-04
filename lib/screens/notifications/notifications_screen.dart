import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../widgets/screen_tutorial_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationService _service = NotificationService();
  late final AnimationController _fadeCtrl;
  NotificationType? _activeFilter; // null = show all

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _service.addListener(_rebuild);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'notifications',
        titleKey: 'tutorial_notifications_title',
        descriptionKey: 'tutorial_notifications_desc',
        mascotAsset: 'assets/Mascots/05 Welcome.gif',
      );
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_rebuild);
    _fadeCtrl.dispose();
    super.dispose();
  }

  List<AppNotification> get _filtered {
    final all = _service.notifications;
    if (_activeFilter == null) return all;
    return all.where((n) => n.type == _activeFilter).toList();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Color _typeColor(NotificationType t) =>
      Color(AppNotification.typeConfig(t)['color'] as int);

  IconData _typeIcon(NotificationType t) {
    switch (t) {
      case NotificationType.obstacle:
        return Icons.warning;
      case NotificationType.buddyFollowUp:
        return Icons.person;
      case NotificationType.battery:
        return Icons.battery_std;
      case NotificationType.connection:
        return Icons.wifi;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.navigation:
        return Icons.navigation;
      case NotificationType.system:
        return Icons.info;
    }
  }

  String _typeLabel(NotificationType t) =>
      AppNotification.typeConfig(t)['label'] as String;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notifications = _filtered;
    final unread = _service.unreadCount;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(unread),
            _buildFilterChips(),
            Expanded(
              child: notifications.isEmpty
                  ? _buildEmptyState()
                  : _buildList(notifications),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(int unread) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + Clear All row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back pill
              GestureDetector(
                onTap: () {
                  SoundService.playClick();
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left, color: AppColors.primaryText, size: 22),
                      const SizedBox(width: 2),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Clear All button
              if (_service.notifications.isNotEmpty)
                GestureDetector(
                  onTap: _confirmClearAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      'Clear All',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Notifications',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryText,
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryButton,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unread new',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryButtonText,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Mark all read
          if (unread > 0)
            GestureDetector(
              onTap: () => _service.markAllRead(),
              child: Text(
                'Mark all as read',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Filter Chips ─────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    final filters = [null, ...NotificationType.values];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final filter = filters[i];
          final isActive = _activeFilter == filter;
          final label = filter == null ? 'All' : _typeLabel(filter);
          final color = filter == null ? AppColors.primaryButton : _typeColor(filter);

          return GestureDetector(
            onTap: () => setState(() => _activeFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? color : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? color : AppColors.cardBorder.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                    : [],
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.primaryButtonText : AppColors.primaryText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Notification List ────────────────────────────────────────────────────

  Widget _buildList(List<AppNotification> notifications) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: notifications.length,
      itemBuilder: (context, i) {
        final n = notifications[i];
        return _buildCard(n);
      },
    );
  }

  Widget _buildCard(AppNotification n) {
    final color = _typeColor(n.type);
    final icon = _typeIcon(n.type);

    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => _service.dismiss(n.id),
      child: GestureDetector(
        onTap: () {
          if (!n.isRead) _service.markAsRead(n.id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: n.isRead ? AppColors.lightBackground : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: n.isRead ? AppColors.cardBorder.withValues(alpha: 0.3) : color.withValues(alpha: 0.35),
              width: n.isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: GoogleFonts.inter(
                              fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _typeLabel(n.type),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(n.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF002663).withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: Color(0xFF002663),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _activeFilter == null ? 'No notifications yet' : 'No ${_typeLabel(_activeFilter!)} notifications',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF002663),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Obstacle alerts, Buddy check-ins, and\nsafety warnings will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Clear All Confirm ────────────────────────────────────────────────────

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear all notifications?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          'This will permanently delete all notifications.',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear All',
              style: GoogleFonts.inter(
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) _service.clearAll();
  }
}
