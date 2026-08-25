/// Represents a person in the family tree
class Person {
  final String id;
  final String familyTreeId;
  final String?
      authUserId; // Firebase Auth UID of the user who owns this record
  final String firstName;
  final String lastName;

  /// Names per locale tag (e.g. 'am'), served by the backend
  final Map<String, LocalizedPersonName> localizedNames;
  final DateTime? birthDate;
  final DateTime? deathDate;
  final String? gender; // 'male', 'female', 'other'
  final String? bio;
  final String? profilePhotoUrl;

  /// Self-authored detail. A linked member writes these about themselves and
  /// everyone browsing the tree reads them on the person's card.
  final String? occupation;
  final String? birthPlace;
  final String? currentResidence;
  final String? education;
  final String? contactEmail;
  final String? contactPhone;
  final List<String> interests;

  /// 'single' | 'married' | 'divorced' | 'widowed', or empty when unstated.
  final String? maritalStatus;

  /// Free text, for a spouse with no record of their own in the tree. A spouse
  /// who *is* in the tree lives in [relationships].
  final String? spouseName;

  /// Set by an admin. Kept separate from [deathDate] because a family often
  /// knows someone has died long before anyone can name the date.
  final bool isDeceasedFlag;

  final List<String> photos;
  final List<LifeEvent> lifeEvents;
  final Relationships relationships;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Person({
    required this.id,
    required this.familyTreeId,
    this.authUserId,
    required this.firstName,
    required this.lastName,
    this.localizedNames = const {},
    this.birthDate,
    this.deathDate,
    this.gender,
    this.bio,
    this.profilePhotoUrl,
    this.occupation,
    this.birthPlace,
    this.currentResidence,
    this.education,
    this.contactEmail,
    this.contactPhone,
    this.interests = const [],
    this.maritalStatus,
    this.spouseName,
    this.isDeceasedFlag = false,
    this.photos = const [],
    this.lifeEvents = const [],
    required this.relationships,
    this.displayOrder = 0,
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

  /// Either an explicit admin flag or a recorded death date. A family often
  /// knows someone has passed before the date is known, so the flag alone is
  /// enough.
  bool get isDeceased => isDeceasedFlag || deathDate != null;

  int? get age {
    if (birthDate == null) return null;
    final end = deathDate ?? DateTime.now();
    return end.year - birthDate!.year;
  }

  /// Resolve the best localized name for a locale tag ('am', 'am-ET', ...)
  LocalizedPersonName? _localizedNameForLocaleTag(String? localeTag) {
    if (localeTag == null || localeTag.isEmpty || localizedNames.isEmpty) {
      return null;
    }
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    final exact = localizedNames[normalized];
    if (exact != null && exact.hasAnyValue) return exact;
    final language = normalized.split('-').first;
    final match = localizedNames[language];
    if (match != null && match.hasAnyValue) return match;
    return null;
  }

  String fullNameForLocaleTag(String? localeTag) {
    final localized = _localizedNameForLocaleTag(localeTag);
    if (localized != null && localized.fullName.isNotEmpty) {
      return localized.fullName;
    }
    return fullName;
  }

  String shortNameForLocaleTag(String? localeTag) {
    final localized = _localizedNameForLocaleTag(localeTag);
    if (localized != null && localized.firstName.isNotEmpty) {
      return localized.firstName;
    }
    return shortName;
  }

  String initialsForLocaleTag(String? localeTag) {
    final localized = _localizedNameForLocaleTag(localeTag);
    final first = localized?.firstName.trim() ?? firstName.trim();
    final last = localized?.lastName.trim() ?? lastName.trim();
    if (first.isEmpty && last.isEmpty) return '?';
    final buffer = StringBuffer();
    if (first.isNotEmpty) buffer.write(first.substring(0, 1));
    if (last.isNotEmpty) buffer.write(last.substring(0, 1));
    return buffer.toString();
  }

  /// Every name this person can be matched against, across locales
  Iterable<String> get searchableNames sync* {
    if (firstName.isNotEmpty) yield firstName;
    if (lastName.isNotEmpty) yield lastName;
    if (fullName.isNotEmpty) yield fullName;
    for (final localized in localizedNames.values) {
      if (localized.firstName.isNotEmpty) yield localized.firstName;
      if (localized.lastName.isNotEmpty) yield localized.lastName;
      if (localized.fullName.isNotEmpty) yield localized.fullName;
    }
  }

  bool matchesNameQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return searchableNames.any((n) => n.toLowerCase().contains(normalized));
  }

  String _formatYear(DateTime date) => date.year.toString();

  Person copyWith({
    String? id,
    String? familyTreeId,
    String? authUserId,
    String? firstName,
    String? lastName,
    Map<String, LocalizedPersonName>? localizedNames,
    DateTime? birthDate,
    DateTime? deathDate,
    String? gender,
    String? bio,
    String? profilePhotoUrl,
    String? occupation,
    String? birthPlace,
    String? currentResidence,
    String? education,
    String? contactEmail,
    String? contactPhone,
    List<String>? interests,
    String? maritalStatus,
    String? spouseName,
    bool? isDeceasedFlag,
    List<String>? photos,
    List<LifeEvent>? lifeEvents,
    Relationships? relationships,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    // `??` can only ever set a date, never unset one. These let the editor
    // clear a birth or death date the user removed.
    bool clearBirthDate = false,
    bool clearDeathDate = false,
  }) {
    return Person(
      id: id ?? this.id,
      familyTreeId: familyTreeId ?? this.familyTreeId,
      authUserId: authUserId ?? this.authUserId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      localizedNames: localizedNames ?? this.localizedNames,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      deathDate: clearDeathDate ? null : (deathDate ?? this.deathDate),
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      occupation: occupation ?? this.occupation,
      birthPlace: birthPlace ?? this.birthPlace,
      currentResidence: currentResidence ?? this.currentResidence,
      education: education ?? this.education,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      interests: interests ?? this.interests,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      spouseName: spouseName ?? this.spouseName,
      isDeceasedFlag: isDeceasedFlag ?? this.isDeceasedFlag,
      photos: photos ?? this.photos,
      lifeEvents: lifeEvents ?? this.lifeEvents,
      relationships: relationships ?? this.relationships,
      displayOrder: displayOrder ?? this.displayOrder,
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
      'localizedNames': localizedNames.map((k, v) => MapEntry(k, v.toJson())),
      'birthDate': _toRfc3339(birthDate),
      'deathDate': _toRfc3339(deathDate),
      'gender': gender,
      'bio': bio,
      'profilePhotoUrl': profilePhotoUrl,
      'occupation': occupation,
      'birthPlace': birthPlace,
      'currentResidence': currentResidence,
      'education': education,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'interests': interests,
      'maritalStatus': maritalStatus,
      'spouseName': spouseName,
      'isDeceased': isDeceasedFlag,
      'photos': photos,
      'lifeEvents': lifeEvents.map((e) => e.toJson()).toList(),
      'relationships': relationships.toJson(),
      'displayOrder': displayOrder,
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
      localizedNames: (json['localizedNames'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(
                    k.toLowerCase(),
                    LocalizedPersonName.fromJson(v as Map<String, dynamic>),
                  )) ??
          const {},
      birthDate:
          json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      deathDate:
          json['deathDate'] != null ? DateTime.parse(json['deathDate']) : null,
      gender: json['gender'] ?? '',
      bio: json['bio'] ?? '',
      profilePhotoUrl: json['profilePhotoUrl'] ?? '',
      occupation: json['occupation'] ?? '',
      birthPlace: json['birthPlace'] ?? '',
      currentResidence: json['currentResidence'] ?? '',
      education: json['education'] ?? '',
      contactEmail: json['contactEmail'] ?? '',
      contactPhone: json['contactPhone'] ?? '',
      interests: List<String>.from(json['interests'] ?? []),
      maritalStatus: json['maritalStatus'] ?? '',
      spouseName: json['spouseName'] ?? '',
      isDeceasedFlag: json['isDeceased'] ?? false,
      photos: List<String>.from(json['photos'] ?? []),
      lifeEvents: (json['lifeEvents'] as List<dynamic>?)
              ?.map((e) => LifeEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      relationships: json['relationships'] != null
          ? Relationships.fromJson(
              json['relationships'] as Map<String, dynamic>)
          : Relationships(),
      displayOrder: json['displayOrder'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
}

/// A person's name in one specific locale
class LocalizedPersonName {
  final String firstName;
  final String lastName;

  const LocalizedPersonName({this.firstName = '', this.lastName = ''});

  bool get hasAnyValue =>
      firstName.trim().isNotEmpty || lastName.trim().isNotEmpty;

  String get fullName {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isEmpty) return l;
    if (l.isEmpty) return f;
    return '$f $l';
  }

  LocalizedPersonName copyWith({String? firstName, String? lastName}) {
    return LocalizedPersonName(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
      };

  factory LocalizedPersonName.fromJson(Map<String, dynamic> json) {
    return LocalizedPersonName(
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
    );
  }
}

/// Family relationships for a person
/// A person's family connections.
///
/// [parentIds] is the single source of truth for descent. [childrenIds] is
/// derived by the server from everyone else's [parentIds] and arrives with the
/// tree — it is never sent back, and writing to it has no effect.
///
/// Both directions used to be written by the app, in two separate requests:
/// create the child with a parent, then update the parent to list the child.
/// A failure between the two left a person who both had a parent and counted
/// as a root, and the layout and the canvas then disagreed about where to draw
/// them.
class Relationships {
  final List<String> parentIds;
  final List<RelationshipConnection> spouses;

  /// Derived by the server. Read-only in practice.
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
              ?.map((e) =>
                  RelationshipConnection.fromJson(e as Map<String, dynamic>))
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
      startDate:
          json['startDate'] != null ? _parseDate(json['startDate']) : null,
      endDate: json['endDate'] != null ? _parseDate(json['endDate']) : null,
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

  // Helper to parse an ISO8601 date string from the API
  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is String) return DateTime.tryParse(date);
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

  // Helper to parse an ISO8601 date string from the API
  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is String) return DateTime.tryParse(date);
    return null;
  }
}

/// How many people sit below [personId] in the tree: their children, those
/// children's children, and so on.
///
/// Descent is read from [Relationships.parentIds], which the server treats as
/// the single source of truth — [Relationships.childrenIds] is derived from it
/// and is not written back, so walking parents is the direction that is always
/// populated.
///
/// The `seen` set is not paranoia. Nothing in the schema stops a record from
/// ending up its own ancestor — an admin reparenting two people in the wrong
/// order is enough — and a plain recursion over such a loop runs until the
/// stack gives out, taking the whole screen with it.
int countDescendants(String personId, List<Person> everyone) {
  final childrenByParent = <String, List<String>>{};
  for (final person in everyone) {
    for (final parentId in person.relationships.parentIds) {
      (childrenByParent[parentId] ??= <String>[]).add(person.id);
    }
  }

  final seen = <String>{personId};
  final pending = <String>[personId];
  var count = 0;

  while (pending.isNotEmpty) {
    for (final childId in childrenByParent[pending.removeLast()] ?? const []) {
      // add() is false when the id is already counted, which is what keeps a
      // cycle — or a person reachable by two paths — from being counted twice.
      if (seen.add(childId)) {
        count++;
        pending.add(childId);
      }
    }
  }

  return count;
}
