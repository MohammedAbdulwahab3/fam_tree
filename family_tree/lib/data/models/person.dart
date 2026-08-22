import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a person in the family tree
class Person {
  final String id;
  final String familyTreeId;
  final String? authUserId; // Firebase Auth UID of the user who owns this record
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final DateTime? deathDate;
  final String? gender; // 'male', 'female', 'other'
  final String? bio;
  final String? profilePhotoUrl;
  final List<String> photos;
  final List<LifeEvent> lifeEvents;
  final Relationships relationships;
  final DateTime createdAt;
  final DateTime updatedAt;

  Person({
    required this.id,
    required this.familyTreeId,
    this.authUserId,
    required this.firstName,
    required this.lastName,
    this.birthDate,
    this.deathDate,
    this.gender,
    this.bio,
    this.profilePhotoUrl,
    this.photos = const [],
    this.lifeEvents = const [],
    required this.relationships,
    required this.createdAt,
    required this.updatedAt,
  });

  // Display as "FirstName LastName"
  String get fullName {
    if (lastName.isEmpty) return firstName;
    return '$firstName $lastName';
  }
  
  // Short name for compact displays
  String get shortName => firstName;
  
  String get lifespan {
    if (birthDate == null && deathDate == null) return '';
    
    final birth = birthDate != null ? _formatYear(birthDate!) : '?';
    final death = deathDate != null ? _formatYear(deathDate!) : 'Present';
    
    return '$birth - $death';
  }
  
  bool get isDeceased => deathDate != null;
  
  int? get age {
    if (birthDate == null) return null;
    final end = deathDate ?? DateTime.now();
    return end.year - birthDate!.year;
  }

  String _formatYear(DateTime date) => date.year.toString();

  // Factory from Firestore document
  factory Person.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Person(
      id: doc.id,
      familyTreeId: data['familyTreeId'] ?? '',
      authUserId: data['authUserId'],
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      birthDate: data['birthDate'] != null
          ? (data['birthDate'] as Timestamp).toDate()
          : null,
      deathDate: data['deathDate'] != null
          ? (data['deathDate'] as Timestamp).toDate()
          : null,
      gender: data['gender'],
      bio: data['bio'],
      profilePhotoUrl: data['profilePhotoUrl'],
      photos: List<String>.from(data['photos'] ?? []),
      lifeEvents: (data['lifeEvents'] as List<dynamic>?)
              ?.map((e) => LifeEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      relationships: Relationships.fromJson(
        data['relationships'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'familyTreeId': familyTreeId,
      'authUserId': authUserId,
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'deathDate': deathDate != null ? Timestamp.fromDate(deathDate!) : null,
      'gender': gender,
      'bio': bio,
      'profilePhotoUrl': profilePhotoUrl,
      'photos': photos,
      'lifeEvents': lifeEvents.map((e) => e.toJson()).toList(),
      'relationships': relationships.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Person copyWith({
    String? id,
    String? familyTreeId,
    String? authUserId,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    DateTime? deathDate,
    String? gender,
    String? bio,
    String? profilePhotoUrl,
    List<String>? photos,
    List<LifeEvent>? lifeEvents,
    Relationships? relationships,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id ?? this.id,
      familyTreeId: familyTreeId ?? this.familyTreeId,
      authUserId: authUserId ?? this.authUserId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthDate: birthDate ?? this.birthDate,
      deathDate: deathDate ?? this.deathDate,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      photos: photos ?? this.photos,
      lifeEvents: lifeEvents ?? this.lifeEvents,
      relationships: relationships ?? this.relationships,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert DateTime to RFC3339 format for Go backend
  static String? _toRfc3339(DateTime? date) {
    if (date == null) return null;
    return date.toUtc().toIso8601String();
  }

  /// Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyTreeId': familyTreeId,
      'authUserId': authUserId,
      'firstName': firstName,
      'lastName': lastName,
      'birthDate': _toRfc3339(birthDate),
      'deathDate': _toRfc3339(deathDate),
      'gender': gender,
      'bio': bio,
      'profilePhotoUrl': profilePhotoUrl,
      'photos': photos,
      'lifeEvents': lifeEvents.map((e) => e.toJson()).toList(),
      'relationships': relationships.toJson(),
      'createdAt': _toRfc3339(createdAt),
      'updatedAt': _toRfc3339(updatedAt),
    };
  }

  /// Create from JSON (API response)
  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] ?? '',
      familyTreeId: json['familyTreeId'] ?? '',
      authUserId: json['authUserId'],
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      deathDate: json['deathDate'] != null ? DateTime.parse(json['deathDate']) : null,
      gender: json['gender'] ?? '',
      bio: json['bio'] ?? '',
      profilePhotoUrl: json['profilePhotoUrl'] ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      lifeEvents: (json['lifeEvents'] as List<dynamic>?)
              ?.map((e) => LifeEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      relationships: json['relationships'] != null
          ? Relationships.fromJson(json['relationships'] as Map<String, dynamic>)
          : Relationships(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    );
  }
}

/// Family relationships for a person
class Relationships {
  final List<String> parentIds;
  final List<RelationshipConnection> spouses;
  final List<String> childrenIds;
  final List<String> siblingIds;

  Relationships({
    this.parentIds = const [],
    this.spouses = const [],
    this.childrenIds = const [],
    this.siblingIds = const [],
  });
  
  // Helper getter for spouse IDs
  List<String> get spouseIds => spouses.map((s) => s.personId).toList();

  Relationships copyWith({
    List<String>? parentIds,
    List<RelationshipConnection>? spouses,
    List<String>? childrenIds,
    List<String>? siblingIds,
  }) {
    return Relationships(
      parentIds: parentIds ?? this.parentIds,
      spouses: spouses ?? this.spouses,
      childrenIds: childrenIds ?? this.childrenIds,
      siblingIds: siblingIds ?? this.siblingIds,
    );
  }

  factory Relationships.fromJson(Map<String, dynamic> json) {
    return Relationships(
      parentIds: List<String>.from(json['parents'] ?? []),
      spouses: (json['spouses'] as List<dynamic>?)
              ?.map((e) => RelationshipConnection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      childrenIds: List<String>.from(json['children'] ?? []),
      siblingIds: List<String>.from(json['siblings'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parents': parentIds,
      'spouses': spouses.map((e) => e.toJson()).toList(),
      'children': childrenIds,
      'siblings': siblingIds,
    };
  }
}

/// Represents a spousal relationship with metadata
class RelationshipConnection {
  final String personId;
  final RelationshipType type;
  final DateTime? startDate;
  final DateTime? endDate;

  RelationshipConnection({
    required this.personId,
    required this.type,
    this.startDate,
    this.endDate,
  });

  factory RelationshipConnection.fromJson(Map<String, dynamic> json) {
    return RelationshipConnection(
      personId: json['personId'] ?? '',
      type: RelationshipType.fromString(json['type'] ?? 'marriage'),
      startDate: json['startDate'] != null
          ? _parseDate(json['startDate'])
          : null,
      endDate: json['endDate'] != null
          ? _parseDate(json['endDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'personId': personId,
      'type': type.value,
      'startDate': startDate?.toUtc().toIso8601String(),
      'endDate': endDate?.toUtc().toIso8601String(),
    };
  }

  // Helper to parse date from either Timestamp or ISO8601 string
  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is String) return DateTime.parse(date);
    return null;
  }
}

/// Types of family relationships
enum RelationshipType {
  biological('biological'),
  marriage('marriage'),
  adoption('adoption'),
  step('step'),
  partnership('partnership');

  final String value;
  const RelationshipType(this.value);

  static RelationshipType fromString(String value) {
    return RelationshipType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => RelationshipType.biological,
    );
  }
}

/// A life event for a person
class LifeEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final String? location;
  final List<String> photos;

  LifeEvent({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.location,
    this.photos = const [],
  });

  factory LifeEvent.fromJson(Map<String, dynamic> json) {
    return LifeEvent(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      date: json['date'] != null
          ? _parseDate(json['date']) ?? DateTime.now()
          : DateTime.now(),
      location: json['location'],
      photos: List<String>.from(json['photos'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toUtc().toIso8601String(),
      'location': location,
      'photos': photos,
    };
  }

  // Helper to parse date from either Timestamp or ISO8601 string
  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is String) return DateTime.parse(date);
    return null;
  }
}
