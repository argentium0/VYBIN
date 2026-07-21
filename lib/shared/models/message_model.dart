import 'package:equatable/equatable.dart';

class MessageModel extends Equatable {
  final String messageId;
  final String senderUid;
  final DateTime timestamp;
  final String type;

  final String iv;
  final String ciphertext;
  final Map<String, String> encryptedKeys;

  final String? plaintext;

  final String status;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  final String? mediaUrl;
  final String? mediaIv;
  final Map<String, String>? mediaEncryptedKeys;
  final int? mediaSize;
  final String? mediaMimeType;
  final String? mediaOriginalFilename;
  final int? durationMs;

  final List<String> deletedFor;
  final bool deletedForEveryone;
  final DateTime? deletedForEveryoneAt;
  final bool isDeleted;
  final bool hasDecryptionError;

  const MessageModel({
    required this.messageId,
    required this.senderUid,
    required this.timestamp,
    required this.type,
    required this.iv,
    required this.ciphertext,
    required this.encryptedKeys,
    this.plaintext,
    required this.status,
    this.deliveredAt,
    this.readAt,
    this.mediaUrl,
    this.mediaIv,
    this.mediaEncryptedKeys,
    this.mediaSize,
    this.mediaMimeType,
    this.mediaOriginalFilename,
    this.durationMs,
    required this.deletedFor,
    required this.deletedForEveryone,
    this.deletedForEveryoneAt,
    this.isDeleted = false,
    this.hasDecryptionError = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final keysMap = <String, String>{};
    if (json['encryptedKeys'] != null && json['encryptedKeys'] is Map) {
      (json['encryptedKeys'] as Map<dynamic, dynamic>).forEach((key, value) {
        keysMap[key.toString()] = value.toString();
      });
    }

    Map<String, String>? mediaKeysMap;
    if (json['mediaEncryptedKeys'] != null &&
        json['mediaEncryptedKeys'] is Map) {
      mediaKeysMap = <String, String>{};
      (json['mediaEncryptedKeys'] as Map<dynamic, dynamic>).forEach((
        key,
        value,
      ) {
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
      durationMs: json['durationMs'] as int?,
      deletedFor:
          (json['deletedFor'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      deletedForEveryone: json['deletedForEveryone'] as bool? ?? false,
      deletedForEveryoneAt: _parseNullableDateTime(
        json['deletedForEveryoneAt'],
      ),
      isDeleted: json['isDeleted'] as bool? ?? false,
      hasDecryptionError: json['hasDecryptionError'] as bool? ?? false,
    );
  }

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
      'durationMs': durationMs,
      'deletedFor': deletedFor,
      'deletedForEveryone': deletedForEveryone,
      'deletedForEveryoneAt': deletedForEveryoneAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'hasDecryptionError': hasDecryptionError,
    };
  }

  MessageModel copyWith({
    String? messageId,
    String? senderUid,
    DateTime? timestamp,
    String? type,
    String? iv,
    String? ciphertext,
    Map<String, String>? encryptedKeys,
    String? Function()? plaintext,
    String? status,
    DateTime? Function()? deliveredAt,
    DateTime? Function()? readAt,
    String? Function()? mediaUrl,
    String? Function()? mediaIv,
    Map<String, String>? Function()? mediaEncryptedKeys,
    int? Function()? mediaSize,
    String? Function()? mediaMimeType,
    String? Function()? mediaOriginalFilename,
    int? Function()? durationMs,
    List<String>? deletedFor,
    bool? deletedForEveryone,
    DateTime? Function()? deletedForEveryoneAt,
    bool? isDeleted,
    bool? hasDecryptionError,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderUid: senderUid ?? this.senderUid,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      iv: iv ?? this.iv,
      ciphertext: ciphertext ?? this.ciphertext,
      encryptedKeys: encryptedKeys ?? this.encryptedKeys,
      plaintext: plaintext != null ? plaintext() : this.plaintext,
      status: status ?? this.status,
      deliveredAt: deliveredAt != null ? deliveredAt() : this.deliveredAt,
      readAt: readAt != null ? readAt() : this.readAt,
      mediaUrl: mediaUrl != null ? mediaUrl() : this.mediaUrl,
      mediaIv: mediaIv != null ? mediaIv() : this.mediaIv,
      mediaEncryptedKeys: mediaEncryptedKeys != null
          ? mediaEncryptedKeys()
          : this.mediaEncryptedKeys,
      mediaSize: mediaSize != null ? mediaSize() : this.mediaSize,
      mediaMimeType: mediaMimeType != null
          ? mediaMimeType()
          : this.mediaMimeType,
      mediaOriginalFilename: mediaOriginalFilename != null
          ? mediaOriginalFilename()
          : this.mediaOriginalFilename,
      durationMs: durationMs != null ? durationMs() : this.durationMs,
      deletedFor: deletedFor ?? this.deletedFor,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      deletedForEveryoneAt: deletedForEveryoneAt != null
          ? deletedForEveryoneAt()
          : this.deletedForEveryoneAt,
      isDeleted: isDeleted ?? this.isDeleted,
      hasDecryptionError: hasDecryptionError ?? this.hasDecryptionError,
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
    plaintext,
    status,
    deliveredAt,
    readAt,
    mediaUrl,
    mediaIv,
    mediaEncryptedKeys,
    mediaSize,
    mediaMimeType,
    mediaOriginalFilename,
    durationMs,
    deletedFor,
    deletedForEveryone,
    deletedForEveryoneAt,
    isDeleted,
    hasDecryptionError,
  ];

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
