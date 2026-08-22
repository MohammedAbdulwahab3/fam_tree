class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String entityType;
  final String entityId;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime sentAt;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.body,
    required this.data,
    required this.sentAt,
    this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['userId'],
      type: json['type'],
      entityType: json['entityType'],
      entityId: json['entityId'],
      title: json['title'],
      body: json['body'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      sentAt: DateTime.parse(json['sentAt']),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'entityType': entityType,
      'entityId': entityId,
      'title': title,
      'body': body,
      'data': data,
      'sentAt': sentAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class NotificationPreference {
  final String id;
  final String userId;
  final bool eventsEnabled;
  final bool postsEnabled;
  final bool messagesEnabled;
  final bool commentsEnabled;
  final bool mentionsEnabled;
  final DateTime? quietHoursStart;
  final DateTime? quietHoursEnd;

  NotificationPreference({
    required this.id,
    required this.userId,
    required this.eventsEnabled,
    required this.postsEnabled,
    required this.messagesEnabled,
    required this.commentsEnabled,
    required this.mentionsEnabled,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      id: json['id'],
      userId: json['userId'],
      eventsEnabled: json['eventsEnabled'],
      postsEnabled: json['postsEnabled'],
      messagesEnabled: json['messagesEnabled'],
      commentsEnabled: json['commentsEnabled'],
      mentionsEnabled: json['mentionsEnabled'],
      quietHoursStart: json['quietHoursStart'] != null
          ? DateTime.parse(json['quietHoursStart'])
          : null,
      quietHoursEnd: json['quietHoursEnd'] != null
          ? DateTime.parse(json['quietHoursEnd'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'eventsEnabled': eventsEnabled,
      'postsEnabled': postsEnabled,
      'messagesEnabled': messagesEnabled,
      'commentsEnabled': commentsEnabled,
      'mentionsEnabled': mentionsEnabled,
      'quietHoursStart': quietHoursStart?.toIso8601String(),
      'quietHoursEnd': quietHoursEnd?.toIso8601String(),
    };
  }

  NotificationPreference copyWith({
    String? id,
    String? userId,
    bool? eventsEnabled,
    bool? postsEnabled,
    bool? messagesEnabled,
    bool? commentsEnabled,
    bool? mentionsEnabled,
    DateTime? quietHoursStart,
    DateTime? quietHoursEnd,
  }) {
    return NotificationPreference(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventsEnabled: eventsEnabled ?? this.eventsEnabled,
      postsEnabled: postsEnabled ?? this.postsEnabled,
      messagesEnabled: messagesEnabled ?? this.messagesEnabled,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      mentionsEnabled: mentionsEnabled ?? this.mentionsEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }
}
