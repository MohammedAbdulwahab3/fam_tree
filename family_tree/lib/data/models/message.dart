/// Represents a message in the family group chat
class Message {
  final String id;
  final String familyTreeId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String text;
  final DateTime sentAt;
  final bool isRead;
  final String type; // 'text', 'image', 'video'
  final String? mediaUrl;

  Message({
    required this.id,
    required this.familyTreeId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.text,
    required this.sentAt,
    this.isRead = false,
    this.type = 'text',
    this.mediaUrl,
  });

  /// Create from JSON (Go backend response)
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      familyTreeId: json['familyTreeId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userPhoto: json['userPhoto'],
      text: json['text'] ?? '',
      sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : DateTime.now(),
      isRead: json['isRead'] ?? false,
      type: json['type'] ?? 'text',
      mediaUrl: json['mediaUrl'],
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
      'text': text,
      'sentAt': sentAt.toUtc().toIso8601String(),
      'isRead': isRead,
      'type': type,
      'mediaUrl': mediaUrl,
    };
  }

  Message copyWith({
    String? id,
    String? familyTreeId,
    String? userId,
    String? userName,
    String? userPhoto,
    String? text,
    DateTime? sentAt,
    bool? isRead,
    String? type,
    String? mediaUrl,
  }) {
    return Message(
      id: id ?? this.id,
      familyTreeId: familyTreeId ?? this.familyTreeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
    );
  }
}
