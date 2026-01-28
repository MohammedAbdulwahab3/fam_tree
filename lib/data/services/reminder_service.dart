import 'dart:convert';
import 'api_service.dart';

class ReminderService {
  final ApiService _apiService = ApiService();

  // Get all reminders for current user
  Future<List<Reminder>> getReminders() async {
    try {
      final response = await _apiService.get('/api/reminders');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Reminder.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch reminders');
      }
    } catch (e) {
      print('Error fetching reminders: $e');
      rethrow;
    }
  }

  // Create a custom reminder
  Future<Reminder> createReminder({
    required String entityType,
    required String entityId,
    required DateTime scheduledTime,
    required String title,
    String? body,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/reminders',
        body: {
          'entityType': entityType,
          'entityId': entityId,
          'scheduledTime': scheduledTime.toIso8601String(),
          'title': title,
          'body': body ?? '',
        },
      );

      if (response.statusCode == 201) {
        return Reminder.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create reminder');
      }
    } catch (e) {
      print('Error creating reminder: $e');
      rethrow;
    }
  }

  // Snooze a reminder
  Future<Reminder> snoozeReminder(String reminderId, int durationMinutes) async {
    try {
      final response = await _apiService.put(
        '/api/reminders/$reminderId/snooze',
        body: {
          'duration': durationMinutes,
        },
      );

      if (response.statusCode == 200) {
        return Reminder.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to snooze reminder');
      }
    } catch (e) {
      print('Error snoozing reminder: $e');
      rethrow;
    }
  }

  // Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    try {
      final response = await _apiService.delete('/api/reminders/$reminderId');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete reminder');
      }
    } catch (e) {
      print('Error deleting reminder: $e');
      rethrow;
    }
  }

  // Update a reminder
  Future<Reminder> updateReminder({
    required String reminderId,
    DateTime? scheduledTime,
    String? title,
    String? body,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (scheduledTime != null) {
        updateData['scheduledTime'] = scheduledTime.toIso8601String();
      }
      if (title != null) updateData['title'] = title;
      if (body != null) updateData['body'] = body;

      final response = await _apiService.put(
        '/api/reminders/$reminderId',
        body: updateData,
      );

      if (response.statusCode == 200) {
        return Reminder.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update reminder');
      }
    } catch (e) {
      print('Error updating reminder: $e');
      rethrow;
    }
  }
}

// Reminder model
class Reminder {
  final String id;
  final String userId;
  final String entityType;
  final String entityId;
  final DateTime scheduledTime;
  final DateTime? snoozeUntil;
  final String reminderType;
  final bool isSent;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reminder({
    required this.id,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.scheduledTime,
    this.snoozeUntil,
    required this.reminderType,
    required this.isSent,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      userId: json['userId'],
      entityType: json['entityType'],
      entityId: json['entityId'],
      scheduledTime: DateTime.parse(json['scheduledTime']),
      snoozeUntil: json['snoozeUntil'] != null
          ? DateTime.parse(json['snoozeUntil'])
          : null,
      reminderType: json['reminderType'],
      isSent: json['isSent'],
      title: json['title'],
      body: json['body'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'entityType': entityType,
      'entityId': entityId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'snoozeUntil': snoozeUntil?.toIso8601String(),
      'reminderType': reminderType,
      'isSent': isSent,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
