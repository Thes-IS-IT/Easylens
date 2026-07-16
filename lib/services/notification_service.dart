import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationService extends ChangeNotifier {
  // --- Singleton ---
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _prefsKey = 'easylens_notifications';
  static const int _maxNotifications = 100;

  final List<AppNotification> _notifications = [];
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications..sort((a, b) => b.timestamp.compareTo(a.timestamp)));

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  // --- Initialization ---
  Future<void> initialize() async {
    await _loadFromPrefs();
    
    // Initialize native push notification settings
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(
      settings: initSettings,
    );

    // Schedule a buddy follow-up notification on first launch of the day
    _maybeSendDailyBuddyFollowUp();
  }

  // --- Core Actions ---

  /// Push a new notification from anywhere in the app
  Future<void> push({
    required NotificationType type,
    required String title,
    required String body,
  }) async {
    final n = AppNotification(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      body: body,
      timestamp: DateTime.now(),
    );
    _notifications.insert(0, n);
    // Keep only latest _maxNotifications
    if (_notifications.length > _maxNotifications) {
      _notifications.removeRange(_maxNotifications, _notifications.length);
    }
    await _saveToPrefs();
    notifyListeners();

    // Trigger Native Notification
    _triggerNativeNotification(n);
  }

  Future<void> _triggerNativeNotification(AppNotification n) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'easylens_alerts',
      'EasyLens Alerts',
      channelDescription: 'Alerts and warnings from EasyLens sensors and Buddy AI guide.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: n.id.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: platformDetails,
    );
  }

  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      await _saveToPrefs();
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> dismiss(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _saveToPrefs();
    notifyListeners();
  }

  // --- Convenience push helpers (called from hardware_screen etc.) ---

  Future<void> pushObstacleAlert(String direction, String objectLabel) async {
    // Transient obstacle alerts are spoken and drawn on the HUD.
    // They are not persisted to avoid notification spam and disk writing lag.
  }

  Future<void> pushWarning(String warningTitle, String detail) async {
    final titleUpper = warningTitle.toUpperCase();
    // Only persist critical safety hazard alerts to the notifications log
    if (titleUpper.contains('STOP') || titleUpper.contains('FIRE') || titleUpper.contains('HAZARD') || titleUpper.contains('EMERGENCY')) {
      await push(
        type: NotificationType.warning,
        title: warningTitle,
        body: detail,
      );
    }
  }

  Future<void> pushBatteryAlert(int percent) async {
    await push(
      type: NotificationType.battery,
      title: 'Low Battery',
      body: 'Smart glasses battery is at $percent%. Please charge soon.',
    );
  }

  Future<void> pushConnectionAlert(bool connected) async {
    await push(
      type: NotificationType.connection,
      title: connected ? 'Glasses Connected' : 'Glasses Disconnected',
      body: connected
          ? 'Your EasyLens smart glasses are now connected.'
          : 'Your EasyLens smart glasses lost connection. Check Bluetooth.',
    );
  }

  Future<void> pushNavigationEvent(String message) async {
    await push(
      type: NotificationType.navigation,
      title: 'Navigation Update',
      body: message,
    );
  }

  // --- Buddy daily follow-up ---
  Future<void> _maybeSendDailyBuddyFollowUp() async {
    final prefs = await SharedPreferences.getInstance();
    final lastKey = 'buddy_followup_last_date';
    final lastStr = prefs.getString(lastKey);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    if (lastStr != todayStr) {
      await prefs.setString(lastKey, todayStr);
      final hour = today.hour;
      String greeting;
      if (hour < 12) {
        greeting = "Good morning! Ready to navigate safely today? I'm here whenever you need me.";
      } else if (hour < 17) {
        greeting = "Good afternoon! How's your day going? I'm standing by to help you navigate.";
      } else {
        greeting = "Good evening! Hope today went well. I'm here if you need any help.";
      }
      await push(
        type: NotificationType.buddyFollowUp,
        title: 'Buddy Check-in',
        body: greeting,
      );
    }
  }

  // --- Persistence ---
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw);
        _notifications.clear();
        for (final item in decoded) {
          try {
            _notifications.add(AppNotification.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[NotificationService] Failed to load: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      debugPrint('[NotificationService] Failed to save: $e');
    }
  }
}
