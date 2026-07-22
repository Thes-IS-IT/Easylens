import 'package:flutter/material.dart';

enum HazardSeverity {
  critical, // Knife, Fire, Weapon, Vehicle Traffic
  caution,  // Animal, Stairs, Overhead, Crowd, non-life-threatening obstacle
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

  /// Critical danger keywords (Knife, Fire, Weapon, Vehicle)
  static final Set<String> _criticalKnifeKeywords = {
    'knife', 'blade', 'dagger', 'scissors', 'cutter', 'machete', 'sword', 'razor', 'scalpel', 'cleaver'
  };

  static final Set<String> _criticalFireKeywords = {
    'fire', 'flame', 'smoke', 'lighter', 'torch', 'burning', 'explosion', 'fire hazard'
  };

  static final Set<String> _criticalWeaponKeywords = {
    'gun', 'weapon', 'pistol', 'rifle', 'shotgun', 'handgun', 'firearm', 'bomb'
  };

  static final Set<String> _criticalVehicleKeywords = {
    'car', 'truck', 'bus', 'motorcycle', 'bicycle', 'scooter', 'train', 'vehicle', 'van'
  };

  /// Non-critical caution keywords (Animals, Stairs/Ground, Overhead, Crowds)
  static final Set<String> _animalKeywords = {
    'dog', 'cat', 'animal', 'pet', 'horse', 'cow', 'sheep', 'goat', 'pig',
    'bear', 'snake', 'bird', 'duck', 'chicken', 'rabbit', 'deer', 'squirrel'
  };

  static final Set<String> _stairsGroundKeywords = {
    'stairs', 'staircase', 'step', 'steps', 'hole', 'manhole', 'pit', 'puddle',
    'wet floor', 'slippery', 'cone', 'construction cone', 'trench', 'uneven ground'
  };

  static final Set<String> _overheadKeywords = {
    'branch', 'tree branch', 'low wire', 'wire', 'signboard', 'awning', 'hanging bar'
  };

  static final Set<String> _crowdKeywords = {
    'crowd', 'group of people', 'pedestrian blocking', 'people'
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

    // Check Vehicle
    for (final kw in _criticalVehicleKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.critical;
    }

    // Check Animal (Caution)
    for (final kw in _animalKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.caution;
    }

    // Check Stairs / Ground (Caution)
    for (final kw in _stairsGroundKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.caution;
    }

    // Check Overhead (Caution)
    for (final kw in _overheadKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.caution;
    }

    // Check Crowd (Caution)
    for (final kw in _crowdKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.caution;
    }

    return HazardSeverity.safe;
  }

  /// Returns full hazard information object for a given label
  DangerHazardInfo getHazardInfo(String label) {
    final cleanLabel = label.toLowerCase().trim();
    final severity = evaluateLabel(cleanLabel);
    final capitalized = label.isNotEmpty ? label[0].toUpperCase() + label.substring(1) : label;

    // 1. Vehicle check (Critical)
    for (final kw in _criticalVehicleKeywords) {
      if (cleanLabel.contains(kw)) {
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.critical,
          icon: Icons.directions_car_rounded,
          title: 'CRITICAL TRAFFIC DANGER ALERT',
          messageEn: "CRITICAL WARNING! Approaching vehicle ($capitalized) detected on your walking path! Stay on the sidewalk!",
          messageTl: "KRITIKAL NA BABALA! May mabilis na sasakyan ($capitalized) sa iyong daanan! Manatili sa bangketa!",
        );
      }
    }

    // 2. Knife check (Critical)
    for (final kw in _criticalKnifeKeywords) {
      if (cleanLabel.contains(kw)) {
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

    // 3. Fire check (Critical)
    for (final kw in _criticalFireKeywords) {
      if (cleanLabel.contains(kw)) {
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

    // 4. Weapon check (Critical)
    for (final kw in _criticalWeaponKeywords) {
      if (cleanLabel.contains(kw)) {
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

    // 5. Animal check (Caution)
    for (final kw in _animalKeywords) {
      if (cleanLabel.contains(kw)) {
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

    // 6. Stairs / Ground check (Caution)
    for (final kw in _stairsGroundKeywords) {
      if (cleanLabel.contains(kw)) {
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.caution,
          icon: Icons.stairs_rounded,
          title: 'GROUND & ELEVATION CAUTION',
          messageEn: "CAUTION: Elevation hazard ($capitalized) detected on your path. Watch your step!",
          messageTl: "MAG-INGAT: May hagdan o hukay ($capitalized) sa iyong hahakbangan!",
        );
      }
    }

    // 7. Overhead check (Caution)
    for (final kw in _overheadKeywords) {
      if (cleanLabel.contains(kw)) {
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.caution,
          icon: Icons.park_rounded,
          title: 'OVERHEAD OBSTACLE CAUTION',
          messageEn: "CAUTION: Low-hanging obstacle ($capitalized) ahead at head height!",
          messageTl: "MAG-INGAT: May nakalawit na sanga o karatula ($capitalized) sa antas ng iyong ulo!",
        );
      }
    }

    // 8. Crowd check (Caution)
    for (final kw in _crowdKeywords) {
      if (cleanLabel.contains(kw)) {
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.caution,
          icon: Icons.groups_rounded,
          title: 'DENSE CROWD CAUTION',
          messageEn: "CAUTION: Dense crowd ahead. Proceed with care.",
          messageTl: "MAG-INGAT: Maraming tao sa iyong harapan. Maglakad nang may pag-iingat.",
        );
      }
    }

    // Default fallback
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
