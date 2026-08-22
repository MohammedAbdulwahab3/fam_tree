/// App user model with role information from backend
class AppUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final String photoUrl;
  final bool isBanned;
  final String banReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.photoUrl = '',
    this.isBanned = false,
    this.banReason = '',
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isMember => role == 'member';

  /// Aliases kept so widgets written against the old Firebase `User` object
  /// keep reading naturally after the migration to backend auth.
  String get uid => id;
  String get displayName => name;
  String? get photoURL => photoUrl.isEmpty ? null : photoUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'member',
      photoUrl: json['profilePhotoUrl'] ?? json['photoUrl'] ?? '',
      isBanned: json['isBanned'] ?? false,
      banReason: json['banReason'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'photoUrl': photoUrl,
      'isBanned': isBanned,
      'banReason': banReason,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? photoUrl,
    bool? isBanned,
    String? banReason,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
