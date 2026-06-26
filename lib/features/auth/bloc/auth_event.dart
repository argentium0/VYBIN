import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class SignUpRequested extends AuthEvent {
  final String displayName;
  final String username;
  final String email;
  final String password;

  const SignUpRequested({
    required this.displayName,
    required this.username,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [displayName, username, email, password];
}

class LogoutRequested extends AuthEvent {}
