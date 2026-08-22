/// Represents an appointment/event in the family calendar
class Appointment {
  final String id;
  final String familyTreeId;
  final String title;
  final String? description;
  final DateTime dateTime;
  final String? location;
  final String? mapLink; // Google Maps URL for routing
  final String createdBy;
  final List<String> attendees;
  final List<String>? maybes; // Users who responded 'maybe'
  final List<String>? declined; // Users who declined

  Appointment({
    required this.id,
    required this.familyTreeId,
    required this.title,
    this.description,
    required this.dateTime,
    this.location,
    this.mapLink,
    required this.createdBy,
    this.attendees = const [],
    this.maybes,
    this.declined,
  });

  // Getter for backward compatibility
  DateTime get date => dateTime;

  /// Create from JSON (Go backend response)
  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? '',
      familyTreeId: json['familyTreeId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']) : DateTime.now(),
      location: json['location'],
      mapLink: json['mapLink'],
      createdBy: json['createdBy'] ?? '',
      attendees: List<String>.from(json['attendees'] ?? []),
      maybes: json['maybes'] != null ? List<String>.from(json['maybes']) : null,
      declined: json['declined'] != null ? List<String>.from(json['declined']) : null,
    );
  }

  /// Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyTreeId': familyTreeId,
      'title': title,
      'description': description,
      'dateTime': dateTime.toUtc().toIso8601String(),
      'location': location,
      'mapLink': mapLink,
      'createdBy': createdBy,
      'attendees': attendees,
      'maybes': maybes,
      'declined': declined,
    };
  }

  Appointment copyWith({
    String? id,
    String? familyTreeId,
    String? title,
    String? description,
    DateTime? dateTime,
    DateTime? date, // Alias for dateTime
    String? location,
    String? mapLink,
    String? createdBy,
    List<String>? attendees,
    List<String>? maybes,
    List<String>? declined,
  }) {
    return Appointment(
      id: id ?? this.id,
      familyTreeId: familyTreeId ?? this.familyTreeId,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? date ?? this.dateTime,
      location: location ?? this.location,
      mapLink: mapLink ?? this.mapLink,
      createdBy: createdBy ?? this.createdBy,
      attendees: attendees ?? this.attendees,
      maybes: maybes ?? this.maybes,
      declined: declined ?? this.declined,
    );
  }
}
