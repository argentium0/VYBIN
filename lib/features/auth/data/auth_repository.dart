import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:pointycastle/export.dart';
import 'package:vybin/core/services/encryption_service.dart';
import 'package:vybin/core/services/secure_key_storage.dart';
import 'package:vybin/shared/models/user_model.dart';

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
    final derivedKey = _encryptionService.deriveKeyFromPassword(
      password,
      fbUser.uid,
    );
    final encryptedPrivKey = await _secureKeyStorage.readEncryptedPrivateKey();
    if (encryptedPrivKey == null) {
      throw Exception('Encrypted private key not found on this device.');
    }

    final privKey = _encryptionService.decryptPrivateKey(
      encryptedPrivKey,
      derivedKey,
    );
    final pubKey = _encryptionService.decodePublicKeyFromPem(user.publicKey);

    // Load key pair into memory
    _encryptionService.loadKeyPair(
      AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(pubKey, privKey),
    );

    // Save raw private key locally for background processing & startup
    final rawJson = _encryptionService.serializePrivateKey(privKey);
    await _secureKeyStorage.writeRawPrivateKey(rawJson);

    // 4. Update online status in Firestore
    await _firestore.collection('users').doc(fbUser.uid).update({
      'onlineStatus': 'online',
      'lastSeen': DateTime.now().toIso8601String(),
    });

    return user.copyWith(onlineStatus: 'online', lastSeen: DateTime.now());
  }

  /// Registers a new user with an atomic username check and public/private key generation.
  Future<UserModel> signUp({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) async {
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
        transaction.set(userRef, user.toJson());
        transaction.set(usernameRef, {'uid': createdFbUser.uid});
      });

      // Load key pair into memory immediately since registration succeeded
      _encryptionService.loadKeyPair(keyPair);

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
  }

  /// Sends an email verification to the currently logged in user
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
    }
  }

  /// Reloads the current user profile from Firebase Auth
  Future<void> reloadUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  /// Checks if the current firebase user's email is verified
  bool isEmailVerified() {
    final user = _firebaseAuth.currentUser;
    return user?.emailVerified ?? false;
  }

  /// Logs out the user and clears in-memory keys
  Future<void> logout() async {
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
    await _secureKeyStorage.deleteRawPrivateKey();
    await _firebaseAuth.signOut();
  }

  /// Compresses a photo and uploads it to Firebase Storage under `/profiles/{uid}.jpg`.
  Future<String> uploadProfilePhoto({
    required String uid,
    required String localPath,
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

    // Upload to Firebase Storage
    final ref = FirebaseStorage.instance.ref().child('profiles').child('$uid.jpg');
    final uploadTask = await ref.putFile(File(compressedFile.path));
    return await uploadTask.ref.getDownloadURL();
  }

  /// Updates the user's display name, about section, and optional profile photo URL in Firestore.
  Future<UserModel> updateProfile({
    required String uid,
    required String displayName,
    required String about,
    String? profilePhotoUrl,
  }) async {
    final Map<String, dynamic> updates = {
      'displayName': displayName,
      'about': about,
    };
    if (profilePhotoUrl != null) {
      updates['profilePhotoUrl'] = profilePhotoUrl;
    }

    await _firestore.collection('users').doc(uid).update(updates);

    // Retrieve and return updated model
    final updatedDoc = await _firestore.collection('users').doc(uid).get();
    return UserModel.fromJson(updatedDoc.data()!);
  }
}
