class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;
  final bool isActive;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
    this.isActive = true,
  });

  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relationship,
    bool? isActive,
  }) {
    return EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'isActive': isActive,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relationship: json['relationship'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }
}
