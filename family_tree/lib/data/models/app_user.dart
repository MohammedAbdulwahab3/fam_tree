/// An account: who signed in, what they are allowed to do, and whether they
/// have been matched to a person in the family tree.
///
/// This is the account, not the person. A member has both: an account they log
/// in with, and — once an admin has confirmed who they are — a record in the
/// tree that the account is linked to. [isVerified] is the difference between
/// somebody who can look at the family and somebody who is in it.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.photoUrl = '',
    this.isVerified = false,
    this.isBanned = false,
    this.banReason = '',
    this.familyTreeId = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final String photoUrl;

  /// True once an admin has linked this account to a person in the tree.
  final bool isVerified;

  /// True when an admin has suspended the account. The server refuses every
  /// request from a suspended account, including the one that would sign them
  /// in, so this is mostly here so the app can explain why.
  final bool isBanned;

  final String banReason;
  final String familyTreeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAdmin => role == 'admin';
  bool get isMember => !isAdmin;

  /// The first name, for greeting somebody by it.
  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Initials for an avatar with no photograph.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  /// Aliases kept so widgets written against the old Firebase `User` object
  /// keep reading naturally after the migration to backend auth.
  String get uid => id;
  String get displayName => name;
  String? get photoURL => photoUrl.isEmpty ? null : photoUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      photoUrl: json['profilePhotoUrl'] as String? ??
          json['photoUrl'] as String? ??
          '',
      isVerified: json['isVerified'] as bool? ?? false,
      isBanned: json['isBanned'] as bool? ?? false,
      banReason: json['banReason'] as String? ?? '',
      familyTreeId: json['familyTreeId'] as String? ?? '',
      createdAt: _date(json['created_at'] ?? json['createdAt']),
      updatedAt: _date(json['updated_at'] ?? json['updatedAt']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// Written with the same keys the server sends, so a user cached on disk
  /// reads back identically.
  ///
  /// This used to write `photoUrl` while [fromJson] preferred
  /// `profilePhotoUrl`, so every restored session came back without its
  /// photograph — and without its role or verified flag, which were simply not
  /// written at all.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'profilePhotoUrl': photoUrl,
      'isVerified': isVerified,
      'isBanned': isBanned,
      'banReason': banReason,
      'familyTreeId': familyTreeId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? photoUrl,
    bool? isVerified,
    bool? isBanned,
    String? banReason,
    String? familyTreeId,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      isVerified: isVerified ?? this.isVerified,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      familyTreeId: familyTreeId ?? this.familyTreeId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.email == email &&
      other.name == name &&
      other.role == role &&
      other.photoUrl == photoUrl &&
      other.isVerified == isVerified &&
      other.isBanned == isBanned;

  @override
  int get hashCode =>
      Object.hash(id, email, name, role, photoUrl, isVerified, isBanned);
}
