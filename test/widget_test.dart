import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vybin/app.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/data/auth_repository.dart';
import 'package:vybin/shared/models/user_model.dart';

class MockAuthRepository implements AuthRepository {
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
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

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
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      BlocProvider(
        create: (context) => AuthBloc(authRepository: MockAuthRepository()),
        child: const VybinApp(isFirstLaunch: false),
      ),
    );

    // Verify that the splash screen shows 'VYBIN'
    expect(find.text('VYBIN'), findsOneWidget);

    // Advance the time so that the BLoC's 100ms timer completes and routing occurs, preventing pending timer leaks.
    await tester.pumpAndSettle();
  });

  testWidgets('Onboarding screen smoke test', (WidgetTester tester) async {
    // Build our app with first launch = true
    await tester.pumpWidget(
      BlocProvider(
        create: (context) => AuthBloc(authRepository: MockAuthRepository()),
        child: const VybinApp(isFirstLaunch: true),
      ),
    );

    // Verify that the onboarding screen shows the welcome title
    expect(find.text('Your Space, Your Keys'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
