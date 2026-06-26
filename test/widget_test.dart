import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/app.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      BlocProvider(
        create: (context) => AuthBloc(),
        child: const VybinApp(),
      ),
    );

    // Verify that the splash screen shows 'VYBIN'
    expect(find.text('VYBIN'), findsOneWidget);

    // Advance the time so that the BLoC's 100ms timer completes and routing occurs, preventing pending timer leaks.
    await tester.pumpAndSettle();
  });
}
