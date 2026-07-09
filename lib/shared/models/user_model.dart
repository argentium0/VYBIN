import 'package:equatable/equatable.dart';

/// Type-safe, immutable data model representing a user profile in project **VYBIN**.
/// Implements all security, profile, and cryptographic fields as defined in Section 7.2 of the spec.
class UserModel extends Equatable {
  final String uid;
  final String username;
  final String displayName;
  final String email;
  final String? profilePhotoUrl;
  final String publicKey; // RSA public key in PEM format
  final String? fcmToken;
  final String onlineStatus; // 'online' | 'offline'
  final DateTime lastSeen;
  final String about;
  final DateTime createdAt;
  final List<String> blockedUids;
  final String? currentSessionId;

  const UserModel({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.email,
    this.profilePhotoUrl,
    required this.publicKey,
    this.fcmToken,
    required this.onlineStatus,
    required this.lastSeen,
    required this.about,
    required this.createdAt,
    required this.blockedUids,
    this.currentSessionId,
  });

  /// Factory constructor to create a [UserModel] from a JSON map (e.g. Firestore document).
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      publicKey: json['publicKey'] as String? ?? '',
      fcmToken: json['fcmToken'] as String?,
      onlineStatus: json['onlineStatus'] as String? ?? 'offline',
      lastSeen: _parseDateTime(json['lastSeen']),
      about: json['about'] as String? ?? 'Hey there! I am using VYBIN',
      createdAt: _parseDateTime(json['createdAt']),
      blockedUids: (json['blockedUids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      currentSessionId: json['currentSessionId'] as String?,
    );
  }

  /// Converts this [UserModel] instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'email': email,
      'profilePhotoUrl': profilePhotoUrl,
      'publicKey': publicKey,
      'fcmToken': fcmToken,
      'onlineStatus': onlineStatus,
      'lastSeen': lastSeen.toIso8601String(), // Serialize to ISO string for JSON compatibility
      'about': about,
      'createdAt': createdAt.toIso8601String(),
      'blockedUids': blockedUids,
      'currentSessionId': currentSessionId,
    };
  }

  /// Creates a copy of this [UserModel] but with the given fields replaced with new values.
  UserModel copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? email,
    String? Function()? profilePhotoUrl,
    String? publicKey,
    String? Function()? fcmToken,
    String? onlineStatus,
    DateTime? lastSeen,
    String? about,
    DateTime? createdAt,
    List<String>? blockedUids,
    String? Function()? currentSessionId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      profilePhotoUrl: profilePhotoUrl != null ? profilePhotoUrl() : this.profilePhotoUrl,
      publicKey: publicKey ?? this.publicKey,
      fcmToken: fcmToken != null ? fcmToken() : this.fcmToken,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      lastSeen: lastSeen ?? this.lastSeen,
      about: about ?? this.about,
      createdAt: createdAt ?? this.createdAt,
      blockedUids: blockedUids ?? this.blockedUids,
      currentSessionId: currentSessionId != null ? currentSessionId() : this.currentSessionId,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        username,
        displayName,
        email,
        profilePhotoUrl,
        publicKey,
        fcmToken,
        onlineStatus,
        lastSeen,
        about,
        createdAt,
        blockedUids,
        currentSessionId,
      ];

  /// Utility method to parse dynamic date fields from JSON/Firestore
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      return DateTime.parse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    // Handle Firestore Timestamp object (has toDate() method)
    try {
      return value.toDate();
    } catch (_) {
      try {
        return (value as dynamic).toDate();
      } catch (_) {
        return DateTime.now();
      }
    }
  }
}
