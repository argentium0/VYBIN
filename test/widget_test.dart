import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vybin/app.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/data/auth_repository.dart';
import 'package:vybin/shared/models/user_model.dart';
import 'package:vybin/core/services/encryption_service.dart';

class MockAuthRepository implements AuthRepository {
  @override
  EncryptionService get encryptionService => EncryptionService();

  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> signUp({
    required String displayName,
    required String username,
    required String email,
    required String password,
    String? localPhotoPath,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadProfileImage(File imageFile) async {
    return 'https://example.com/mock_profile_photo.jpg';
  }

  @override
  Future<void> logout({bool eraseDeviceData = false}) async {}

  @override
  bool isEmailVerified() => false;

  @override
  Future<void> reloadUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<String> uploadProfilePhoto({
    required String uid,
    required String localPath,
    String? existingPhotoUrl,
  }) async {
    return 'https://example.com/mock_profile_photo.jpg';
  }

  @override
  Future<UserModel> updateProfile({
    required String uid,
    required String displayName,
    required String about,
    String? profilePhotoUrl,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<UserModel> completeLoginWithPrivateKey({
    required UserModel user,
    required String password,
    required String encryptedPrivateKey,
  }) async {
    throw UnimplementedError();
  }

  @override
  StreamSubscription listenToSessionChanges(
    String userId,
    void Function() onSessionMismatch,
  ) {
    return const Stream<void>.empty().listen((_) {});
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (context) => AuthBloc(authRepository: MockAuthRepository()),
        child: const VybinApp(isFirstLaunch: false),
      ),
    );

    expect(find.text('VYBIN'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('Onboarding screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (context) => AuthBloc(authRepository: MockAuthRepository()),
        child: const VybinApp(isFirstLaunch: true),
      ),
    );

    expect(find.text('Your Space, Your Keys'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
