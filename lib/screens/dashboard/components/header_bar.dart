import 'package:flutter/material.dart';

class HeaderBar extends StatelessWidget {
  final VoidCallback onSOSSelected;
  final VoidCallback onSettingsSelected;
  final VoidCallback onNotificationsSelected;
  final VoidCallback onContactsSelected;

  const HeaderBar({
    super.key,
    required this.onSOSSelected,
    required this.onSettingsSelected,
    required this.onNotificationsSelected,
    required this.onContactsSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // SOS button
        GestureDetector(
          onTap: onSOSSelected,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE53E3E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
        
        // Settings / profiles float pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Color(0xFF002663)),
                onPressed: onNotificationsSelected,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: const Icon(Icons.people_outline, color: Color(0xFF002663)),
                onPressed: onContactsSelected, // Wired contacts screen trigger
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF002663)),
                onPressed: onSettingsSelected,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
