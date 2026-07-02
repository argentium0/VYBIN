import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
    );
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'vybin_chats',
      'VYBIN Secure Chats',
      channelDescription: 'Notifications for secure E2EE chat messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  static Future<void> decryptAndShowLocalNotification(RemoteMessage message) async {
    final senderUid = message.data['sender_uid'] as String?;
    final messageId = message.data['message_id'] as String?;
    if (senderUid == null || messageId == null) return;

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final sorted = [senderUid, myUid]..sort();
    final conversationId = sorted.join('_');

    const secureStorage = FlutterSecureStorage();
    final rawJson = await secureStorage.read(key: 'vybin_raw_private_key');
    if (rawJson == null) {
      await showAnonymizedNotification(senderUid);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!doc.exists) {
        await showAnonymizedNotification(senderUid);
        return;
      }

      final data = doc.data();
      if (data == null) {
        await showAnonymizedNotification(senderUid);
        return;
      }

      // Update message status to 'delivered' if currently 'sent'
      if (data['status'] == 'sent') {
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(messageId)
            .update({
          'status': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
        });
      }

      final encryptedKeys = Map<String, String>.from(data['encryptedKeys'] as Map? ?? {});
      final encryptedSessionKeyBase64 = encryptedKeys[myUid];
      final ivBase64 = data['iv'] as String?;
      final ciphertextBase64 = data['ciphertext'] as String?;

      if (encryptedSessionKeyBase64 == null || ivBase64 == null || ciphertextBase64 == null) {
        await showAnonymizedNotification(senderUid);
        return;
      }

      // Deserialize private key
      final Map<String, dynamic> keyData = jsonDecode(rawJson);
      final rawPrivateKey = RSAPrivateKey(
        BigInt.parse(keyData['n']!, radix: 16),
        BigInt.parse(keyData['d']!, radix: 16),
        BigInt.parse(keyData['p']!, radix: 16),
        BigInt.parse(keyData['q']!, radix: 16),
      );

      // Decrypt session key using RSA-OAEP with SHA-256
      final oaep = OAEPEncoding.withSHA256(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(rawPrivateKey));
      final aesKey = oaep.process(base64Decode(encryptedSessionKeyBase64));

      // Decrypt message ciphertext using AES-GCM
      final iv = base64Decode(ivBase64);
      final ciphertextBytes = base64Decode(ciphertextBase64);
      final cipher = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(aesKey), 128, iv, Uint8List(0)));
      final plaintextBytes = cipher.process(ciphertextBytes);
      final plaintext = utf8.decode(plaintextBytes);

      // Fetch contact name from local cache
      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('contact_$senderUid');

      final title = cachedName ?? 'New Message';
      await showNotification(
        id: messageId.hashCode,
        title: title,
        body: plaintext,
      );
    } catch (e) {
      debugPrint('Local notification decryption failed: $e');
      await showAnonymizedNotification(senderUid);
    }
  }

  static Future<void> showAnonymizedNotification(String senderUid) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedName = prefs.getString('contact_$senderUid');
    final title = cachedName ?? 'New Message';
    await showNotification(
      id: senderUid.hashCode,
      title: title,
      body: 'New encrypted message received',
    );
  }
}

@pragma('vm:entry-point')
Future<void> anonymizedBackgroundMessageHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in the background isolate
  await Firebase.initializeApp();
  await NotificationService.initialize();
  await NotificationService.decryptAndShowLocalNotification(message);
}
