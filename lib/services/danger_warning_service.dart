import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

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

  /// Triggers maximum physical hardware vibration on Android & iOS devices
  Future<void> triggerStrongHazardVibration({bool isCritical = true}) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        if (isCritical) {
          final hasCustom = await Vibration.hasCustomVibrationsSupport();
          if (hasCustom == true) {
            Vibration.vibrate(
              pattern: [0, 500, 150, 500, 150, 800],
              intensities: [0, 255, 0, 255, 0, 255],
            );
          } else {
            Vibration.vibrate(pattern: [0, 500, 150, 500, 150, 800]);
          }
        } else {
          Vibration.vibrate(duration: 400);
        }
        return;
      }
    } catch (_) {}

    HapticFeedback.vibrate();
    HapticFeedback.heavyImpact();
    for (int i = 1; i <= 4; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        HapticFeedback.vibrate();
        HapticFeedback.heavyImpact();
      });
    }
  }

  /// Critical danger keywords (Knife, Fire, Weapon, Vehicle, Electrical)
  static final Set<String> _criticalKnifeKeywords = {
    'knife', 'blade', 'dagger', 'scissors', 'cutter', 'machete', 'sword', 'razor', 'scalpel', 'cleaver'
  };

  static final Set<String> _criticalFireKeywords = {
    'fire', 'flame', 'smoke', 'lighter', 'torch', 'burning', 'explosion', 'fire hazard',
    'stove', 'grill', 'oven', 'steam', 'boiler', 'burner'
  };

  static final Set<String> _criticalWeaponKeywords = {
    'gun', 'weapon', 'pistol', 'rifle', 'shotgun', 'handgun', 'firearm', 'bomb'
  };

  static final Set<String> _criticalVehicleKeywords = {
    'car', 'truck', 'bus', 'motorcycle', 'bicycle', 'scooter', 'train', 'vehicle', 'van',
    'jeepney', 'tricycle', 'e-bike', 'trolley', 'stroller', 'forklift', 'golf cart', 'heavy machinery'
  };

  static final Set<String> _criticalElectricalKeywords = {
    'wire', 'cable', 'voltage', 'live wire', 'power line', 'exposed wire', 'generator'
  };

  /// Non-critical caution keywords (Animals, Stairs/Ground, Overhead, Crowds, Indoor, Outdoor, Terrain)
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

  static final Set<String> _indoorObstacleKeywords = {
    'chair', 'table', 'desk', 'sofa', 'couch', 'bed', 'cabinet', 'shelf', 'bookcase',
    'box', 'crate', 'backpack', 'bag', 'luggage', 'bin', 'trashcan', 'pot', 'plant', 'stand', 'doorway'
  };

  static final Set<String> _outdoorObstacleKeywords = {
    'pole', 'lamppost', 'signpost', 'hydrant', 'fire hydrant', 'trash bin', 'bollard',
    'bench', 'barricade', 'construction barrier', 'scaffolding', 'gate', 'guardrail', 'fence'
  };

  static final Set<String> _elevationTerrainKeywords = {
    'curb', 'ramp', 'slope', 'drain', 'sewer', 'ditch', 'gutter', 'pavement crack', 'gravel', 'mud'
  };

  static final Set<String> _elevatorKeywords = {
    'elevator', 'lift', 'escalator'
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

    // Check Electrical (Critical)
    for (final kw in _criticalElectricalKeywords) {
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

    // Check Indoor Obstacle (Caution)
    for (final kw in _indoorObstacleKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.caution;
    }

    // Check Outdoor Obstacle (Caution)
    for (final kw in _outdoorObstacleKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.caution;
    }

    // Check Elevation / Terrain (Caution)
    for (final kw in _elevationTerrainKeywords) {
      if (cleanLabel.contains(kw)) return HazardSeverity.caution;
    }

    // Check Elevator (Caution)
    for (final kw in _elevatorKeywords) {
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
          messageEn: "CRITICAL DANGER! Approaching vehicle ($capitalized) detected on your walking path! STOP AND AVOID THIS AREA IMMEDIATELY!",
          messageTl: "KRITIKAL NA PANGANIB! May mabilis na sasakyan ($capitalized) sa iyong daanan! HUMINTO AT UMIWAS AGAD!",
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
          messageEn: "CRITICAL DANGER! Sharp object ($capitalized) detected ahead! STOP AND AVOID THIS AREA IMMEDIATELY!",
          messageTl: "KRITIKAL NA PANGANIB! May matalas na bagay ($capitalized) sa iyong daanan! HUMINTO AT UMIWAS AGAD!",
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
          messageEn: "CRITICAL DANGER! Fire hazard detected ahead! STOP AND AVOID THIS AREA IMMEDIATELY!",
          messageTl: "KRITIKAL NA PANGANIB! May apoy o usok sa iyong daanan! HUMINTO AT UMIWAS AGAD!",
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
          messageEn: "CRITICAL DANGER! Weapon hazard detected ahead! STOP AND AVOID THIS AREA IMMEDIATELY!",
          messageTl: "KRITIKAL NA PANGANIB! May peligrosong armas sa iyong daanan! HUMINTO AT UMIWAS AGAD!",
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

    // 9. Electrical check (Critical)
    for (final kw in _criticalElectricalKeywords) {
      if (cleanLabel.contains(kw)) {
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.critical,
          icon: Icons.electric_bolt_rounded,
          title: 'CRITICAL ELECTRICAL HAZARD',
          messageEn: "CRITICAL DANGER! Live wire or electrical hazard ($capitalized) detected ahead! STOP AND AVOID THIS AREA IMMEDIATELY!",
          messageTl: "KRITIKAL NA PANGANIB! May nakalawit na linya ng kuryente o exposed wire ($capitalized) sa harap! HUMINTO AT UMIWAS AGAD!",
        );
      }
    }

    // 10. Indoor Obstacle check (Caution)
    for (final kw in _indoorObstacleKeywords) {
      if (cleanLabel.contains(kw)) {
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.caution,
          icon: Icons.chair_rounded,
          title: 'INDOOR OBSTACLE CAUTION',
          messageEn: "Caution: Indoor obstacle ($capitalized) detected on your path. Proceed slowly.",
          messageTl: "Mag-ingat: May kasangkapan o harang ($capitalized) sa iyong dinadaanan.",
        );
      }
    }

    // 11. Outdoor Obstacle check (Caution)
    for (final kw in _outdoorObstacleKeywords) {
      if (cleanLabel.contains(kw)) {
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.caution,
          icon: Icons.door_sliding_rounded,
          title: 'STREET FIXTURE CAUTION',
          messageEn: "Caution: Street obstacle ($capitalized) detected ahead. Step aside to avoid it.",
          messageTl: "Mag-ingat: May poste o harang sa daan ($capitalized) sa iyong harapan.",
        );
      }
    }

    // 12. Elevation / Terrain check (Caution)
    for (final kw in _elevationTerrainKeywords) {
      if (cleanLabel.contains(kw)) {
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.caution,
          icon: Icons.terrain_rounded,
          title: 'TERRAIN ELEVATION CAUTION',
          messageEn: "Caution: Elevation change ($capitalized) detected on your path. Watch your footing.",
          messageTl: "Mag-ingat: May bangketa, dalisdis, o kanal ($capitalized) sa iyong hahakbangan.",
        );
      }
    }

    // 13. Elevator check (Caution)
    for (final kw in _elevatorKeywords) {
      if (cleanLabel.contains(kw)) {
        return DangerHazardInfo(
          label: capitalized,
          severity: HazardSeverity.caution,
          icon: Icons.elevator_rounded,
          title: 'ELEVATOR APPROACHING',
          messageEn: "Caution: Approaching elevator door ahead. Locate the call buttons and wait for it to open before stepping inside.",
          messageTl: "Mag-ingat: May elevator o hagdanang de-motor sa iyong tapat. Hintayin itong bumukas bago pumasok.",
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
