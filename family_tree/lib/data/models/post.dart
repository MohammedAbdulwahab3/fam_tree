/// Represents a post in the family group feed
class Post {
  final String id;
  final String familyTreeId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String content;
  final List<String> photos;
  final List<String> videos;
  final List<String> files; // Document attachments (PDFs, etc.)
  final DateTime createdAt;
  final Map<String, List<String>> reactions; // emoji -> [userId1, userId2...]

  Post({
    required this.id,
    required this.familyTreeId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.content,
    this.photos = const [],
    this.videos = const [],
    this.files = const [],
    required this.createdAt,
    this.reactions = const {},
  });

  /// Create from JSON (Go backend response)
  factory Post.fromJson(Map<String, dynamic> json) {
    // Convert reactions from JSON format
    Map<String, List<String>> reactionsMap = {};
    if (json['reactions'] != null) {
      final reactionsData = json['reactions'] as Map<String, dynamic>;
      reactionsData.forEach((emoji, users) {
        reactionsMap[emoji] = List<String>.from(users as List);
      });
    }
    
    return Post(
      id: json['id'] ?? '',
      familyTreeId: json['familyTreeId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userPhoto: json['userPhoto'],
      content: json['content'] ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      videos: List<String>.from(json['videos'] ?? []),
      files: List<String>.from(json['files'] ?? []),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      reactions: reactionsMap,
    );
  }

  /// Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyTreeId': familyTreeId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'content': content,
      'photos': photos,
      'videos': videos,
      'files': files,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'reactions': reactions,
    };
  }

  Post copyWith({
    String? id,
    String? familyTreeId,
    String? userId,
    String? userName,
    String? userPhoto,
    String? content,
    List<String>? photos,
    List<String>? videos,
    List<String>? files,
    DateTime? createdAt,
    Map<String, List<String>>? reactions,
  }) {
    return Post(
      id: id ?? this.id,
      familyTreeId: familyTreeId ?? this.familyTreeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      content: content ?? this.content,
      photos: photos ?? this.photos,
      videos: videos ?? this.videos,
      files: files ?? this.files,
      createdAt: createdAt ?? this.createdAt,
      reactions: reactions ?? this.reactions,
    );
  }

  // Helper methods for reactions
  int get totalReactions {
    return reactions.values.fold(0, (sum, users) => sum + users.length);
  }

  bool hasUserReacted(String userId) {
    return reactions.values.any((users) => users.contains(userId));
  }

  String? getUserReaction(String userId) {
    for (var entry in reactions.entries) {
      if (entry.value.contains(userId)) {
        return entry.key;
      }
    }
    return null;
  }
}
