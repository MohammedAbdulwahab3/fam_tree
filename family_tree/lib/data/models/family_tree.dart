import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a family tree
class FamilyTree {
  final String id;
  final String name;
  final String ownerId;
  final List<String> collaboratorIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyTree({
    required this.id,
    required this.name,
    required this.ownerId,
    this.collaboratorIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyTree.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FamilyTree(
      id: doc.id,
      name: data['name'] ?? 'Untitled Tree',
      ownerId: data['ownerId'] ?? '',
      collaboratorIds: List<String>.from(data['collaborators'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'collaborators': collaboratorIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FamilyTree copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? collaboratorIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyTree(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
