import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vybin/core/services/media_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:pointycastle/export.dart';
import 'package:vybin/core/services/encryption_service.dart';
import 'package:vybin/core/services/secure_key_storage.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:vybin/shared/models/conversation_model.dart';
import 'package:vybin/shared/models/message_model.dart';

class AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final EncryptionService _encryptionService;
  final SecureKeyStorage _secureKeyStorage;

  AuthRepository({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    EncryptionService? encryptionService,
    SecureKeyStorage? secureKeyStorage,
  }) : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _encryptionService = encryptionService ?? EncryptionService(),
       _secureKeyStorage = secureKeyStorage ?? SecureKeyStorage();

  EncryptionService get encryptionService => _encryptionService;

  /// Gets the currently authenticated user's profile from Firestore (if logged in).
  Future<UserModel?> getCurrentUser() async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) return null;

    final doc = await _firestore.collection('users').doc(fbUser.uid).get();
    if (!doc.exists) return null;

    final user = UserModel.fromJson(doc.data()!);

    // Load raw private key from secure storage if available
    final rawJson = await _secureKeyStorage.readRawPrivateKey();
    if (rawJson != null) {
      final privKey = _encryptionService.deserializePrivateKey(rawJson);
      final pubKey = _encryptionService.decodePublicKeyFromPem(user.publicKey);
      _encryptionService.loadKeyPair(
        AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(pubKey, privKey),
      );
    }

    return user;
  }

  /// Logs in an existing user and loads their E2EE private key.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Authenticate with Firebase Auth
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = userCredential.user;
      if (fbUser == null) {
        throw Exception('User authentication failed.');
      }

      // 2. Fetch user profile from Firestore
      final userDoc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found in database.');
      }

      final user = UserModel.fromJson(userDoc.data()!);

      // 3. Re-derive AES key and decrypt private key
      final hasRawKey = await _encryptionService.hasValidLocalPrivateKey(user.publicKey);
      if (hasRawKey) {
        final rawJson = await _secureKeyStorage.readRawPrivateKey();
        if (rawJson != null) {
          final privKey = _encryptionService.deserializePrivateKey(rawJson);
          final pubKey = _encryptionService.decodePublicKeyFromPem(user.publicKey);
          _encryptionService.loadKeyPair(
            AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(pubKey, privKey),
          );
          
          await _firestore.collection('users').doc(fbUser.uid).update({
            'onlineStatus': 'online',
            'lastSeen': DateTime.now().toIso8601String(),
          });
          return user.copyWith(onlineStatus: 'online', lastSeen: DateTime.now());
        }
      }

      final derivedKey = _encryptionService.deriveKeyFromPassword(
        password,
        fbUser.uid,
      );
      final encryptedPrivKey = await _secureKeyStorage.readEncryptedPrivateKey();
      if (encryptedPrivKey == null) {
        throw IdentityKeyMissingException(user: user, password: password);
      }

      try {
        final privKey = _encryptionService.decryptPrivateKey(
          encryptedPrivKey,
          derivedKey,
        );
        final pubKey = _encryptionService.decodePublicKeyFromPem(user.publicKey);

        if (privKey.modulus != pubKey.modulus) {
          throw IdentityKeyMissingException(user: user, password: password);
        }

        // Load key pair into memory
        _encryptionService.loadKeyPair(
          AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(pubKey, privKey),
        );

        // Save raw private key locally for background processing & startup
        final rawJson = _encryptionService.serializePrivateKey(privKey);
        await _secureKeyStorage.writeRawPrivateKey(rawJson);
      } catch (_) {
        throw IdentityKeyMissingException(user: user, password: password);
      }

      // 4. Update online status in Firestore
      await _firestore.collection('users').doc(fbUser.uid).update({
        'onlineStatus': 'online',
        'lastSeen': DateTime.now().toIso8601String(),
      });

      return user.copyWith(onlineStatus: 'online', lastSeen: DateTime.now());
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw NetworkException();
      }
      rethrow;
    }
  }

  Future<UserModel> signUp({
    required String displayName,
    required String username,
    required String email,
    required String password,
    String? localPhotoPath,
  }) async {
    try {
      final sanitizedUsername = username.trim().toLowerCase();

      // 1. Pre-check if the username is already taken
      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(sanitizedUsername)
          .get();
      if (usernameDoc.exists) {
        throw Exception('Username already taken. Please choose another one.');
      }

      // 2. Create the Firebase Auth account
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = userCredential.user;
      if (fbUser == null) {
        throw Exception('User registration failed.');
      }

      fb.User? createdFbUser = fbUser;
      await createdFbUser.sendEmailVerification();

      try {
        // Upload profile image immediately after Firebase Auth user is created if selected
        String? downloadUrl;
        if (localPhotoPath != null) {
          try {
            downloadUrl = await uploadProfilePhoto(
              uid: createdFbUser.uid,
              localPath: localPhotoPath,
            );
            await createdFbUser.updatePhotoURL(downloadUrl);
          } catch (e) {
            debugPrint('Error uploading profile picture during signup: $e');
            rethrow;
          }
        }

        // 3. Generate RSA-2048 key pair
        final keyPair = await _encryptionService.generateKeyPair();

        // 4. Derive key and encrypt private key
        final derivedKey = _encryptionService.deriveKeyFromPassword(
          password,
          createdFbUser.uid,
        );
        final encryptedPrivateKey = _encryptionService.encryptPrivateKey(
          keyPair.privateKey,
          derivedKey,
        );

        // Save encrypted private key locally
        await _secureKeyStorage.writeEncryptedPrivateKey(encryptedPrivateKey);
        final rawJson = _encryptionService.serializePrivateKey(keyPair.privateKey);
        await _secureKeyStorage.writeRawPrivateKey(rawJson);

        // Serialize public key to PEM string
        final publicKeyPem = _encryptionService.encodePublicKeyToPem(
          keyPair.publicKey,
        );

        // 5. Write to Firestore in a transaction to ensure atomic username check and registration
        final user = UserModel(
          uid: createdFbUser.uid,
          username: sanitizedUsername,
          displayName: displayName,
          email: email,
          publicKey: publicKeyPem,
          onlineStatus:
              'offline', // Default state on register is offline until they log in or session triggers online
          lastSeen: DateTime.now(),
          about: 'Hey there! I am using VYBIN',
          createdAt: DateTime.now(),
          blockedUids: const [],
          profilePhotoUrl: downloadUrl,
        );

        await _firestore.runTransaction((transaction) async {
          final usernameRef = _firestore
              .collection('usernames')
              .doc(sanitizedUsername);
          final usernameSnap = await transaction.get(usernameRef);
          if (usernameSnap.exists) {
            throw Exception('Username already taken. Please choose another one.');
          }

          final userRef = _firestore.collection('users').doc(createdFbUser.uid);
          final userData = user.toJson();
          if (downloadUrl != null) {
            userData['photoUrl'] = downloadUrl;
          }
          transaction.set(userRef, userData);
          transaction.set(usernameRef, {'uid': createdFbUser.uid});
        });

        // Load key pair into memory immediately since registration succeeded
        _encryptionService.loadKeyPair(keyPair);

        // Inject educational welcome system message from VYBIN Team
        await _injectWelcomeMessage(user);

        return user;
      } catch (e) {
        // Clean up Firebase Auth user if Firestore registration fails
        try {
          await createdFbUser.delete();
        } catch (_) {
          // Ignore auth deletion errors if it fails
        }
        rethrow;
      }
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw NetworkException();
      }
      rethrow;
    }
  }

  /// Sends an email verification to the currently logged in user
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      try {
        await user.sendEmailVerification();
      } on fb.FirebaseAuthException catch (e) {
        if (e.code == 'network-request-failed') {
          throw NetworkException();
        }
        rethrow;
      }
    }
  }

  /// Reloads the current user profile from Firebase Auth
  Future<void> reloadUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } on fb.FirebaseAuthException catch (e) {
        if (e.code == 'network-request-failed') {
          throw NetworkException();
        }
        rethrow;
      }
    }
  }

  /// Checks if the current firebase user's email is verified
  bool isEmailVerified() {
    final user = _firebaseAuth.currentUser;
    return user?.emailVerified ?? false;
  }

  /// Logs out the user and clears in-memory keys
  Future<void> logout({bool eraseDeviceData = false}) async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser != null) {
      try {
        await _firestore.collection('users').doc(fbUser.uid).update({
          'onlineStatus': 'offline',
          'lastSeen': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Ignore if network is offline
      }
    }

    _encryptionService.clearPrivateKey();
    if (eraseDeviceData) {
      await _secureKeyStorage.deleteRawPrivateKey();
      await _secureKeyStorage.deleteEncryptedPrivateKey();
    }
    await _firebaseAuth.signOut();
  }

  /// Compresses a photo and uploads it to Firebase Storage under `users/{uid}/profile_picture.jpg`.
  Future<String> uploadProfilePhoto({
    required String uid,
    required String localPath,
    String? existingPhotoUrl,
  }) async {
    // Stub or bypass if running in unit tests where Firebase is not initialized
    if (Firebase.apps.isEmpty) {
      return 'https://example.com/mock_profile_photo.jpg';
    }

    final file = File(localPath);
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/profile_${uid}_compressed.jpg';

    // Compress using flutter_image_compress
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 75,
      format: CompressFormat.jpeg,
    );

    if (compressedFile == null) {
      throw Exception('Failed to compress profile photo');
    }

    // Upload to Cloudinary
    final mediaService = MediaService();
    try {
      final downloadUrl = await mediaService.uploadToCloudinary(File(compressedFile.path));
      if (downloadUrl == null) {
        throw Exception('Failed to upload profile photo to Cloudinary');
      }
      return downloadUrl;
    } catch (e) {
      throw Exception('Unknown Upload Error: \$e');
    }
  }

  /// Compresses and uploads a profile image file for the currently authenticated user.
  /// Overwrites the existing profile picture at `users/{uid}/profile_picture.jpg` and returns the download URL.
  Future<String> uploadProfileImage(File imageFile) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user found for profile image upload.');
    }
    
    String? existingPhotoUrl;
    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        existingPhotoUrl = userDoc.data()?['photoUrl'] ?? userDoc.data()?['profilePhotoUrl'] as String?;
      }
    } catch (_) {
      existingPhotoUrl = currentUser.photoURL;
    }
    
    try {
      return await uploadProfilePhoto(
        uid: currentUser.uid,
        localPath: imageFile.path,
        existingPhotoUrl: existingPhotoUrl,
      );
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  /// Updates the user's display name, about section, and optional profile photo URL in Firestore and Firebase Auth.
  Future<UserModel> updateProfile({
    required String uid,
    required String displayName,
    required String about,
    String? profilePhotoUrl,
  }) async {
    // 1. Update Firebase Auth currentUser details if available
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        if (profilePhotoUrl != null) {
          await user.updatePhotoURL(profilePhotoUrl);
        }
        await user.updateDisplayName(displayName);
      }
    } catch (e) {
      debugPrint('Firebase Auth profile update error: $e');
    }

    final Map<String, dynamic> updates = {
      'displayName': displayName,
      'about': about,
    };
    if (profilePhotoUrl != null) {
      updates['profilePhotoUrl'] = profilePhotoUrl;
      updates['photoUrl'] = profilePhotoUrl; // Write photoUrl for consistency
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true));

    // Retrieve and return updated model
    final updatedDoc = await _firestore.collection('users').doc(uid).get();
    return UserModel.fromJson(updatedDoc.data()!);
  }

  /// Deletes the user account from Auth and Firestore, deleting the user profile and username mapping.
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Fetch username to delete it from usernames collection
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final username = userDoc.data()?['username'] as String?;

    final batch = _firestore.batch();
    batch.delete(_firestore.collection('users').doc(uid));
    if (username != null) {
      batch.delete(_firestore.collection('usernames').doc(username));
    }

    await batch.commit();
    await user.delete();

    // Clean up local keys
    _encryptionService.clearPrivateKey();
    await _secureKeyStorage.deleteRawPrivateKey();
    await _secureKeyStorage.deleteEncryptedPrivateKey();
  }

  /// Re-authenticates, changes the Firebase password, and re-encrypts the local cryptographic vault.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      throw Exception('No authenticated user found.');
    }

    // 1. Re-authenticate using the validated current password.
    final credential = fb.EmailAuthProvider.credential(
      email: currentUser.email!,
      password: currentPassword,
    );

    try {
      await currentUser.reauthenticateWithCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw NetworkException();
      }
      throw Exception('Re-authentication failed: ${e.message}');
    }

    RSAPrivateKey? temporaryPrivateKey;
    try {
      // 3. Vault Re-encryption Sequence
      // a. Decrypt local private key
      final encryptedPrivateKeyBase64 = await _secureKeyStorage.readEncryptedPrivateKey();
      if (encryptedPrivateKeyBase64 == null) {
        throw Exception('Cryptographic vault not found locally.');
      }

      final currentDerivedKey = _encryptionService.deriveKeyFromPassword(
        currentPassword,
        currentUser.uid,
      );

      temporaryPrivateKey = _encryptionService.decryptPrivateKey(
        encryptedPrivateKeyBase64,
        currentDerivedKey,
      );

      // b. Update password in Firebase Auth
      try {
        await currentUser.updatePassword(newPassword);
      } on fb.FirebaseAuthException catch (e) {
        if (e.code == 'network-request-failed') {
          throw NetworkException();
        }
        rethrow;
      }

      // c. Re-derive key with new password, encrypt, and save to secure storage
      final newDerivedKey = _encryptionService.deriveKeyFromPassword(
        newPassword,
        currentUser.uid,
      );

      final newEncryptedPrivateKeyBase64 = _encryptionService.encryptPrivateKey(
        temporaryPrivateKey,
        newDerivedKey,
      );

      await _secureKeyStorage.writeEncryptedPrivateKey(newEncryptedPrivateKeyBase64);
    } finally {
      // d. Wipe the plain text key from temporary memory variables
      temporaryPrivateKey = null;
    }
  }

  /// Completes the login process by saving and loading the private key.
  Future<UserModel> completeLoginWithPrivateKey({
    required UserModel user,
    required String password,
    required String encryptedPrivateKey,
  }) async {
    // Sanitize the pasted blob to remove any formatting/newlines/whitespace
    final sanitizedBlob = encryptedPrivateKey.replaceAll(RegExp(r'\s+'), '').trim();

    try {
      // 1. Save the encrypted private key to secure storage
      await _secureKeyStorage.writeEncryptedPrivateKey(sanitizedBlob);

      // 2. Re-derive AES key and decrypt private key
      final derivedKey = _encryptionService.deriveKeyFromPassword(
        password,
        user.uid,
      );

      final privKey = _encryptionService.decryptPrivateKey(
        sanitizedBlob,
        derivedKey,
      );
      final pubKey = _encryptionService.decodePublicKeyFromPem(user.publicKey);

      if (privKey.modulus != pubKey.modulus) {
        throw const FormatException('Private key modulus mismatch');
      }

      // Load key pair into memory
      _encryptionService.loadKeyPair(
        AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(pubKey, privKey),
      );

      // Save raw private key locally for background processing & startup
      final rawJson = _encryptionService.serializePrivateKey(privKey);
      await _secureKeyStorage.writeRawPrivateKey(rawJson);
    } catch (e) {
      throw Exception(
        'Invalid or corrupted migration blob. Please ensure you copied the entire text without missing characters.',
      );
    }

    // 3. Update online status in Firestore
    await _firestore.collection('users').doc(user.uid).update({
      'onlineStatus': 'online',
      'lastSeen': DateTime.now().toIso8601String(),
    });

    return user.copyWith(onlineStatus: 'online', lastSeen: DateTime.now());
  }

  Future<void> _injectWelcomeMessage(UserModel user) async {
    try {
      final sortedUids = [user.uid, 'vybin_team']..sort();
      final conversationId = sortedUids.join('_');

      // 1. Ensure the "VYBIN Team" user exists in Firestore
      final vybinTeamRef = _firestore.collection('users').doc('vybin_team');
      final vybinTeamSnap = await vybinTeamRef.get();
      if (!vybinTeamSnap.exists) {
        await vybinTeamRef.set({
          'uid': 'vybin_team',
          'displayName': 'VYBIN Team',
          'username': 'vybin_team',
          'email': 'team@vybin.internal',
          'publicKey': user.publicKey, // Use user's public key as dummy PEM
          'onlineStatus': 'online',
          'lastSeen': DateTime.now().toIso8601String(),
          'about': 'System Account',
          'createdAt': DateTime.now().toIso8601String(),
          'blockedUids': const <String>[],
        });
        
        await _firestore.collection('usernames').doc('vybin_team').set({
          'uid': 'vybin_team'
        });
      }

      // 2. Create the conversation document if not exists
      final convRef = _firestore.collection('conversations').doc(conversationId);
      final convSnap = await convRef.get();
      if (!convSnap.exists) {
        final unreadMap = {
          user.uid: 0,
          'vybin_team': 0,
        };
        await convRef.set({
          'conversationId': conversationId,
          'participantUids': [user.uid, 'vybin_team'],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCount': unreadMap,
          'mutedBy': const <String>[],
          'deletedBy': const <String>[],
          'lastMessagePreview': null,
        });
      }

      // 3. Encrypt the welcome message using user's public key
      const welcomeText =
          "Welcome to VYBIN! Because your privacy is our priority, this app uses strict End-to-End Encryption. Your access keys are locked entirely to this physical phone. If you ever plan to switch devices, you MUST go to Settings > Account > Export Cryptographic Identity and save your backup blob somewhere safe. Without it, your history cannot be recovered on a new device.";

      final encryptedData = _encryptionService.encryptMessage(
        plaintext: welcomeText,
        recipientUid: user.uid,
        recipientPubKeyPEM: user.publicKey,
        senderUid: 'vybin_team',
        senderPubKeyPEM: user.publicKey, // Use user's public key as dummy PEM
      );

      // 4. Create and save the message
      final messagesRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages');

      final messageDoc = messagesRef.doc();
      final messageId = messageDoc.id;

      final message = MessageModel(
        messageId: messageId,
        senderUid: 'vybin_team',
        timestamp: DateTime.now(),
        type: 'text',
        iv: encryptedData['iv'] as String,
        ciphertext: encryptedData['ciphertext'] as String,
        encryptedKeys: Map<String, String>.from(encryptedData['encryptedKeys'] as Map),
        status: 'sent',
        deletedFor: const [],
        deletedForEveryone: false,
      );

      final lastMessagePreview = LastMessagePreview(
        senderUid: 'vybin_team',
        type: 'text',
        iv: encryptedData['iv'] as String,
        ciphertext: encryptedData['ciphertext'] as String,
        encryptedKeys: Map<String, String>.from(encryptedData['encryptedKeys'] as Map),
        status: 'sent',
      );

      final batch = _firestore.batch();
      batch.set(messageDoc, message.toJson());
      batch.update(convRef, {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessagePreview': lastMessagePreview.toJson(),
        'unreadCount.${user.uid}': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      // Print/log and allow signup to complete even if welcome message injection fails
      debugPrint('Error injecting welcome message: $e');
    }
  }
}

class IdentityKeyMissingException implements Exception {
  final UserModel user;
  final String password;

  IdentityKeyMissingException({required this.user, required this.password});

  @override
  String toString() => 'Cryptographic identity key missing from secure storage.';
}

class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'Network error. Please check your internet connection and try again.']);

  @override
  String toString() => message;
}
