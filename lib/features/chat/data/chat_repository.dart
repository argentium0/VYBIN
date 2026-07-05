import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:vybin/core/services/encryption_service.dart';
import 'package:vybin/core/services/media_service.dart';
import 'package:vybin/shared/models/conversation_model.dart';
import 'package:vybin/shared/models/message_model.dart';
import 'package:vybin/shared/models/user_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;
  final EncryptionService _encryptionService;
  final MediaService _mediaService;

  ChatRepository({
    FirebaseFirestore? firestore,
    EncryptionService? encryptionService,
    MediaService? mediaService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _encryptionService = encryptionService ?? EncryptionService(),
        _mediaService = mediaService ?? MediaService();

  /// Queries `usernames/{input}` for an exact match.
  /// If found, fetches and returns the `users/{uid}` document.
  Future<UserModel?> searchUserByUsername(String username) async {
    final sanitizedUsername = username.trim().toLowerCase();
    final doc = await _firestore.collection('usernames').doc(sanitizedUsername).get();
    if (!doc.exists) return null;

    final uid = doc.data()?['uid'] as String?;
    if (uid == null) return null;

    return getUserById(uid);
  }

  /// Fetches a user document by their UID.
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return UserModel.fromJson(data);
  }

  /// Deterministically generates a conversation ID from two UIDs.
  /// Sorts them alphabetically and joins them with an underscore.
  String generateConversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return sorted.join('_');
  }

  /// Creates a conversation document in `conversations/{conversationId}` if it doesn't exist.
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

  /// Real-time stream of conversations for the current user, ordered by `lastMessageAt` descending.
  Stream<List<ConversationModel>> getConversationsStream(String currentUid) {
    return _firestore
        .collection('conversations')
        .where('participantUids', arrayContains: currentUid)
        .snapshots()
        .map((snapshot) {
      final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.docs);
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
        return bTime.compareTo(aTime); // Descending (most recent first)
      });

      return docs.map((doc) {
        final data = doc.data();
        return ConversationModel.fromJson(data);
      }).toList();
    });
  }

  /// Sends a text message to a conversation.
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
      encryptedKeys: Map<String, String>.from(encryptedData['encryptedKeys'] as Map),
      status: 'sent',
      deletedFor: const [],
      deletedForEveryone: false,
    );

    final lastMessagePreview = LastMessagePreview(
      senderUid: senderUid,
      type: 'text',
      iv: encryptedData['iv'] as String,
      ciphertext: encryptedData['ciphertext'] as String,
      encryptedKeys: Map<String, String>.from(encryptedData['encryptedKeys'] as Map),
    );

    final batch = _firestore.batch();
    batch.set(messageDoc, message.toJson());

    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    batch.update(conversationRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': lastMessagePreview.toJson(),
      'unreadCount.$recipientUid': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Sends a media message (image/voice/document) to a conversation after encrypting it.
  Future<void> sendMediaMessage({
    required String conversationId,
    required String senderUid,
    required String recipientUid,
    required String type, // 'image' | 'voice' | 'document'
    required String localFilePath,
    required String senderPubKeyPEM,
    required String recipientPubKeyPEM,
  }) async {
    // 1. Get bytes from MediaService
    final mediaBytes = await _mediaService.getMediaBytes(localFilePath);

    // 2. Encrypt the raw bytes and generate AES key and RSA-OAEP encrypted keys
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
    final encryptedKeys = Map<String, String>.from(encryptionData['encryptedKeys'] as Map);

    // 3. Generate message doc and ID
    final messagesRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');
    final messageDoc = messagesRef.doc();
    final messageId = messageDoc.id;

    final filename = localFilePath.split('/').last.split('\\').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Write the ciphertext to a temporary file locally
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${timestamp}_$filename.enc');
    await tempFile.writeAsBytes(encryptedBytes);

    // 4. Upload the ENCRYPTED temporary file to Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('chats')
        .child(conversationId)
        .child('media')
        .child('${timestamp}_$filename.enc');

    final uploadTask = await storageRef.putFile(tempFile);
    final mediaUrl = await uploadTask.ref.getDownloadURL();

    // Clean up local temporary encrypted file
    try {
      await tempFile.delete();
    } catch (_) {}

    // 5. Encrypt placeholder text so decryption in stream does not fail
    String placeholderText;
    if (type == 'image') {
      placeholderText = 'Sent an image 📷';
    } else if (type == 'voice') {
      placeholderText = 'Sent a voice message 🎤';
    } else {
      placeholderText = 'Sent a document 📎';
    }

    final textEncryptionData = _encryptionService.encryptPlaintextWithKey(
      plaintext: placeholderText,
      aesKey: aesKey,
    );

    final textCiphertext = textEncryptionData['ciphertext'] as String;
    final textIv = textEncryptionData['iv'] as String;

    // 6. Save the message to Firestore
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
      mediaMimeType: type == 'image' ? 'image/jpeg' : (type == 'voice' ? 'audio/aac' : 'application/octet-stream'),
      mediaOriginalFilename: filename,
      deletedFor: const [],
      deletedForEveryone: false,
    );

    final lastMessagePreview = LastMessagePreview(
      senderUid: senderUid,
      type: type,
      iv: textIv,
      ciphertext: textCiphertext,
      encryptedKeys: encryptedKeys,
    );

    final batch = _firestore.batch();
    // Save MessageModel to json, ensuring both type and messageType are stored
    final messageJson = message.toJson();
    messageJson['messageType'] = type;

    batch.set(messageDoc, messageJson);

    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    batch.update(conversationRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': lastMessagePreview.toJson(),
      'unreadCount.$recipientUid': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Decrypts a message ciphertext using the shared/injected encryption service.
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

  /// Decrypts encrypted media bytes using the shared/injected encryption service.
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

  /// Real-time stream of messages in a conversation, decrypted on the fly and filtered by blocked users.
  Stream<List<MessageModel>> getMessagesStream(String conversationId, String myUid) {
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
        .listen((snapshot) {
      blockedUids = snapshot.docs.map((doc) => doc.id).toList();
      emitFiltered();
    }, onError: (err) {
      if (!controller.isClosed) controller.addError(err);
    });

    messagesSub = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .snapshots()
        .listen((snapshot) {
      final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.docs);
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
        return bTime.compareTo(aTime); // Descending (most recent first)
      });

      currentMessages = docs.map((doc) {
        final data = doc.data();
        var msg = MessageModel.fromJson(data);

        if (msg.deletedForEveryone || data['isDeleted'] == true) {
          msg = msg.copyWith(plaintext: () => '🚫 This message was deleted.');
        } else {
          try {
            final plaintext = _encryptionService.decryptMessage(
              ciphertextBase64: msg.ciphertext,
              ivBase64: msg.iv,
              encryptedSessionKeyBase64: msg.encryptedKeys[myUid] ?? '',
            );
            msg = msg.copyWith(plaintext: () => plaintext);
          } catch (e) {
            msg = msg.copyWith(plaintext: () => 'Error decrypting message');
          }
        }

        return msg;
      }).toList();
      emitFiltered();
    }, onError: (err) {
      if (!controller.isClosed) controller.addError(err);
    });

    controller.onCancel = () {
      blockedSub?.cancel();
      messagesSub?.cancel();
    };

    return controller.stream;
  }

  /// Real-time stream of a user's profile from Firestore, hiding presence details if they are blocked.
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
          controller.add(currentUser!.copyWith(
            onlineStatus: 'offline',
            lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
          ));
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
        .listen((snapshot) {
      isBlocked = snapshot.exists;
      emitFiltered();
    }, onError: (err) {
      if (!controller.isClosed) controller.addError(err);
    });

    userSub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        currentUser = UserModel.fromJson(snapshot.data()!);
      } else {
        currentUser = null;
      }
      emitFiltered();
    }, onError: (err) {
      if (!controller.isClosed) controller.addError(err);
    });

    controller.onCancel = () {
      userSub?.cancel();
      blockedSub?.cancel();
    };

    return controller.stream;
  }

  /// Updates a message's status to 'read' (or 'delivered') in Firestore.
  Future<void> updateMessageStatus({
    required String conversationId,
    required String messageId,
    required String status,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status,
    };
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
  }

  /// Marks all unread incoming messages in a conversation as read.
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
      
      // Also update the unread count in conversation document to 0 for current user
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount.$myUid': 0,
      });
    }
  }

  /// Blocks a user by creating a document in users/{myUid}/blocked_users/{otherUid}.
  Future<void> blockUser(String myUid, String otherUid) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('blocked_users')
        .doc(otherUid)
        .set({
      'blockedAt': FieldValue.serverTimestamp(),
    });

    // Optional: Add to recipient's blocked list for symmetry or handle unidirectionally
  }

  /// Voluntarily reports a conversation using E2EE blind metadata (only handshakes and comments).
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

  /// Soft deletes a message for the current user locally.
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

  /// Soft deletes a message for everyone.
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
}
