import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';

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

  IconData _typeIcon(NotificationType t) =>
      IconData(AppNotification.typeConfig(t)['icon'] as int,
          fontFamily: 'MaterialIcons');

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
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chevron_left, color: Color(0xFF002663), size: 22),
                      const SizedBox(width: 2),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF002663),
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
                  color: const Color(0xFF002663),
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF002663),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unread new',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
          final color = filter == null ? const Color(0xFF002663) : _typeColor(filter);

          return GestureDetector(
            onTap: () => setState(() => _activeFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? color : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? color : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
                    : [],
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFF64748B),
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
            color: n.isRead ? Colors.white : color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: n.isRead ? const Color(0xFFE2E8F0) : color.withOpacity(0.25),
              width: n.isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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
                  color: color.withOpacity(0.12),
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
                              color: const Color(0xFF0F172A),
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
                        color: const Color(0xFF64748B),
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
