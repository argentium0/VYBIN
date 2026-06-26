class Message {
  final String messageId;
  final String senderUid;
  final DateTime timestamp;
  final String type; // 'text' | 'image' | 'voice' | 'document'

  final String? iv;
  final String? ciphertext;
  final Map<String, String>? encryptedKeys;

  // Transient field for local MVP before full encryption pipeline is built
  final String? plaintext;

  final String status; // 'sent' | 'delivered' | 'read' | 'failed'
  final DateTime? deliveredAt;
  final DateTime? readAt;

  final String? mediaUrl;
  final String? mediaIv;
  final Map<String, String>? mediaEncryptedKeys;
  final int? mediaSize;
  final String? mediaMimeType;
  final String? mediaOriginalFilename;

  final List<String> deletedFor;
  final bool deletedForEveryone;
  final DateTime? deletedForEveryoneAt;

  const Message({
    required this.messageId,
    required this.senderUid,
    required this.timestamp,
    required this.type,
    this.iv,
    this.ciphertext,
    this.encryptedKeys,
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
    this.deletedFor = const [],
    this.deletedForEveryone = false,
    this.deletedForEveryoneAt,
  });

  Message copyWith({
    String? messageId,
    String? senderUid,
    DateTime? timestamp,
    String? type,
    String? iv,
    String? ciphertext,
    Map<String, String>? encryptedKeys,
    String? plaintext,
    String? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? mediaUrl,
    String? mediaIv,
    Map<String, String>? mediaEncryptedKeys,
    int? mediaSize,
    String? mediaMimeType,
    String? mediaOriginalFilename,
    List<String>? deletedFor,
    bool? deletedForEveryone,
    DateTime? deletedForEveryoneAt,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      senderUid: senderUid ?? this.senderUid,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      iv: iv ?? this.iv,
      ciphertext: ciphertext ?? this.ciphertext,
      encryptedKeys: encryptedKeys ?? this.encryptedKeys,
      plaintext: plaintext ?? this.plaintext,
      status: status ?? this.status,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaIv: mediaIv ?? this.mediaIv,
      mediaEncryptedKeys: mediaEncryptedKeys ?? this.mediaEncryptedKeys,
      mediaSize: mediaSize ?? this.mediaSize,
      mediaMimeType: mediaMimeType ?? this.mediaMimeType,
      mediaOriginalFilename: mediaOriginalFilename ?? this.mediaOriginalFilename,
      deletedFor: deletedFor ?? this.deletedFor,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      deletedForEveryoneAt: deletedForEveryoneAt ?? this.deletedForEveryoneAt,
    );
  }

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      messageId: id,
      senderUid: map['senderUid'] as String,
      timestamp: _parseDateTime(map['timestamp']),
      type: map['type'] as String,
      iv: map['iv'] as String?,
      ciphertext: map['ciphertext'] as String?,
      encryptedKeys: (map['encryptedKeys'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as String),
      ),
      plaintext: map['plaintext'] as String?,
      status: map['status'] as String,
      deliveredAt: map['deliveredAt'] != null ? _parseDateTime(map['deliveredAt']) : null,
      readAt: map['readAt'] != null ? _parseDateTime(map['readAt']) : null,
      mediaUrl: map['mediaUrl'] as String?,
      mediaIv: map['mediaIv'] as String?,
      mediaEncryptedKeys: (map['mediaEncryptedKeys'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as String),
      ),
      mediaSize: map['mediaSize'] as int?,
      mediaMimeType: map['mediaMimeType'] as String?,
      mediaOriginalFilename: map['mediaOriginalFilename'] as String?,
      deletedFor: List<String>.from(map['deletedFor'] ?? []),
      deletedForEveryone: map['deletedForEveryone'] as bool? ?? false,
      deletedForEveryoneAt: map['deletedForEveryoneAt'] != null 
          ? _parseDateTime(map['deletedForEveryoneAt']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
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

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      return (value as dynamic).toDate();
    } catch (_) {
      return DateTime.now();
    }
  }
}
