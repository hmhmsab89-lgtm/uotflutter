class Location {
  final String id;
  final String name;
  final String? description;
  final String category;
  final double lat;
  final double lng;
  final String? createdBy;
  final DateTime createdAt;
  final bool hiddenByAdmin;

  Location({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.lat,
    required this.lng,
    this.createdBy,
    required this.createdAt,
    this.hiddenByAdmin = false,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'other',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      hiddenByAdmin: json['hidden_by_admin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'lat': lat,
      'lng': lng,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'hidden_by_admin': hiddenByAdmin,
    };
  }
}
