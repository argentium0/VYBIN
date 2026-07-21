import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:vybin/core/services/encryption_service.dart';
import 'package:vybin/core/services/media_service.dart';
import 'package:vybin/shared/models/conversation_model.dart';
import 'package:vybin/shared/models/message_model.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:vybin/core/services/zego_signaling_extension.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;
  final EncryptionService _encryptionService;
  final MediaService _mediaService;

  ChatRepository({
    FirebaseFirestore? firestore,
    EncryptionService? encryptionService,
    MediaService? mediaService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _encryptionService = encryptionService ?? EncryptionService(),
       _mediaService = mediaService ?? MediaService();

  Future<UserModel?> searchUserByUsername(String username) async {
    final sanitizedUsername = username.trim().toLowerCase();
    final doc = await _firestore
        .collection('usernames')
        .doc(sanitizedUsername)
        .get();
    if (!doc.exists) return null;

    final uid = doc.data()?['uid'] as String?;
    if (uid == null) return null;

    return getUserById(uid);
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return UserModel.fromJson(data);
  }

  String generateConversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return sorted.join('_');
  }

  Future<void> createConversation({
    required String conversationId,
    required List<String> participantUids,
  }) async {
    final docRef = _firestore.collection('conversations').doc(conversationId);
    final doc = await docRef.get();

    if (!doc.exists) {
      final unreadMap = <String, int>{};
      for (final uid in participantUids) {
        unreadMap[uid] = 0;
      }

      await docRef.set({
        'conversationId': conversationId,
        'participantUids': participantUids,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': unreadMap,
        'mutedBy': const <String>[],
        'deletedBy': const <String>[],
        'lastMessagePreview': null,
      });
    }
  }

  Stream<List<ConversationModel>> getConversationsStream(String currentUid) {
    return _firestore
        .collection('conversations')
        .where('participantUids', arrayContains: currentUid)
        .snapshots()
        .map((snapshot) {
          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snapshot.docs,
          );
          final now = DateTime.now();

          DateTime parseTimestamp(dynamic val) {
            if (val == null) return now;
            if (val is Timestamp) return val.toDate();
            if (val is String) return DateTime.tryParse(val) ?? now;
            if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
            return now;
          }

          docs.sort((a, b) {
            final aTime = parseTimestamp(a.data()['lastMessageAt']);
            final bTime = parseTimestamp(b.data()['lastMessageAt']);
            return bTime.compareTo(aTime);
          });

          return docs.map((doc) {
            final data = doc.data();
            return ConversationModel.fromJson(data);
          }).toList();
        });
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderUid,
    required String recipientUid,
    required String plaintext,
    required String senderPubKeyPEM,
    required String recipientPubKeyPEM,
  }) async {
    final encryptedData = _encryptionService.encryptMessage(
      plaintext: plaintext,
      recipientUid: recipientUid,
      recipientPubKeyPEM: recipientPubKeyPEM,
      senderUid: senderUid,
      senderPubKeyPEM: senderPubKeyPEM,
    );

    final messagesRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');

    final messageDoc = messagesRef.doc();
    final messageId = messageDoc.id;

    final now = DateTime.now();

    final message = MessageModel(
      messageId: messageId,
      senderUid: senderUid,
      timestamp: now,
      type: 'text',
      iv: encryptedData['iv'] as String,
      ciphertext: encryptedData['ciphertext'] as String,
      encryptedKeys: Map<String, String>.from(
        encryptedData['encryptedKeys'] as Map,
      ),
      status: 'sent',
      deletedFor: const [],
      deletedForEveryone: false,
    );

    final lastMessagePreview = LastMessagePreview(
      senderUid: senderUid,
      type: 'text',
      iv: encryptedData['iv'] as String,
      ciphertext: encryptedData['ciphertext'] as String,
      encryptedKeys: Map<String, String>.from(
        encryptedData['encryptedKeys'] as Map,
      ),
      status: 'sent',
    );

    final batch = _firestore.batch();
    batch.set(messageDoc, message.toJson());

    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    batch.update(conversationRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': lastMessagePreview.toJson(),
      'unreadCount.$recipientUid': FieldValue.increment(1),
    });

    await batch.commit();

    try {
      await ZegoUIKitSignalingPlugin().sendCustomCommand(
        inviterID: senderUid,
        inviteeIDs: [recipientUid],
        customCommand: '{"type": "new_text"}',
      );
    } catch (_) {}
  }

  Future<void> sendMediaMessage({
    required String conversationId,
    required String senderUid,
    required String recipientUid,
    required String type,
    required String localFilePath,
    required String senderPubKeyPEM,
    required String recipientPubKeyPEM,
    int? durationMs,
  }) async {
    final mediaBytes = await _mediaService.getMediaBytes(localFilePath);

    final encryptionData = _encryptionService.encryptMediaBytes(
      rawBytes: mediaBytes,
      recipientUid: recipientUid,
      recipientPubKeyPEM: recipientPubKeyPEM,
      senderUid: senderUid,
      senderPubKeyPEM: senderPubKeyPEM,
    );

    final encryptedBytes = encryptionData['encryptedBytes'] as Uint8List;
    final mediaIv = encryptionData['iv'] as String;
    final aesKey = encryptionData['aesKey'] as Uint8List;
    final encryptedKeys = Map<String, String>.from(
      encryptionData['encryptedKeys'] as Map,
    );

    final messagesRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');
    final messageDoc = messagesRef.doc();
    final messageId = messageDoc.id;

    final filename = localFilePath.split('/').last.split('\\').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${timestamp}_$filename.enc');
    await tempFile.writeAsBytes(encryptedBytes);

    final String? mediaUrl = await _mediaService.uploadToCloudinary(tempFile);
    if (mediaUrl == null) {
      throw Exception('Failed to upload media to Cloudinary');
    }

    try {
      await tempFile.delete();
    } catch (_) {}

    String placeholderText;
    if (type == 'image') {
      placeholderText = 'Sent an image 📷';
    } else if (type == 'voice') {
      placeholderText = 'Sent a voice message 🎤';
    } else if (type == 'video') {
      placeholderText = 'Sent a video 🎥';
    } else {
      placeholderText = 'Sent a document 📎';
    }

    final textEncryptionData = _encryptionService.encryptPlaintextWithKey(
      plaintext: placeholderText,
      aesKey: aesKey,
    );

    final textCiphertext = textEncryptionData['ciphertext'] as String;
    final textIv = textEncryptionData['iv'] as String;

    final now = DateTime.now();
    final message = MessageModel(
      messageId: messageId,
      senderUid: senderUid,
      timestamp: now,
      type: type,
      iv: textIv,
      ciphertext: textCiphertext,
      encryptedKeys: encryptedKeys,
      status: 'sent',
      mediaUrl: mediaUrl,
      mediaIv: mediaIv,
      mediaEncryptedKeys: encryptedKeys,
      mediaSize: mediaBytes.length,
      mediaMimeType: type == 'image'
          ? 'image/jpeg'
          : (type == 'voice'
                ? 'audio/aac'
                : (type == 'video' ? 'video/mp4' : 'application/octet-stream')),
      mediaOriginalFilename: filename,
      durationMs: durationMs,
      deletedFor: const [],
      deletedForEveryone: false,
    );

    final lastMessagePreview = LastMessagePreview(
      senderUid: senderUid,
      type: type,
      iv: textIv,
      ciphertext: textCiphertext,
      encryptedKeys: encryptedKeys,
      status: 'sent',
    );

    final batch = _firestore.batch();

    final messageJson = message.toJson();
    messageJson['messageType'] = type;

    batch.set(messageDoc, messageJson);

    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    batch.update(conversationRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': lastMessagePreview.toJson(),
      'unreadCount.$recipientUid': FieldValue.increment(1),
    });

    await batch.commit();
  }

  String decryptMessage({
    required String ciphertext,
    required String iv,
    required String encryptedKey,
  }) {
    return _encryptionService.decryptMessage(
      ciphertextBase64: ciphertext,
      ivBase64: iv,
      encryptedSessionKeyBase64: encryptedKey,
    );
  }

  Uint8List decryptMediaBytes({
    required Uint8List encryptedBytes,
    required String iv,
    required String encryptedKey,
  }) {
    return _encryptionService.decryptMediaBytes(
      encryptedBytes: encryptedBytes,
      ivBase64: iv,
      encryptedSessionKeyBase64: encryptedKey,
    );
  }

  Stream<List<MessageModel>> getMessagesStream(
    String conversationId,
    String myUid,
  ) {
    final controller = StreamController<List<MessageModel>>();
    List<String> blockedUids = [];
    List<MessageModel> currentMessages = [];

    StreamSubscription? blockedSub;
    StreamSubscription? messagesSub;

    void emitFiltered() {
      if (controller.isClosed) return;
      final filtered = currentMessages.where((msg) {
        if (blockedUids.contains(msg.senderUid)) return false;
        if (msg.deletedFor.contains(myUid)) return false;
        return true;
      }).toList();
      controller.add(filtered);
    }

    blockedSub = _firestore
        .collection('users')
        .doc(myUid)
        .collection('blocked_users')
        .snapshots()
        .listen(
          (snapshot) {
            blockedUids = snapshot.docs.map((doc) => doc.id).toList();
            emitFiltered();
          },
          onError: (err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );

    messagesSub = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .snapshots()
        .listen(
          (snapshot) {
            final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              snapshot.docs,
            );
            final now = DateTime.now();

            DateTime parseTimestamp(dynamic val) {
              if (val == null) return now;
              if (val is Timestamp) return val.toDate();
              if (val is String) return DateTime.tryParse(val) ?? now;
              if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
              return now;
            }

            docs.sort((a, b) {
              final aTime = parseTimestamp(a.data()['timestamp']);
              final bTime = parseTimestamp(b.data()['timestamp']);
              return bTime.compareTo(aTime);
            });

            currentMessages = docs.map((doc) {
              final data = doc.data();
              var msg = MessageModel.fromJson(data);

              if (msg.type == 'call_log') {
                msg = msg.copyWith(
                  plaintext: () => null,
                  hasDecryptionError: false,
                );
              } else if (msg.deletedForEveryone ||
                  msg.isDeleted ||
                  data['isDeleted'] == true) {
                msg = msg.copyWith(
                  plaintext: () => '🚫 This message was deleted.',
                  isDeleted: true,
                );
              } else {
                try {
                  final plaintext = _encryptionService.decryptMessage(
                    ciphertextBase64: msg.ciphertext,
                    ivBase64: msg.iv,
                    encryptedSessionKeyBase64: msg.encryptedKeys[myUid] ?? '',
                  );
                  msg = msg.copyWith(
                    plaintext: () => plaintext,
                    hasDecryptionError: plaintext == '[DECRYPTION_FAILED]',
                  );
                } catch (e) {
                  msg = msg.copyWith(
                    plaintext: () => 'Error decrypting message',
                    hasDecryptionError: true,
                  );
                }
              }

              return msg;
            }).toList();
            emitFiltered();
          },
          onError: (err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );

    controller.onCancel = () {
      blockedSub?.cancel();
      messagesSub?.cancel();
    };

    return controller.stream;
  }

  Stream<UserModel?> getUserStream(String uid, String myUid) {
    final controller = StreamController<UserModel?>();
    UserModel? currentUser;
    bool isBlocked = false;

    StreamSubscription? userSub;
    StreamSubscription? blockedSub;

    void emitFiltered() {
      if (controller.isClosed) return;
      if (isBlocked) {
        if (currentUser != null) {
          controller.add(
            currentUser!.copyWith(
              onlineStatus: 'offline',
              isOnline: false,
              lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          );
        } else {
          controller.add(null);
        }
      } else {
        controller.add(currentUser);
      }
    }

    blockedSub = _firestore
        .collection('users')
        .doc(myUid)
        .collection('blocked_users')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) {
            isBlocked = snapshot.exists;
            emitFiltered();
          },
          onError: (err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );

    userSub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              currentUser = UserModel.fromJson(snapshot.data()!);
            } else {
              currentUser = null;
            }
            emitFiltered();
          },
          onError: (err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );

    controller.onCancel = () {
      userSub?.cancel();
      blockedSub?.cancel();
    };

    return controller.stream;
  }

  Future<void> updateMessageStatus({
    required String conversationId,
    required String messageId,
    required String status,
  }) async {
    final Map<String, dynamic> updates = {'status': status};
    if (status == 'read') {
      updates['readAt'] = FieldValue.serverTimestamp();
    } else if (status == 'delivered') {
      updates['deliveredAt'] = FieldValue.serverTimestamp();
    }

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update(updates);

    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessagePreview.status': status,
    });
  }

  Future<void> markMessagesAsRead({
    required String conversationId,
    required String myUid,
  }) async {
    final query = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('status', whereIn: const ['sent', 'delivered'])
        .get();

    final batch = _firestore.batch();
    var hasUpdates = false;

    for (final doc in query.docs) {
      if (doc.data()['senderUid'] != myUid) {
        batch.update(doc.reference, {
          'status': 'read',
          'readAt': FieldValue.serverTimestamp(),
        });
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit();

      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount.$myUid': 0,
        'lastMessagePreview.status': 'read',
      });
    }
  }

  Future<void> blockUser(String myUid, String otherUid) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('blocked_users')
        .doc(otherUid)
        .set({'blockedAt': FieldValue.serverTimestamp()});
  }

  Future<void> reportConversation({
    required String conversationId,
    required String reporterUid,
    required String reportedUid,
    required String reason,
  }) async {
    await _firestore.collection('reports').add({
      'conversationId': conversationId,
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'metadata_only',
    });
  }

  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String myUid,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
          'deletedFor': FieldValue.arrayUnion([myUid]),
        });
  }

  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
          'deletedForEveryone': true,
          'isDeleted': true,
          'ciphertext': '',
          'mediaUrl': FieldValue.delete(),
          'deletedForEveryoneAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> logCall({
    required String callId,
    required String callerId,
    required String receiverId,
    required String status,
  }) async {
    final conversationId = generateConversationId(callerId, receiverId);

    await createConversation(
      conversationId: conversationId,
      participantUids: [callerId, receiverId],
    );

    final messagesRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');

    final messageDoc = messagesRef.doc(callId);

    final callLogDoc = {
      'messageId': callId,
      'senderUid': callerId,
      'callerId': callerId,
      'receiverId': receiverId,
      'type': 'call_log',
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
      'iv': '',
      'ciphertext': status,
      'encryptedKeys': <String, String>{},
      'deletedFor': <String>[],
      'deletedForEveryone': false,
    };

    final batch = _firestore.batch();
    batch.set(messageDoc, callLogDoc, SetOptions(merge: true));

    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    final updateData = <String, dynamic>{
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': {
        'senderUid': callerId,
        'type': 'call_log',
        'iv': '',
        'ciphertext': status,
        'encryptedKeys': <String, String>{},
        'status': status,
      },
    };
    if (status == 'missed') {
      updateData['unreadCount.$receiverId'] = FieldValue.increment(1);
    }
    batch.update(conversationRef, updateData);

    final callLogRef = _firestore.collection('call_logs').doc(callId);
    batch.set(callLogRef, {
      'type': 'call_log',
      'status': status,
      'callerId': callerId,
      'receiverId': receiverId,
      'timestamp': FieldValue.serverTimestamp(),
      'participantUids': [callerId, receiverId],
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
