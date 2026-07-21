import 'package:flutter_test/flutter_test.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:vybin/shared/models/message_model.dart';
import 'package:vybin/shared/models/conversation_model.dart';

void main() {
  group('UserModel Tests', () {
    final now = DateTime(2026, 6, 26, 12, 0, 0);

    final userJson = {
      'uid': 'user123',
      'username': 'alice_dev',
      'displayName': 'Alice',
      'email': 'alice@example.com',
      'profilePhotoUrl': 'https://example.com/photo.png',
      'publicKey':
          '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...',
      'fcmToken': 'fcmToken123',
      'onlineStatus': 'online',
      'lastSeen': now.toIso8601String(),
      'about': 'Hey there! I am using VYBIN',
      'createdAt': now.toIso8601String(),
      'blockedUids': ['user_spammer'],
      'currentSessionId': 'session123',
    };

    test('should parse correctly from json', () {
      final model = UserModel.fromJson(userJson);

      expect(model.uid, 'user123');
      expect(model.username, 'alice_dev');
      expect(model.displayName, 'Alice');
      expect(model.email, 'alice@example.com');
      expect(model.profilePhotoUrl, 'https://example.com/photo.png');
      expect(model.publicKey, startsWith('-----BEGIN PUBLIC KEY-----'));
      expect(model.fcmToken, 'fcmToken123');
      expect(model.onlineStatus, 'online');
      expect(model.lastSeen, now);
      expect(model.about, 'Hey there! I am using VYBIN');
      expect(model.createdAt, now);
      expect(model.blockedUids, contains('user_spammer'));
      expect(model.currentSessionId, 'session123');
    });

    test('should serialize correctly to json', () {
      final model = UserModel.fromJson(userJson);
      final serialized = model.toJson();

      expect(serialized['uid'], 'user123');
      expect(serialized['username'], 'alice_dev');
      expect(serialized['displayName'], 'Alice');
      expect(serialized['email'], 'alice@example.com');
      expect(serialized['profilePhotoUrl'], 'https://example.com/photo.png');
      expect(serialized['publicKey'], startsWith('-----BEGIN PUBLIC KEY-----'));
      expect(serialized['fcmToken'], 'fcmToken123');
      expect(serialized['onlineStatus'], 'online');
      expect(serialized['lastSeen'], now.toIso8601String());
      expect(serialized['about'], 'Hey there! I am using VYBIN');
      expect(serialized['createdAt'], now.toIso8601String());
      expect(serialized['blockedUids'], contains('user_spammer'));
      expect(serialized['currentSessionId'], 'session123');
    });

    test('should support copyWith', () {
      final model = UserModel.fromJson(userJson);
      final copied = model.copyWith(
        displayName: 'Alice Updated',
        fcmToken: () => null,
        currentSessionId: () => 'newSessionId',
      );

      expect(copied.displayName, 'Alice Updated');
      expect(copied.fcmToken, isNull);
      expect(copied.currentSessionId, 'newSessionId');
      expect(copied.uid, model.uid);
    });

    test('should support Equatable equality', () {
      final model1 = UserModel.fromJson(userJson);
      final model2 = UserModel.fromJson(userJson);

      expect(model1, equals(model2));
    });
  });

  group('MessageModel Tests', () {
    final now = DateTime(2026, 6, 26, 12, 0, 0);

    final messageJson = {
      'messageId': 'msg456',
      'senderUid': 'user123',
      'timestamp': now.toIso8601String(),
      'type': 'text',
      'iv': 'dGVzdF9pdg==',
      'ciphertext': 'ZW5jcnlwdGVkX21lc3NhZ2U=',
      'encryptedKeys': {'user123': 'encKeyAliceB64', 'bob456': 'encKeyBobB64'},
      'status': 'read',
      'deliveredAt': now.toIso8601String(),
      'readAt': now.toIso8601String(),
      'mediaUrl': null,
      'mediaIv': null,
      'mediaEncryptedKeys': null,
      'mediaSize': null,
      'mediaMimeType': null,
      'mediaOriginalFilename': null,
      'deletedFor': <dynamic>[],
      'deletedForEveryone': false,
      'deletedForEveryoneAt': null,
    };

    test('should parse correctly from json', () {
      final model = MessageModel.fromJson(messageJson);

      expect(model.messageId, 'msg456');
      expect(model.senderUid, 'user123');
      expect(model.timestamp, now);
      expect(model.type, 'text');
      expect(model.iv, 'dGVzdF9pdg==');
      expect(model.ciphertext, 'ZW5jcnlwdGVkX21lc3NhZ2U=');
      expect(model.encryptedKeys, containsPair('user123', 'encKeyAliceB64'));
      expect(model.encryptedKeys, containsPair('bob456', 'encKeyBobB64'));
      expect(model.status, 'read');
      expect(model.deliveredAt, now);
      expect(model.readAt, now);
      expect(model.mediaUrl, isNull);
      expect(model.deletedFor, isEmpty);
      expect(model.deletedForEveryone, isFalse);
      expect(model.isDeleted, isFalse);
    });

    test('should support media fields when populated', () {
      final mediaJson = Map<String, dynamic>.from(messageJson)
        ..['type'] = 'image'
        ..['mediaUrl'] = 'https://example.com/media.enc'
        ..['mediaIv'] = 'mediaIvB64'
        ..['mediaEncryptedKeys'] = {'user123': 'mediaKeyAliceB64'}
        ..['mediaSize'] = 1024
        ..['mediaMimeType'] = 'image/png'
        ..['mediaOriginalFilename'] = 'enc_photo.png'
        ..['durationMs'] = 5000;

      final model = MessageModel.fromJson(mediaJson);
      expect(model.type, 'image');
      expect(model.mediaUrl, 'https://example.com/media.enc');
      expect(model.mediaIv, 'mediaIvB64');
      expect(
        model.mediaEncryptedKeys,
        containsPair('user123', 'mediaKeyAliceB64'),
      );
      expect(model.mediaSize, 1024);
      expect(model.mediaMimeType, 'image/png');
      expect(model.mediaOriginalFilename, 'enc_photo.png');
      expect(model.durationMs, 5000);
    });

    test('should serialize correctly to json', () {
      final model = MessageModel.fromJson(messageJson);
      final serialized = model.toJson();

      expect(serialized['messageId'], 'msg456');
      expect(serialized['senderUid'], 'user123');
      expect(serialized['timestamp'], now.toIso8601String());
      expect(serialized['type'], 'text');
      expect(serialized['iv'], 'dGVzdF9pdg==');
      expect(serialized['ciphertext'], 'ZW5jcnlwdGVkX21lc3NhZ2U=');
      expect(serialized['encryptedKeys'], isA<Map<String, String>>());
      expect(serialized['status'], 'read');
      expect(serialized['deliveredAt'], now.toIso8601String());
      expect(serialized['readAt'], now.toIso8601String());
      expect(serialized['deletedForEveryone'], isFalse);
      expect(serialized['isDeleted'], isFalse);
    });

    test('should support copyWith', () {
      final model = MessageModel.fromJson(messageJson);
      final copied = model.copyWith(
        status: 'delivered',
        readAt: () => null,
        isDeleted: true,
      );

      expect(copied.status, 'delivered');
      expect(copied.readAt, isNull);
      expect(copied.isDeleted, isTrue);
    });
  });

  group('ConversationModel Tests', () {
    final now = DateTime(2026, 6, 26, 12, 0, 0);

    final conversationJson = {
      'conversationId': 'user123_bob456',
      'participantUids': ['bob456', 'user123'],
      'createdAt': now.toIso8601String(),
      'lastMessageAt': now.toIso8601String(),
      'lastMessagePreview': {
        'senderUid': 'user123',
        'type': 'text',
        'iv': 'ivB64==',
        'ciphertext': 'previewTextB64',
        'encryptedKeys': {'user123': 'keyAlice', 'bob456': 'keyBob'},
        'status': 'sent',
      },
      'unreadCount': {'user123': 0, 'bob456': 2},
      'mutedBy': ['bob456'],
      'deletedBy': <dynamic>[],
    };

    test('should parse correctly from json', () {
      final model = ConversationModel.fromJson(conversationJson);

      expect(model.conversationId, 'user123_bob456');
      expect(model.participantUids, containsAll(['bob456', 'user123']));
      expect(model.createdAt, now);
      expect(model.lastMessageAt, now);
      expect(model.lastMessagePreview, isNotNull);
      expect(model.lastMessagePreview!.senderUid, 'user123');
      expect(model.lastMessagePreview!.ciphertext, 'previewTextB64');
      expect(model.lastMessagePreview!.status, 'sent');
      expect(model.unreadCount, containsPair('bob456', 2));
      expect(model.unreadCount, containsPair('user123', 0));
      expect(model.mutedBy, contains('bob456'));
      expect(model.deletedBy, isEmpty);
    });

    test('should serialize correctly to json', () {
      final model = ConversationModel.fromJson(conversationJson);
      final serialized = model.toJson();

      expect(serialized['conversationId'], 'user123_bob456');
      expect(serialized['participantUids'], containsAll(['bob456', 'user123']));
      expect(serialized['createdAt'], now.toIso8601String());
      expect(serialized['lastMessageAt'], now.toIso8601String());
      expect(serialized['lastMessagePreview']['senderUid'], 'user123');
      expect(serialized['lastMessagePreview']['status'], 'sent');
      expect(serialized['unreadCount']['bob456'], 2);
      expect(serialized['mutedBy'], contains('bob456'));
    });

    test('should support copyWith', () {
      final model = ConversationModel.fromJson(conversationJson);
      final copied = model.copyWith(
        unreadCount: {'user123': 1},
        lastMessagePreview: () => null,
      );

      expect(copied.unreadCount, containsPair('user123', 1));
      expect(copied.lastMessagePreview, isNull);
    });
  });
}
