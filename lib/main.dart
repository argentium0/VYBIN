import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/app.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';

void main() {
  runApp(
    BlocProvider(create: (context) => AuthBloc(), child: const VybinApp()),
  );
}
