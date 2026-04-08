// ABOUTME: Model representing a NIP-51 kind 30000 user/people list.
// ABOUTME: Contains pubkeys and metadata for lists of people.

import 'package:equatable/equatable.dart';

/// Represents a user list (NIP-51 kind 30000) containing pubkeys.
class UserList extends Equatable {
  const UserList({
    required this.id,
    required this.name,
    required this.pubkeys,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.imageUrl,
    this.isPublic = true,
    this.nostrEventId,
    this.isEditable = true,
  });

  factory UserList.fromJson(Map<String, dynamic> json) => UserList(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    pubkeys: List<String>.from(json['pubkeys'] as Iterable? ?? []),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isPublic: json['isPublic'] as bool? ?? true,
    nostrEventId: json['nostrEventId'] as String?,
    isEditable: json['isEditable'] as bool? ?? true,
  );

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<String> pubkeys;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;
  final String? nostrEventId;

  /// Whether the list can be edited by the user.
  ///
  /// `false` for system lists like Divine Team.
  final bool isEditable;

  UserList copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<String>? pubkeys,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? nostrEventId,
    bool? isEditable,
  }) => UserList(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    pubkeys: pubkeys ?? this.pubkeys,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isPublic: isPublic ?? this.isPublic,
    nostrEventId: nostrEventId ?? this.nostrEventId,
    isEditable: isEditable ?? this.isEditable,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'pubkeys': pubkeys,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isPublic': isPublic,
    'nostrEventId': nostrEventId,
    'isEditable': isEditable,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    imageUrl,
    pubkeys,
    createdAt,
    updatedAt,
    isPublic,
    nostrEventId,
    isEditable,
  ];
}
