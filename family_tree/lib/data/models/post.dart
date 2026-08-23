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
  final String? audioUrl; // Voice message URL
  final DateTime createdAt;
  final Map<String, String> reactions; // userId -> emoji

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
    this.audioUrl,
    required this.createdAt,
    this.reactions = const {},
  });

  /// Create from JSON (Go backend response)
  factory Post.fromJson(Map<String, dynamic> json) {
    // Convert reactions from JSON format
    // Backend returns: [{id, postId, userId, emoji}, ...]
    // We convert to: {userId: emoji, ...} for easy lookup
    Map<String, String> reactionsMap = {};
    if (json['reactions'] != null) {
      if (json['reactions'] is List) {
        // New format: array of reaction objects
        for (final reaction in json['reactions']) {
          if (reaction is Map<String, dynamic>) {
            final userId = reaction['userId'] as String?;
            final emoji = reaction['emoji'] as String? ?? '❤️';
            if (userId != null) {
              reactionsMap[userId] = emoji;
            }
          }
        }
      } else if (json['reactions'] is Map) {
        // Legacy format: {userId: emoji}
        final reactionsData = json['reactions'] as Map<String, dynamic>;
        reactionsData.forEach((key, value) {
          reactionsMap[key] = value.toString();
        });
      }
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
      audioUrl: json['audioUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
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
      'audioUrl': audioUrl,
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
    String? audioUrl,
    DateTime? createdAt,
    Map<String, String>? reactions,
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
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt ?? this.createdAt,
      reactions: reactions ?? this.reactions,
    );
  }

  // Helper methods for reactions
  int get totalReactions => reactions.length;

  bool hasUserReacted(String userId) => reactions.containsKey(userId);

  String? getUserReaction(String userId) => reactions[userId];
}
