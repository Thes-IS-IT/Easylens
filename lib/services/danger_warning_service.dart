import 'package:flutter/material.dart';

enum HazardSeverity {
  critical, // Knife, Fire, Weapon, etc.
  caution,  // Animal, non-life-threatening obstacle
  safe,
}

class DangerHazardInfo {
  final String label;
  final HazardSeverity severity;
  final IconData icon;
  final String title;
  final String messageEn;
  final String messageTl;

  DangerHazardInfo({
    required this.label,
    required this.severity,
    required this.icon,
    required this.title,
    required this.messageEn,
    required this.messageTl,
  });
}

class DangerWarningService {
  static final DangerWarningService _instance = DangerWarningService._internal();
  factory DangerWarningService() => _instance;
  DangerWarningService._internal();

  /// Critical danger keywords (Knife, Fire, Weapon)
  static final Set<String> _criticalKnifeKeywords = {
    'knife', 'blade', 'dagger', 'scissors', 'cutter', 'machete', 'sword', 'razor', 'scalpel', 'cleaver'
  };

  static final Set<String> _criticalFireKeywords = {
    'fire', 'flame', 'smoke', 'lighter', 'torch', 'burning', 'explosion', 'fire hazard'
  };

  static final Set<String> _criticalWeaponKeywords = {
    'gun', 'weapon', 'pistol', 'rifle', 'shotgun', 'handgun', 'firearm', 'bomb'
  };

  /// Non-critical caution keywords (Animals)
  static final Set<String> _animalKeywords = {
    'dog', 'cat', 'animal', 'pet', 'horse', 'cow', 'sheep', 'goat', 'pig',
    'bear', 'snake', 'bird', 'duck', 'chicken', 'rabbit', 'deer', 'squirrel'
  };

  /// Evaluates an object label string and returns its hazard severity level
  HazardSeverity evaluateLabel(String label) {
    final cleanLabel = label.toLowerCase().trim();
    
    // Check Knife
    for (final kw in _criticalKnifeKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.critical;
    }
    
    // Check Fire
    for (final kw in _criticalFireKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.critical;
    }

    // Check Weapon
    for (final kw in _criticalWeaponKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.critical;
    }

    // Check Animal (Caution)
    for (final kw in _animalKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.caution;
    }

    return HazardSeverity.safe;
  }

  /// Returns full hazard information object for a given label
  DangerHazardInfo getHazardInfo(String label) {
    final cleanLabel = label.toLowerCase().trim();
    final severity = evaluateLabel(cleanLabel);

    // Animal check
    for (final kw in _animalKeywords) {
      if (cleanLabel.contains(kw)) {
        final capitalized = label.isNotEmpty ? label[0].toUpperCase() + label.substring(1) : label;
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.caution,
          icon: Icons.pets_rounded,
          title: 'ANIMAL CAUTION',
          messageEn: "Be careful, there's an animal ($capitalized) on your way!",
          messageTl: "Mag-ingat, may hayop ($capitalized) sa iyong daanan!",
        );
      }
    }

    // Knife check
    for (final kw in _criticalKnifeKeywords) {
      if (cleanLabel.contains(kw)) {
        final capitalized = label.isNotEmpty ? label[0].toUpperCase() + label.substring(1) : label;
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.critical,
          icon: Icons.warning_amber_rounded,
          title: 'CRITICAL SHARP OBJECT ALERT',
          messageEn: "CRITICAL WARNING! Dangerous sharp object ($capitalized) detected ahead! Stop immediately!",
          messageTl: "KRITIKAL NA BABALA! May matalas na bagay ($capitalized) sa iyong daanan! Huminto agad!",
        );
      }
    }

    // Fire check
    for (final kw in _criticalFireKeywords) {
      if (cleanLabel.contains(kw)) {
        final capitalized = label.isNotEmpty ? label[0].toUpperCase() + label.substring(1) : label;
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.critical,
          icon: Icons.local_fire_department_rounded,
          title: 'CRITICAL FIRE HAZARD ALERT',
          messageEn: "CRITICAL WARNING! Fire hazard detected ahead! Exercise extreme caution and stay back!",
          messageTl: "KRITIKAL NA BABALA! May apoy o usok sa iyong daanan! Mag-ingat nang husto at lumayo!",
        );
      }
    }

    // Weapon check
    for (final kw in _criticalWeaponKeywords) {
      if (cleanLabel.contains(kw)) {
        final capitalized = label.isNotEmpty ? label[0].toUpperCase() + label.substring(1) : label;
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.critical,
          icon: Icons.gavel_rounded,
          title: 'CRITICAL WEAPON DANGER ALERT',
          messageEn: "CRITICAL WARNING! Weapon hazard detected ahead! Stop and seek assistance immediately!",
          messageTl: "KRITIKAL NA BABALA! May peligrosong armas sa iyong daanan! Huminto at humingi agad ng tulong!",
        );
      }
    }

    // Default Critical if specified explicitly
    final capitalized = label.isNotEmpty ? label[0].toUpperCase() + label.substring(1) : label;
    return DangerHazardInfo(
      label: capitalized,
      severity: severity == HazardSeverity.safe ? HazardSeverity.caution : severity,
      icon: severity == HazardSeverity.critical ? Icons.report_problem_rounded : Icons.info_rounded,
      title: severity == HazardSeverity.critical ? 'CRITICAL DANGER ALERT' : 'HAZARD CAUTION',
      messageEn: severity == HazardSeverity.critical
          ? "CRITICAL WARNING! Dangerous hazard ($capitalized) detected ahead!"
          : "Caution: $capitalized detected ahead on your path.",
      messageTl: severity == HazardSeverity.critical
          ? "KRITIKAL NA BABALA! May peligrosong bagay ($capitalized) sa iyong daanan!"
          : "Mag-ingat: May $capitalized sa iyong daanan.",
    );
  }
}
