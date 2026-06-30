import 'dart:typed_data';
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
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
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

  /// Sends a media message (image/voice) to a conversation after encrypting it.
  Future<void> sendMediaMessage({
    required String conversationId,
    required String senderUid,
    required String recipientUid,
    required String type, // 'image' | 'voice'
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

    // 4. Upload the ENCRYPTED bytes to Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('media')
        .child(conversationId)
        .child('$messageId.enc');

    final uploadTask = await storageRef.putData(
      encryptedBytes,
      SettableMetadata(contentType: 'application/octet-stream'),
    );
    final mediaUrl = await uploadTask.ref.getDownloadURL();

    // 5. Encrypt placeholder text so decryption in stream does not fail
    final placeholderText = type == 'image' ? 'Sent an image 📷' : 'Sent a voice message 🎤';
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
    batch.set(messageDoc, message.toJson());

    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    batch.update(conversationRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': lastMessagePreview.toJson(),
      'unreadCount.$recipientUid': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Real-time stream of messages in a conversation, decrypted on the fly.
  Stream<List<MessageModel>> getMessagesStream(String conversationId, String myUid) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        var msg = MessageModel.fromJson(data);
        
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
        
        return msg;
      }).toList();
    });
  }
}
