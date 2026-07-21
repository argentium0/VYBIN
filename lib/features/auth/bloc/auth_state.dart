import 'package:equatable/equatable.dart';
import 'package:vybin/shared/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String errorMessage;

  const AuthError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

class AuthNetworkError extends AuthState {
  final String errorMessage;

  const AuthNetworkError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

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

class AuthPasswordChangeSuccess extends AuthState {
  const AuthPasswordChangeSuccess();
}

class AuthNeedsMigrationState extends AuthState {
  final UserModel user;
  final String password;

  const AuthNeedsMigrationState({required this.user, required this.password});

  @override
  List<Object?> get props => [user, password];
}

class AuthLoggedOutState extends AuthState {
  final String message;

  const AuthLoggedOutState(this.message);

  @override
  List<Object?> get props => [message];
}
