import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybin/core/services/media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const MethodChannel pickerChannel = MethodChannel(
    'plugins.flutter.io/image_picker',
  );
  const MethodChannel recordChannel = MethodChannel(
    'com.llfbandit.record/messages',
  );
  const MethodChannel justAudioChannel = MethodChannel(
    'com.ryanheise.just_audio.methods',
  );

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (
          MethodCall methodCall,
        ) async {
          log.add(methodCall);
          if (methodCall.method == 'requestPermissions') {
            final List<dynamic> permissions =
                methodCall.arguments as List<dynamic>;
            final Map<int, int> results = {};
            for (final p in permissions) {
              results[p as int] = 1;
            }
            return results;
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (MethodCall methodCall) async {
          log.add(methodCall);
          if (methodCall.method == 'pickImage') {
            return '/mocked/path/to/image.png';
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (MethodCall methodCall) async {
          log.add(methodCall);
          if (methodCall.method == 'create') {
            return 'mock_recorder_id';
          }
          if (methodCall.method == 'hasPermission') {
            return true;
          }
          if (methodCall.method == 'start') {
            return null;
          }
          if (methodCall.method == 'stop') {
            return '/mocked/path/to/audio.m4a';
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(justAudioChannel, (
          MethodCall methodCall,
        ) async {
          log.add(methodCall);
          if (methodCall.method == 'init') {
            return {'duration': 10000};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(justAudioChannel, null);
  });

  test('MediaService requests camera permission successfully', () async {
    final mediaService = MediaService();
    final granted = await mediaService.requestCameraPermission();
    expect(granted, isTrue);
  });

  test('MediaService requests microphone permission successfully', () async {
    final mediaService = MediaService();
    final granted = await mediaService.requestMicrophonePermission();
    expect(granted, isTrue);
  });

  test('MediaService requests storage permission successfully', () async {
    final mediaService = MediaService();
    final granted = await mediaService.requestStoragePermission();
    expect(granted, isTrue);
  });
}
