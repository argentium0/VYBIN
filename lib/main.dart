import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vybin/app.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/data/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

  final authRepository = AuthRepository();

  runApp(
    BlocProvider(
      create: (context) => AuthBloc(authRepository: authRepository),
      child: VybinApp(isFirstLaunch: isFirstLaunch),
    ),
  );
}
