import 'package:equatable/equatable.dart';
import 'package:vybin/shared/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state representing the App started/splash loading state.
class AuthInitializing extends AuthState {}

/// State representing unauthenticated user (ready for login/signup inputs).
class AuthUnauthenticated extends AuthState {}

/// State representing the ongoing login/signup network/authentication process.
class AuthAuthenticating extends AuthState {}

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
