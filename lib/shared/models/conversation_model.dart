import 'package:equatable/equatable.dart';

/// Class representing the encrypted last message preview in a conversation.
class LastMessagePreview extends Equatable {
  final String senderUid;
  final String type; // 'text' | 'image' | 'voice' | 'document'
  final String iv; // base64
  final String ciphertext; // base64 encrypted text or preview placeholder
  final Map<String, String> encryptedKeys; // Map of uid -> base64 encrypted AES key
  final String status; // 'sent' | 'delivered' | 'read'

  const LastMessagePreview({
    required this.senderUid,
    required this.type,
    required this.iv,
    required this.ciphertext,
    required this.encryptedKeys,
    required this.status,
  });

  factory LastMessagePreview.fromJson(Map<String, dynamic> json) {
    final keysMap = <String, String>{};
    if (json['encryptedKeys'] != null && json['encryptedKeys'] is Map) {
      (json['encryptedKeys'] as Map<dynamic, dynamic>).forEach((key, value) {
        keysMap[key.toString()] = value.toString();
      });
    }

    return LastMessagePreview(
      senderUid: json['senderUid'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      iv: json['iv'] as String? ?? '',
      ciphertext: json['ciphertext'] as String? ?? '',
      encryptedKeys: keysMap,
      status: json['status'] as String? ?? 'sent',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderUid': senderUid,
      'type': type,
      'iv': iv,
      'ciphertext': ciphertext,
      'encryptedKeys': encryptedKeys,
      'status': status,
    };
  }

  LastMessagePreview copyWith({
    String? senderUid,
    String? type,
    String? iv,
    String? ciphertext,
    Map<String, String>? encryptedKeys,
    String? status,
  }) {
    return LastMessagePreview(
      senderUid: senderUid ?? this.senderUid,
      type: type ?? this.type,
      iv: iv ?? this.iv,
      ciphertext: ciphertext ?? this.ciphertext,
      encryptedKeys: encryptedKeys ?? this.encryptedKeys,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [senderUid, type, iv, ciphertext, encryptedKeys, status];
}

/// Type-safe, immutable data model representing a chat conversation in project **VYBIN**.
/// Fully implements the deterministic conversation indexing and state tracking defined in Section 7.4.
class ConversationModel extends Equatable {
  final String conversationId;
  final List<String> participantUids;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final LastMessagePreview? lastMessagePreview;
  final Map<String, int> unreadCount; // Map of uid -> unread count
  final List<String> mutedBy; // List of uids who muted this conversation
  final List<String> deletedBy; // List of uids who deleted this conversation

  const ConversationModel({
    required this.conversationId,
    required this.participantUids,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessagePreview,
    required this.unreadCount,
    required this.mutedBy,
    required this.deletedBy,
  });

  /// Factory constructor to create a [ConversationModel] from a JSON map (e.g. Firestore document).
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final countsMap = <String, int>{};
    if (json['unreadCount'] != null && json['unreadCount'] is Map) {
      (json['unreadCount'] as Map<dynamic, dynamic>).forEach((key, value) {
        countsMap[key.toString()] = (value as num).toInt();
      });
    }

    final previewJson = json['lastMessagePreview'];
    final preview = previewJson != null && previewJson is Map<String, dynamic>
        ? LastMessagePreview.fromJson(previewJson)
        : null;

    return ConversationModel(
      conversationId: json['conversationId'] as String? ?? '',
      participantUids: (json['participantUids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: _parseDateTime(json['createdAt']),
      lastMessageAt: _parseDateTime(json['lastMessageAt']),
      lastMessagePreview: preview,
      unreadCount: countsMap,
      mutedBy: (json['mutedBy'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      deletedBy: (json['deletedBy'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  /// Converts this [ConversationModel] instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'participantUids': participantUids,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'lastMessagePreview': lastMessagePreview?.toJson(),
      'unreadCount': unreadCount,
      'mutedBy': mutedBy,
      'deletedBy': deletedBy,
    };
  }

  /// Creates a copy of this [ConversationModel] but with the given fields replaced.
  ConversationModel copyWith({
    String? conversationId,
    List<String>? participantUids,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    LastMessagePreview? Function()? lastMessagePreview,
    Map<String, int>? unreadCount,
    List<String>? mutedBy,
    List<String>? deletedBy,
  }) {
    return ConversationModel(
      conversationId: conversationId ?? this.conversationId,
      participantUids: participantUids ?? this.participantUids,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview != null ? lastMessagePreview() : this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      mutedBy: mutedBy ?? this.mutedBy,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }

  @override
  List<Object?> get props => [
        conversationId,
        participantUids,
        createdAt,
        lastMessageAt,
        lastMessagePreview,
        unreadCount,
        mutedBy,
        deletedBy,
      ];

  /// Utility method to parse dynamic date fields from JSON/Firestore.
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      return DateTime.parse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
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
