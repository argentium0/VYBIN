import 'package:equatable/equatable.dart';

/// Type-safe, immutable data model representing an encrypted message in project **VYBIN**.
/// Fully implements all specified cryptographic data fields and serialization mapping as defined in Section 7.5.
class MessageModel extends Equatable {
  final String messageId;
  final String senderUid;
  final DateTime timestamp;
  final String type; // 'text' | 'image' | 'voice' | 'document'
  
  // Cryptographic payloads (encrypted text/metadata)
  final String iv; // base64(12-byte GCM nonce)
  final String ciphertext; // base64(AES-256-GCM encrypted content)
  final Map<String, String> encryptedKeys; // Map of uid -> base64(RSA-OAEP encrypted AES key)
  
  // Status tracking
  final String status; // 'sent' | 'delivered' | 'read' | 'failed'
  final DateTime? deliveredAt;
  final DateTime? readAt;
  
  // Media payload fields (nullable, populated if type is 'image' | 'voice' | 'document')
  final String? mediaUrl; // Firebase Storage URL for encrypted media blob
  final String? mediaIv; // Separate IV for encrypted media file
  final Map<String, String>? mediaEncryptedKeys; // Map of uid -> base64(RSA-OAEP encrypted AES key for media)
  final int? mediaSize; // bytes
  final String? mediaMimeType;
  final String? mediaOriginalFilename; // Encrypted/plaintext original filename
  
  // Soft delete fields
  final List<String> deletedFor; // List of uids who deleted this message for themselves
  final bool deletedForEveryone;
  final DateTime? deletedForEveryoneAt;

  const MessageModel({
    required this.messageId,
    required this.senderUid,
    required this.timestamp,
    required this.type,
    required this.iv,
    required this.ciphertext,
    required this.encryptedKeys,
    required this.status,
    this.deliveredAt,
    this.readAt,
    this.mediaUrl,
    this.mediaIv,
    this.mediaEncryptedKeys,
    this.mediaSize,
    this.mediaMimeType,
    this.mediaOriginalFilename,
    required this.deletedFor,
    required this.deletedForEveryone,
    this.deletedForEveryoneAt,
  });

  /// Factory constructor to create a [MessageModel] from a JSON map (e.g. Firestore document).
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Parse encryptedKeys
    final keysMap = <String, String>{};
    if (json['encryptedKeys'] != null && json['encryptedKeys'] is Map) {
      (json['encryptedKeys'] as Map<dynamic, dynamic>).forEach((key, value) {
        keysMap[key.toString()] = value.toString();
      });
    }

    // Parse mediaEncryptedKeys if present
    Map<String, String>? mediaKeysMap;
    if (json['mediaEncryptedKeys'] != null && json['mediaEncryptedKeys'] is Map) {
      mediaKeysMap = <String, String>{};
      (json['mediaEncryptedKeys'] as Map<dynamic, dynamic>).forEach((key, value) {
        mediaKeysMap![key.toString()] = value.toString();
      });
    }

    return MessageModel(
      messageId: json['messageId'] as String? ?? '',
      senderUid: json['senderUid'] as String? ?? '',
      timestamp: _parseDateTime(json['timestamp']),
      type: json['type'] as String? ?? 'text',
      iv: json['iv'] as String? ?? '',
      ciphertext: json['ciphertext'] as String? ?? '',
      encryptedKeys: keysMap,
      status: json['status'] as String? ?? 'sent',
      deliveredAt: _parseNullableDateTime(json['deliveredAt']),
      readAt: _parseNullableDateTime(json['readAt']),
      mediaUrl: json['mediaUrl'] as String?,
      mediaIv: json['mediaIv'] as String?,
      mediaEncryptedKeys: mediaKeysMap,
      mediaSize: json['mediaSize'] as int?,
      mediaMimeType: json['mediaMimeType'] as String?,
      mediaOriginalFilename: json['mediaOriginalFilename'] as String?,
      deletedFor: (json['deletedFor'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      deletedForEveryone: json['deletedForEveryone'] as bool? ?? false,
      deletedForEveryoneAt: _parseNullableDateTime(json['deletedForEveryoneAt']),
    );
  }

  /// Converts this [MessageModel] instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderUid': senderUid,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'iv': iv,
      'ciphertext': ciphertext,
      'encryptedKeys': encryptedKeys,
      'status': status,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'mediaUrl': mediaUrl,
      'mediaIv': mediaIv,
      'mediaEncryptedKeys': mediaEncryptedKeys,
      'mediaSize': mediaSize,
      'mediaMimeType': mediaMimeType,
      'mediaOriginalFilename': mediaOriginalFilename,
      'deletedFor': deletedFor,
      'deletedForEveryone': deletedForEveryone,
      'deletedForEveryoneAt': deletedForEveryoneAt?.toIso8601String(),
    };
  }

  /// Creates a copy of this [MessageModel] but with the given fields replaced.
  MessageModel copyWith({
    String? messageId,
    String? senderUid,
    DateTime? timestamp,
    String? type,
    String? iv,
    String? ciphertext,
    Map<String, String>? encryptedKeys,
    String? status,
    DateTime? Function()? deliveredAt,
    DateTime? Function()? readAt,
    String? Function()? mediaUrl,
    String? Function()? mediaIv,
    Map<String, String>? Function()? mediaEncryptedKeys,
    int? Function()? mediaSize,
    String? Function()? mediaMimeType,
    String? Function()? mediaOriginalFilename,
    List<String>? deletedFor,
    bool? deletedForEveryone,
    DateTime? Function()? deletedForEveryoneAt,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderUid: senderUid ?? this.senderUid,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      iv: iv ?? this.iv,
      ciphertext: ciphertext ?? this.ciphertext,
      encryptedKeys: encryptedKeys ?? this.encryptedKeys,
      status: status ?? this.status,
      deliveredAt: deliveredAt != null ? deliveredAt() : this.deliveredAt,
      readAt: readAt != null ? readAt() : this.readAt,
      mediaUrl: mediaUrl != null ? mediaUrl() : this.mediaUrl,
      mediaIv: mediaIv != null ? mediaIv() : this.mediaIv,
      mediaEncryptedKeys: mediaEncryptedKeys != null ? mediaEncryptedKeys() : this.mediaEncryptedKeys,
      mediaSize: mediaSize != null ? mediaSize() : this.mediaSize,
      mediaMimeType: mediaMimeType != null ? mediaMimeType() : this.mediaMimeType,
      mediaOriginalFilename: mediaOriginalFilename != null ? mediaOriginalFilename() : this.mediaOriginalFilename,
      deletedFor: deletedFor ?? this.deletedFor,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      deletedForEveryoneAt: deletedForEveryoneAt != null ? deletedForEveryoneAt() : this.deletedForEveryoneAt,
    );
  }

  @override
  List<Object?> get props => [
        messageId,
        senderUid,
        timestamp,
        type,
        iv,
        ciphertext,
        encryptedKeys,
        status,
        deliveredAt,
        readAt,
        mediaUrl,
        mediaIv,
        mediaEncryptedKeys,
        mediaSize,
        mediaMimeType,
        mediaOriginalFilename,
        deletedFor,
        deletedForEveryone,
        deletedForEveryoneAt,
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

  /// Utility method to parse dynamic nullable date fields from JSON/Firestore.
  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
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
        return null;
      }
    }
  }
}
