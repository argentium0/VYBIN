import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/shared/router/app_router.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class VybinApp extends StatefulWidget {
  const VybinApp({super.key});

  @override
  State<VybinApp> createState() => _VybinAppState();
}

class _VybinAppState extends State<VybinApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Retrieve AuthBloc and create the state-aware central router
    final authBloc = context.read<AuthBloc>();
    _router = AppRouter.createRouter(authBloc);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VYBIN',
      theme: VybinTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
