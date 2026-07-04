import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import '../data/auth_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository(),
        super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckEmailVerificationRequested>(_onCheckEmailVerificationRequested);
    on<ResendVerificationEmailRequested>(_onResendVerificationEmailRequested);
    on<UpdateProfileRequested>(_onUpdateProfileRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);
    on<IdentityImportSubmitted>(_onIdentityImportSubmitted);
    on<ChangePasswordRequested>(_onChangePasswordRequested);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthInitial());
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        if (_authRepository.isEmailVerified()) {
          emit(AuthAuthenticated(user));
        } else {
          emit(AuthEmailUnverified(user));
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.login(
        email: event.email,
        password: event.password,
      );
      if (_authRepository.isEmailVerified()) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthEmailUnverified(user));
      }
    } on IdentityKeyMissingException catch (e) {
      emit(AuthRequiresIdentityImport(user: e.user, password: e.password));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signUp(
        displayName: event.displayName,
        username: event.username,
        email: event.email,
        password: event.password,
      );
      emit(AuthEmailUnverified(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCheckEmailVerificationRequested(
    CheckEmailVerificationRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthEmailUnverified) {
      try {
        await _authRepository.reloadUser();
        if (_authRepository.isEmailVerified()) {
          final user = await _authRepository.getCurrentUser();
          if (user != null) {
            emit(AuthAuthenticated(user));
          } else {
            emit(AuthEmailUnverified(
              currentState.user,
              verificationError: 'User profile not found in database.',
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        } else {
          emit(AuthEmailUnverified(
            currentState.user,
            verificationError: 'Email verification is still pending. Please check your inbox.',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      } catch (e) {
        emit(AuthEmailUnverified(
          currentState.user,
          verificationError: e.toString().replaceAll('Exception: ', ''),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }
  }

  Future<void> _onResendVerificationEmailRequested(
    ResendVerificationEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthEmailUnverified) {
      try {
        await _authRepository.sendEmailVerification();
      } catch (e) {
        emit(AuthEmailUnverified(
          currentState.user,
          verificationError: e.toString().replaceAll('Exception: ', ''),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }
  }

  Future<void> _onUpdateProfileRequested(
    UpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      emit(AuthLoading());
      try {
        String? downloadUrl;
        if (event.localPhotoPath != null) {
          downloadUrl = await _authRepository.uploadProfilePhoto(
            uid: currentState.user.uid,
            localPath: event.localPhotoPath!,
          );
        }

        final updatedUser = await _authRepository.updateProfile(
          uid: currentState.user.uid,
          displayName: event.displayName,
          about: event.about,
          profilePhotoUrl: downloadUrl,
        );

        emit(AuthAuthenticated(updatedUser));
      } catch (e) {
        emit(AuthError(e.toString()));
        emit(AuthAuthenticated(currentState.user));
      }
    }
  }

  Future<void> _onDeleteAccountRequested(
    DeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.deleteAccount();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onIdentityImportSubmitted(
    IdentityImportSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthRequiresIdentityImport) {
      emit(AuthLoading());
      try {
        final user = await _authRepository.completeLoginWithPrivateKey(
          user: currentState.user,
          password: currentState.password,
          encryptedPrivateKey: event.identityBlob.trim(),
        );

        if (_authRepository.isEmailVerified()) {
          emit(AuthAuthenticated(user));
        } else {
          emit(AuthEmailUnverified(user));
        }
      } catch (e) {
        emit(AuthError(e.toString().replaceAll('Exception: ', '')));
        // Restore previous state so user can re-attempt pasting/editing
        emit(currentState);
      }
    }
  }

  Future<void> _onChangePasswordRequested(
    ChangePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      emit(AuthLoading());
      try {
        await _authRepository.changePassword(
          currentPassword: event.currentPassword,
          newPassword: event.newPassword,
        );
        emit(const AuthPasswordChangeSuccess());
        emit(AuthAuthenticated(currentState.user));
      } catch (e) {
        emit(AuthError(e.toString().replaceAll('Exception: ', '')));
        emit(AuthAuthenticated(currentState.user));
      }
    }
  }
}
