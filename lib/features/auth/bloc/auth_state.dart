import 'package:equatable/equatable.dart';
import 'package:vybin/shared/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state representing the App started/splash loading state.
class AuthInitial extends AuthState {}

/// State representing unauthenticated user (ready for login/signup inputs).
class AuthUnauthenticated extends AuthState {}

/// State representing the ongoing login/signup network/authentication process.
class AuthLoading extends AuthState {}

/// State representing a successfully authenticated user.
class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// State representing a failure during initialization or authentication.
class AuthError extends AuthState {
  final String errorMessage;

  const AuthError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

/// State representing a network error during authentication.
class AuthNetworkError extends AuthState {
  final String errorMessage;

  const AuthNetworkError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

/// State representing an authenticated Firebase user who has not yet verified their email.
class AuthEmailUnverified extends AuthState {
  final UserModel user;
  final String? verificationError;
  final int timestamp;

  const AuthEmailUnverified(
    this.user, {
    this.verificationError,
    this.timestamp = 0,
  });

  @override
  List<Object?> get props => [user, verificationError, timestamp];
}

/// State representing a user who is authenticated on Firebase, but lacks their E2EE private key locally.
class AuthRequiresIdentityImport extends AuthState {
  final UserModel user;
  final String password;

  const AuthRequiresIdentityImport({
    required this.user,
    required this.password,
  });

  @override
  List<Object?> get props => [user, password];
}

/// State representing a successfully completed password change and vault re-encryption.
class AuthPasswordChangeSuccess extends AuthState {
  const AuthPasswordChangeSuccess();
}
