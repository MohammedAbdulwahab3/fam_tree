import 'dart:convert';
import 'api_service.dart';

class LinkService {
  final ApiService _apiService = ApiService();

  // Get current user's link status
  Future<LinkStatus> getMyLinkStatus() async {
    try {
      final response = await _apiService.get('/api/link-requests/my-status');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LinkStatus.fromJson(data);
      } else {
        throw Exception('Failed to fetch link status');
      }
    } catch (e) {
      print('Error fetching link status: $e');
      rethrow;
    }
  }

  // Request to link user account to a person in the tree
  Future<LinkRequest> requestLink(String personId) async {
    try {
      final response = await _apiService.post(
        '/api/link-requests',
        body: {
          'personId': personId,
        },
      );

      if (response.statusCode == 201) {
        return LinkRequest.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to create link request');
      }
    } catch (e) {
      print('Error requesting link: $e');
      rethrow;
    }
  }

  // Admin: Get all pending link requests
  Future<List<LinkRequest>> getPendingRequests() async {
    try {
      final response = await _apiService.get('/api/admin/link-requests');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => LinkRequest.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch link requests');
      }
    } catch (e) {
      print('Error fetching link requests: $e');
      rethrow;
    }
  }

  // Admin: Approve or reject a link request
  Future<LinkRequest> updateLinkStatus(String requestId, String status) async {
    try {
      final response = await _apiService.put(
        '/api/admin/link-requests/$requestId',
        body: {
          'status': status,
        },
      );

      if (response.statusCode == 200) {
        return LinkRequest.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update link request');
      }
    } catch (e) {
      print('Error updating link request: $e');
      rethrow;
    }
  }
}

// Link Status model
class LinkStatus {
  final bool isVerified;
  final String status; // "verified", "pending", "not_linked"
  final String? requestId;
  final String? personId;
  final DateTime? requestedAt;

  LinkStatus({
    required this.isVerified,
    required this.status,
    this.requestId,
    this.personId,
    this.requestedAt,
  });

  factory LinkStatus.fromJson(Map<String, dynamic> json) {
    return LinkStatus(
      isVerified: json['isVerified'] ?? false,
      status: json['status'],
      requestId: json['requestId'],
      personId: json['personId'],
      requestedAt: json['requestedAt'] != null
          ? DateTime.parse(json['requestedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isVerified': isVerified,
      'status': status,
      'requestId': requestId,
      'personId': personId,
      'requestedAt': requestedAt?.toIso8601String(),
    };
  }
}

// Link Request model
class LinkRequest {
  final String id;
  final String userId;
  final String personId;
  final String familyTreeId;
  final String status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processedBy;

  LinkRequest({
    required this.id,
    required this.userId,
    required this.personId,
    required this.familyTreeId,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
  });

  factory LinkRequest.fromJson(Map<String, dynamic> json) {
    return LinkRequest(
      id: json['id'],
      userId: json['userId'],
      personId: json['personId'],
      familyTreeId: json['familyTreeId'],
      status: json['status'],
      requestedAt: DateTime.parse(json['requestedAt']),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'])
          : null,
      processedBy: json['processedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'personId': personId,
      'familyTreeId': familyTreeId,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'processedBy': processedBy,
    };
  }
}
