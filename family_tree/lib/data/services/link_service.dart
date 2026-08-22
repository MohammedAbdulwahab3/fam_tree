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

      ApiService.ensureOk(response, whileDoing: 'sending your claim');
      return LinkRequest.fromJson(jsonDecode(response.body));
    } catch (e) {
      print('Error requesting link: $e');
      rethrow;
    }
  }

  /// Withdraw the caller's own pending claim.
  Future<void> cancelMyRequest() async {
    final response = await _apiService.delete('/api/link-requests/mine');
    ApiService.ensureOk(response, whileDoing: 'withdrawing your claim');
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
  /// Approve or reject a claim. [reason] is shown to the member on a rejection,
  /// so they know why and what to do instead.
  Future<LinkRequest> updateLinkStatus(
    String requestId,
    String status, {
    String? reason,
  }) async {
    try {
      final response = await _apiService.put(
        '/api/admin/link-requests/$requestId',
        body: {
          'status': status,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );

      ApiService.ensureOk(response, whileDoing: 'saving your decision');
      return LinkRequest.fromJson(jsonDecode(response.body));
    } catch (e) {
      print('Error updating link request: $e');
      rethrow;
    }
  }
}

// Link Status model
class LinkStatus {
  final bool isVerified;

  /// "verified", "pending", "rejected", or "not_linked".
  ///
  /// "rejected" used to be indistinguishable from "not_linked", which left a
  /// turned-down member with no explanation and nothing to do but submit the
  /// same claim again.
  final String status;
  final String? requestId;
  final String? personId;

  /// The name of the person claimed, so the UI can say who rather than showing
  /// a bare id.
  final String? personName;

  /// What the admin said when turning the claim down. Empty when they gave no
  /// reason.
  final String? reason;

  final DateTime? requestedAt;
  final DateTime? processedAt;

  LinkStatus({
    required this.isVerified,
    required this.status,
    this.requestId,
    this.personId,
    this.personName,
    this.reason,
    this.requestedAt,
    this.processedAt,
  });

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  /// Whether the member can start a new claim right now.
  bool get canClaim => !isVerified && !isPending;

  factory LinkStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String key) {
      final raw = json[key];
      return raw is String ? DateTime.tryParse(raw) : null;
    }

    final reason = (json['reason'] as String?)?.trim();

    return LinkStatus(
      isVerified: json['isVerified'] ?? false,
      status: json['status'] ?? 'not_linked',
      requestId: json['requestId'],
      personId: json['personId'],
      personName: (json['personName'] as String?)?.trim(),
      reason: reason == null || reason.isEmpty ? null : reason,
      requestedAt: parse('requestedAt'),
      processedAt: parse('processedAt'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isVerified': isVerified,
      'status': status,
      'requestId': requestId,
      'personId': personId,
      'personName': personName,
      'reason': reason,
      'requestedAt': requestedAt?.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
    };
  }
}

/// The account behind a claim, as the admin list returns it.
class LinkRequester {
  final String id;
  final String name;
  final String email;
  final String role;
  final String photoUrl;
  final DateTime? joinedAt;
  final bool isVerified;

  const LinkRequester({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl = '',
    this.joinedAt,
    this.isVerified = false,
  });

  bool get isAdmin => role == 'admin';

  factory LinkRequester.fromJson(Map<String, dynamic> json) => LinkRequester(
        id: json['id'] ?? '',
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? json['name']
            : (json['email'] as String? ?? 'Unknown'),
        email: json['email'] ?? '',
        role: json['role'] ?? 'member',
        photoUrl: json['profilePhotoUrl'] ?? '',
        joinedAt:
            json['joinedAt'] != null ? DateTime.tryParse(json['joinedAt']) : null,
        isVerified: json['isVerified'] ?? false,
      );
}

/// The person being claimed, resolved to names an admin can recognise.
class LinkTargetPerson {
  final String id;
  final String fullName;
  final DateTime? birthDate;
  final DateTime? deathDate;
  final String gender;
  final String photoUrl;
  final List<String> parentNames;
  final List<String> spouseNames;
  final List<String> childNames;

  /// Set when another account already owns this record — approving would be a
  /// mistake, so the admin sees it before deciding.
  final String? alreadyClaimedBy;

  const LinkTargetPerson({
    required this.id,
    required this.fullName,
    this.birthDate,
    this.deathDate,
    this.gender = '',
    this.photoUrl = '',
    this.parentNames = const [],
    this.spouseNames = const [],
    this.childNames = const [],
    this.alreadyClaimedBy,
  });

  bool get isDeceased => deathDate != null;

  String get lifespan {
    if (birthDate == null && deathDate == null) return '';
    final birth = birthDate?.year.toString() ?? '?';
    final death = deathDate?.year.toString() ?? 'Present';
    return '$birth – $death';
  }

  factory LinkTargetPerson.fromJson(Map<String, dynamic> json) =>
      LinkTargetPerson(
        id: json['id'] ?? '',
        fullName: json['fullName'] ?? 'Unnamed person',
        birthDate: json['birthDate'] != null
            ? DateTime.tryParse(json['birthDate'])
            : null,
        deathDate: json['deathDate'] != null
            ? DateTime.tryParse(json['deathDate'])
            : null,
        gender: json['gender'] ?? '',
        photoUrl: json['profilePhotoUrl'] ?? '',
        parentNames: List<String>.from(json['parentNames'] ?? const []),
        spouseNames: List<String>.from(json['spouseNames'] ?? const []),
        childNames: List<String>.from(json['childNames'] ?? const []),
        alreadyClaimedBy: json['alreadyClaimedBy'],
      );
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

  /// Why the claim was turned down, when it was.
  final String? reason;

  /// Both sides resolved to names. Present on the admin listing; null on the
  /// bare record the create endpoint echoes back.
  final LinkRequester? requester;
  final LinkTargetPerson? person;

  LinkRequest({
    required this.id,
    required this.userId,
    required this.personId,
    required this.familyTreeId,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
    this.reason,
    this.requester,
    this.person,
  });

  /// Whether an admin has everything needed to decide on this request.
  bool get isReviewable => requester != null && person != null;

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
      reason: json['reason'],
      requester: json['requester'] != null
          ? LinkRequester.fromJson(json['requester'] as Map<String, dynamic>)
          : null,
      person: json['person'] != null
          ? LinkTargetPerson.fromJson(json['person'] as Map<String, dynamic>)
          : null,
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
      'reason': reason,
    };
  }
}
