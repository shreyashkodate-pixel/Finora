class DeviceTokenModel {
  final String id;
  final String userId;
  final String token;
  final String platform;
  final String? deviceName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  const DeviceTokenModel({
    required this.id,
    required this.userId,
    required this.token,
    required this.platform,
    this.deviceName,
    this.isActive = true,
    required this.createdAt,
    required this.lastSeenAt,
  });

  factory DeviceTokenModel.fromJson(Map<String, dynamic> json) {
    return DeviceTokenModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      token: json['token'] as String? ?? '',
      platform: (json['platform'] as String?)?.toLowerCase() ?? 'android',
      deviceName: json['device_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'token': token,
      'platform': platform,
      'device_name': deviceName,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'last_seen_at': lastSeenAt.toIso8601String(),
    };
  }
}
