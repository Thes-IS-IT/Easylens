class UserPreferences {
  final String language;
  final bool faceIdUnlock;
  final String appearanceTheme;
  final int accentColorIndex;
  final bool shakeToUndo;
  
  // Preferences settings
  final bool voiceFeedback;
  final bool navigationAssistant;
  final bool hapticFeedback;
  final bool buttonHaptics;
  final bool navigationHaptics;
  final double speechRate;
  final double pitch;
  final String voicePersonaId;
  
  // Units settings
  final String unitsPreference;
  
  // Notifications settings
  final bool globalNotifications;
  final bool buddyFollowUp;
  final bool obstacleAlerts;
  final bool batteryAlerts;
  final bool connectionAlerts;

  UserPreferences({
    this.language = 'English',
    this.faceIdUnlock = false,
    this.appearanceTheme = 'Black',
    this.accentColorIndex = 0,
    this.shakeToUndo = true,
    this.voiceFeedback = true,
    this.navigationAssistant = true,
    this.hapticFeedback = true,
    this.buttonHaptics = true,
    this.navigationHaptics = true,
    this.speechRate = 0.5,
    this.pitch = 0.5,
    this.voicePersonaId = 'aria',
    this.unitsPreference = 'Metric',
    this.globalNotifications = true,
    this.buddyFollowUp = true,
    this.obstacleAlerts = true,
    this.batteryAlerts = false,
    this.connectionAlerts = false,
  });

  UserPreferences copyWith({
    String? language,
    bool? faceIdUnlock,
    String? appearanceTheme,
    int? accentColorIndex,
    bool? shakeToUndo,
    bool? voiceFeedback,
    bool? navigationAssistant,
    bool? hapticFeedback,
    bool? buttonHaptics,
    bool? navigationHaptics,
    double? speechRate,
    double? pitch,
    String? voicePersonaId,
    String? unitsPreference,
    bool? globalNotifications,
    bool? buddyFollowUp,
    bool? obstacleAlerts,
    bool? batteryAlerts,
    bool? connectionAlerts,
  }) {
    return UserPreferences(
      language: language ?? this.language,
      faceIdUnlock: faceIdUnlock ?? this.faceIdUnlock,
      appearanceTheme: appearanceTheme ?? this.appearanceTheme,
      accentColorIndex: accentColorIndex ?? this.accentColorIndex,
      shakeToUndo: shakeToUndo ?? this.shakeToUndo,
      voiceFeedback: voiceFeedback ?? this.voiceFeedback,
      navigationAssistant: navigationAssistant ?? this.navigationAssistant,
      hapticFeedback: hapticFeedback ?? buttonHaptics ?? this.hapticFeedback,
      buttonHaptics: buttonHaptics ?? hapticFeedback ?? this.buttonHaptics,
      navigationHaptics: navigationHaptics ?? this.navigationHaptics,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      voicePersonaId: voicePersonaId ?? this.voicePersonaId,
      unitsPreference: unitsPreference ?? this.unitsPreference,
      globalNotifications: globalNotifications ?? this.globalNotifications,
      buddyFollowUp: buddyFollowUp ?? this.buddyFollowUp,
      obstacleAlerts: obstacleAlerts ?? this.obstacleAlerts,
      batteryAlerts: batteryAlerts ?? this.batteryAlerts,
      connectionAlerts: connectionAlerts ?? this.connectionAlerts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'faceIdUnlock': faceIdUnlock,
      'appearanceTheme': appearanceTheme,
      'accentColorIndex': accentColorIndex,
      'shakeToUndo': shakeToUndo,
      'voiceFeedback': voiceFeedback,
      'navigationAssistant': navigationAssistant,
      'hapticFeedback': hapticFeedback,
      'buttonHaptics': buttonHaptics,
      'navigationHaptics': navigationHaptics,
      'speechRate': speechRate,
      'pitch': pitch,
      'voicePersonaId': voicePersonaId,
      'unitsPreference': unitsPreference,
      'globalNotifications': globalNotifications,
      'buddyFollowUp': buddyFollowUp,
      'obstacleAlerts': obstacleAlerts,
      'batteryAlerts': batteryAlerts,
      'connectionAlerts': connectionAlerts,
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final rawButtonHaptics = json['buttonHaptics'] ?? json['hapticFeedback'] ?? true;
    final rawNavHaptics = json['navigationHaptics'] ?? true;
    return UserPreferences(
      language: json['language'] ?? 'English',
      faceIdUnlock: json['faceIdUnlock'] ?? false,
      appearanceTheme: json['appearanceTheme'] ?? 'Black',
      accentColorIndex: json['accentColorIndex'] ?? 0,
      shakeToUndo: json['shakeToUndo'] ?? true,
      voiceFeedback: json['voiceFeedback'] ?? true,
      navigationAssistant: json['navigationAssistant'] ?? true,
      hapticFeedback: rawButtonHaptics,
      buttonHaptics: rawButtonHaptics,
      navigationHaptics: rawNavHaptics,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 0.5,
      voicePersonaId: json['voicePersonaId'] ?? 'aria',
      unitsPreference: json['unitsPreference'] ?? 'Metric',
      globalNotifications: json['globalNotifications'] ?? true,
      buddyFollowUp: json['buddyFollowUp'] ?? true,
      obstacleAlerts: json['obstacleAlerts'] ?? true,
      batteryAlerts: json['batteryAlerts'] ?? false,
      connectionAlerts: json['connectionAlerts'] ?? false,
    );
  }
}
