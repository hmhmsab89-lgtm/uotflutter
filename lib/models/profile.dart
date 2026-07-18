class Profile {
  final String id;
  final String? fullName;
  final String? username;
  final String? department;
  final String? status;
  final bool isSharingLocation;
  final double? currentLat;
  final double? currentLng;
  final DateTime? lastLocationUpdate;
  final String? avatarUrl;
  final String? bio;

  Profile({
    required this.id,
    this.fullName,
    this.username,
    this.department,
    this.status,
    required this.isSharingLocation,
    this.currentLat,
    this.currentLng,
    this.lastLocationUpdate,
    this.avatarUrl,
    this.bio,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      username: json['username'] as String?,
      department: json['department'] as String?,
      status: json['status'] as String?,
      isSharingLocation: json['is_sharing_location'] as bool? ?? false,
      currentLat: json['current_lat'] != null
          ? (json['current_lat'] as num).toDouble()
          : null,
      currentLng: json['current_lng'] != null
          ? (json['current_lng'] as num).toDouble()
          : null,
      lastLocationUpdate: json['last_location_update'] != null
          ? DateTime.parse(json['last_location_update'] as String)
          : null,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'username': username,
      'department': department,
      'status': status,
      'is_sharing_location': isSharingLocation,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'last_location_update': lastLocationUpdate?.toIso8601String(),
      'avatar_url': avatarUrl,
      'bio': bio,
    };
  }

  Profile copyWith({
    String? id,
    String? fullName,
    String? username,
    String? department,
    String? status,
    bool? isSharingLocation,
    double? currentLat,
    double? currentLng,
    DateTime? lastLocationUpdate,
    String? avatarUrl,
    String? bio,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      department: department ?? this.department,
      status: status ?? this.status,
      isSharingLocation: isSharingLocation ?? this.isSharingLocation,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
    );
  }
}
