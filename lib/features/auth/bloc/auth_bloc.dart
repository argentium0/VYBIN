import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/models/user_model.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthInitial());

    // Simulate initial startup (checking login cache/keys storage)
    await Future.delayed(const Duration(milliseconds: 100));

    // Default to unauthenticated state for now
    emit(AuthUnauthenticated());
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    // Simulate network authentication request
    await Future.delayed(const Duration(milliseconds: 1500));

    // Hardcoded logic to simulate authentication errors
    if (event.email == 'error@example.com') {
      emit(const AuthError('Invalid email or password'));
      return;
    }

    // Mock successful user profile setup
    final mockUser = UserModel(
      uid: 'mock_uid_123',
      username: 'abdullah123',
      displayName: 'Abdullah Naseer',
      email: event.email,
      profilePhotoUrl: null,
      publicKey:
          '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...',
      fcmToken: 'mock_fcm_token',
      onlineStatus: 'online',
      lastSeen: DateTime.now(),
      about: 'Hey there! I am using VYBIN',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      blockedUids: const [],
    );

    emit(AuthAuthenticated(mockUser));
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    // Simulate network registration & key generation request
    await Future.delayed(const Duration(milliseconds: 1500));

    // Hardcoded logic to simulate registration username clash
    if (event.username.toLowerCase() == 'taken') {
      emit(
        const AuthError('Username already taken. Please choose another one.'),
      );
      return;
    }

    // Mock successful signup profile setup
    final mockUser = UserModel(
      uid: 'mock_uid_new',
      username: event.username.toLowerCase(),
      displayName: event.displayName,
      email: event.email,
      profilePhotoUrl: null,
      publicKey:
          '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...',
      fcmToken: 'mock_fcm_token_new',
      onlineStatus: 'online',
      lastSeen: DateTime.now(),
      about: 'Hey there! I am using VYBIN',
      createdAt: DateTime.now(),
      blockedUids: const [],
    );

    emit(AuthAuthenticated(mockUser));
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    // Simulate cleanup
    await Future.delayed(const Duration(milliseconds: 800));

    emit(AuthUnauthenticated());
  }
}
