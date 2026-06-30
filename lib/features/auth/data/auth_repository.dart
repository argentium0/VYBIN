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
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _encryptionService = encryptionService ?? EncryptionService(),
        _secureKeyStorage = secureKeyStorage ?? SecureKeyStorage();

  /// Gets the currently authenticated user's profile from Firestore (if logged in).
  Future<UserModel?> getCurrentUser() async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) return null;

    final doc = await _firestore.collection('users').doc(fbUser.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromJson(doc.data()!);
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
    final derivedKey = _encryptionService.deriveKeyFromPassword(password, fbUser.uid);
    final encryptedPrivKey = await _secureKeyStorage.readEncryptedPrivateKey();
    if (encryptedPrivKey == null) {
      throw Exception('Encrypted private key not found on this device.');
    }

    final privKey = _encryptionService.decryptPrivateKey(encryptedPrivKey, derivedKey);
    final pubKey = _encryptionService.decodePublicKeyFromPem(user.publicKey);

    // Load key pair into memory
    _encryptionService.loadKeyPair(
      AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(pubKey, privKey),
    );

    // 4. Update online status in Firestore
    await _firestore.collection('users').doc(fbUser.uid).update({
      'onlineStatus': 'online',
      'lastSeen': DateTime.now().toIso8601String(),
    });

    return user.copyWith(
      onlineStatus: 'online',
      lastSeen: DateTime.now(),
    );
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
    final usernameDoc = await _firestore.collection('usernames').doc(sanitizedUsername).get();
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

    try {
      // 3. Generate RSA-2048 key pair
      final keyPair = await _encryptionService.generateKeyPair();

      // 4. Derive key and encrypt private key
      final derivedKey = _encryptionService.deriveKeyFromPassword(password, createdFbUser.uid);
      final encryptedPrivateKey = _encryptionService.encryptPrivateKey(keyPair.privateKey, derivedKey);

      // Save encrypted private key locally
      await _secureKeyStorage.writeEncryptedPrivateKey(encryptedPrivateKey);

      // Serialize public key to PEM string
      final publicKeyPem = _encryptionService.encodePublicKeyToPem(keyPair.publicKey);

      // 5. Write to Firestore in a transaction to ensure atomic username check and registration
      final user = UserModel(
        uid: createdFbUser.uid,
        username: sanitizedUsername,
        displayName: displayName,
        email: email,
        publicKey: publicKeyPem,
        onlineStatus: 'offline', // Default state on register is offline until they log in or session triggers online
        lastSeen: DateTime.now(),
        about: 'Hey there! I am using VYBIN',
        createdAt: DateTime.now(),
        blockedUids: const [],
      );

      await _firestore.runTransaction((transaction) async {
        final usernameRef = _firestore.collection('usernames').doc(sanitizedUsername);
        final usernameSnap = await transaction.get(usernameRef);
        if (usernameSnap.exists) {
          throw Exception('Username already taken. Please choose another one.');
        }

        final userRef = _firestore.collection('users').doc(createdFbUser!.uid);
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
    await _firebaseAuth.signOut();
  }
}
