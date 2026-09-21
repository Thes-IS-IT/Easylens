import 'package:flutter/material.dart';

/// Hazard scenario definitions used by the HUD status card.
/// Extracted from _HardwareScreenState._hazardSimulations — data is identical.
final List<Map<String, dynamic>> kHazardSimulations = [
  {
    'title': 'Path Clear',
    'desc': 'No hazards detected nearby.',
    'bg': Color(0xFFE8F5E9),
    'icon': Icons.check_circle_outline,
    'iconColor': Colors.green,
    'speech': 'Path clear. No hazards detected nearby.'
  },
  {
    'title': 'Traffic Sign Located',
    'desc': 'Traffic sign detected. Slow down and proceed carefully.',
    'bg': Color(0xFFE8EAF6),
    'icon': Icons.remove_road_rounded,
    'iconColor': Colors.indigo,
    'speech': 'Traffic sign located. Slow down and proceed carefully.'
  },
  {
    'title': 'Caution',
    'desc': 'Obstacle approaching. Proceed slowly.',
    'bg': Color(0xFFFFFDE7),
    'icon': Icons.warning_amber_rounded,
    'iconColor': Colors.amber,
    'speech': 'Caution. Obstacle approaching. Proceed slowly.'
  },
  {
    'title': 'Stairs Detected',
    'desc': 'Slow down and step carefully.',
    'bg': Color(0xFFFFF8E1),
    'icon': Icons.stairs_rounded,
    'iconColor': Colors.orange,
    'speech': 'Stairs detected. Slow down and step carefully.'
  },
  {
    'title': 'Low Light Detected',
    'desc': 'Camera visibility is low. Scanning accuracy reduced.',
    'bg': Color(0xFFFFFDE7),
    'icon': Icons.lightbulb_outline_rounded,
    'iconColor': Colors.amber,
    'speech': 'Low light detected. Scanning accuracy reduced.'
  },
  {
    'title': 'Moving Too Fast',
    'desc': 'Hold steady for a moment to resume scanning.',
    'bg': Color(0xFFFFF8E1),
    'icon': Icons.access_time_rounded,
    'iconColor': Colors.orange,
    'speech': 'Moving too fast. Hold steady for a moment.'
  },
  {
    'title': 'Vehicle Detected',
    'desc': 'Vehicle approaching. Please slow down and wait.',
    'bg': Color(0xFFFFF8E1),
    'icon': Icons.directions_car_rounded,
    'iconColor': Colors.orange,
    'speech': 'Vehicle detected. A vehicle is approaching. Please slow down and wait.'
  },
  {
    'title': 'Damaged Pathway',
    'desc': 'Pothole detected. Slow down and step carefully.',
    'bg': Color(0xFFFFF8E1),
    'icon': Icons.trending_down_rounded,
    'iconColor': Colors.orange,
    'speech': 'Damaged pathway. Pothole detected. Slow down and step carefully.'
  },
  {
    'title': 'Multiple Hazards',
    'desc': 'Complex environment detected. Proceed with extreme caution.',
    'bg': Color(0xFFFFF8E1),
    'icon': Icons.warning_amber_rounded,
    'iconColor': Colors.orange,
    'speech': 'Multiple hazards. Complex environment detected. Proceed with extreme caution.'
  },
  {
    'title': 'Obstacle Ahead',
    'desc': 'Object blocking path. Slow down.',
    'bg': Color(0xFFFFF8E1),
    'icon': Icons.block_flipped,
    'iconColor': Colors.orange,
    'speech': 'Obstacle ahead. Object blocking path. Slow down.'
  },
  {
    'title': 'Fire Hazard!',
    'desc': 'Fire or heavy smoke detected nearby. Move away immediately.',
    'bg': Color(0xFFFFEBEE),
    'icon': Icons.local_fire_department_rounded,
    'iconColor': Colors.red,
    'speech': 'Fire hazard! Fire or heavy smoke detected nearby. Move away immediately.'
  },
  {
    'title': 'STOP!',
    'desc': 'Immediate hazard in your path.',
    'bg': Color(0xFFFFEBEE),
    'icon': Icons.error_outline_rounded,
    'iconColor': Colors.red,
    'speech': 'STOP! Immediate hazard in your path.'
  },
  {
    'title': 'Person Ahead',
    'desc': 'A person is in front of you. Be careful!',
    'bg': Color(0xFFE8EAF6),
    'icon': Icons.person_rounded,
    'iconColor': Colors.indigo,
    'speech': 'Person detected. A person is in front of you, be careful.'
  },
  {
    'title': 'GO Signal Detected',
    'desc': 'Go or walk signal detected. You may proceed.',
    'bg': Color(0xFFE8F5E9),
    'icon': Icons.arrow_circle_right_outlined,
    'iconColor': Colors.green,
    'speech': 'Go signal detected. Proceed carefully.'
  },
  {
    'title': 'Traffic Light Detected',
    'desc': 'Traffic light detected. Slow down and check the signal.',
    'bg': Color(0xFFE8EAF6),
    'icon': Icons.traffic_rounded,
    'iconColor': Colors.indigo,
    'speech': 'Traffic light detected. Slow down and check the signal.'
  },
  {
    'title': 'Approaching Door',
    'desc': 'You are approaching a door.',
    'bg': Color(0xFFE8F5E9),
    'icon': Icons.door_front_door_outlined,
    'iconColor': Color(0xFF2E7D32),
    'speech': 'You are approaching a door.'
  },
  {
    'title': 'CRITICAL: VEHICLE TOO CLOSE!',
    'desc': 'Vehicle is dangerously close! Stop or avoid immediately!',
    'bg': Color(0xFFFFEBEE),
    'icon': Icons.directions_car_rounded,
    'iconColor': Colors.red,
    'speech': 'Warning! Vehicle is too close! Stop or avoid immediately!'
  }
];
