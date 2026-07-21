import 'package:flutter_test/flutter_test.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:vybin/core/services/zego_signaling_extension.dart';

void main() {
  group('ZegoUIKitSignalingPluginExtension Tests', () {
    test(
      'sendCustomCommand throws Exception when ZIM is not initialized',
      () async {
        final plugin = ZegoUIKitSignalingPlugin();

        expect(
          () => plugin.sendCustomCommand(
            inviterID: 'user_1',
            inviteeIDs: ['user_2'],
            customCommand: 'test_command',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('ZIM is not initialized.'),
            ),
          ),
        );
      },
    );
  });
}
