// lib/models/app_notification.dart
// Dynamic, persistent notification model for EasyLens

enum NotificationType {
  obstacle,    // Obstacle/proximity alert
  buddyFollowUp, // Buddy AI check-in
  battery,     // Battery low
  connection,  // Glasses disconnect
  warning,     // Image-labeler detected hazard
  system,      // General system
  navigation,  // Navigation event
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
      );

  // Returns the icon and color info for each notification type
  static Map<String, dynamic> typeConfig(NotificationType type) {
    switch (type) {
      case NotificationType.obstacle:
        return {
          'icon': 0xe8b2, // Icons.warning_rounded
          'color': 0xFFF97316, // orange
          'label': 'Obstacle Alert',
        };
      case NotificationType.buddyFollowUp:
        return {
          'icon': 0xe7fd, // Icons.psychology_rounded
          'color': 0xFF6366F1, // indigo
          'label': 'Buddy Follow-up',
        };
      case NotificationType.battery:
        return {
          'icon': 0xe19c, // Icons.battery_alert_rounded
          'color': 0xFFEF4444, // red
          'label': 'Battery Alert',
        };
      case NotificationType.connection:
        return {
          'icon': 0xe1ba, // Icons.bluetooth_disabled_rounded
          'color': 0xFF64748B, // slate
          'label': 'Connection Alert',
        };
      case NotificationType.warning:
        return {
          'icon': 0xe8b2, // Icons.warning_rounded
          'color': 0xFFDC2626, // deep red
          'label': 'Safety Warning',
        };
      case NotificationType.navigation:
        return {
          'icon': 0xe569, // Icons.navigation_rounded
          'color': 0xFF10B981, // emerald
          'label': 'Navigation',
        };
      case NotificationType.system:
        return {
          'icon': 0xe88f, // Icons.notifications_rounded
          'color': 0xFF002663, // brand blue
          'label': 'System',
        };
    }
  }
}
