import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    String? conversationId;
    if (myUid != null) {
      final sorted = [senderUid, myUid]..sort();
      conversationId = sorted.join('_');

      // Update message status to 'delivered' in Firestore if currently 'sent' (non-decrypting operation)
      try {
        final docRef = FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(messageId);
        final doc = await docRef.get();
        if (doc.exists && doc.data()?['status'] == 'sent') {
          await docRef.update({
            'status': 'delivered',
            'deliveredAt': FieldValue.serverTimestamp(),
          });
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .update({
            'lastMessagePreview.status': 'delivered',
          });
        }
      } catch (e) {
        debugPrint('Error updating message delivery status in background: $e');
      }
    }

    // Show generic, privacy-respecting notification
    await showNotification(
      id: messageId.hashCode,
      title: 'VYBIN',
      body: '🔒 New Encrypted Message',
      payload: jsonEncode({
        'conversationId': ?conversationId,
        'senderUid': senderUid,
      }),
    );
  }

  static Future<void> showAnonymizedNotification(String senderUid) async {
    await showNotification(
      id: senderUid.hashCode,
      title: 'VYBIN',
      body: '🔒 New Encrypted Message',
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
