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

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignUpRequested extends AuthEvent {
  final String displayName;
  final String username;
  final String email;
  final String password;
  final String? localPhotoPath;

  const SignUpRequested({
    required this.displayName,
    required this.username,
    required this.email,
    required this.password,
    this.localPhotoPath,
  });

  @override
  List<Object?> get props => [
    displayName,
    username,
    email,
    password,
    localPhotoPath,
  ];
}

class LogoutRequested extends AuthEvent {
  final bool eraseDeviceData;
  const LogoutRequested({this.eraseDeviceData = false});

  @override
  List<Object?> get props => [eraseDeviceData];
}

class CheckEmailVerificationRequested extends AuthEvent {}

class ResendVerificationEmailRequested extends AuthEvent {}

class UpdateProfileRequested extends AuthEvent {
  final String displayName;
  final String about;
  final String? localPhotoPath;

  const UpdateProfileRequested({
    required this.displayName,
    required this.about,
    this.localPhotoPath,
  });

  @override
  List<Object?> get props => [displayName, about, localPhotoPath];
}

class DeleteAccountRequested extends AuthEvent {}

class IdentityImportSubmitted extends AuthEvent {
  final String identityBlob;

  const IdentityImportSubmitted({required this.identityBlob});

  @override
  List<Object?> get props => [identityBlob];
}

class ChangePasswordRequested extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordRequested({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

class SessionMismatchDetected extends AuthEvent {}
