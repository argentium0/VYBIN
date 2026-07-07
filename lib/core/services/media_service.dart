import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class MediaService {
  final ImagePicker _imagePicker;
  final AudioRecorder _audioRecorder;
  final AudioPlayer _audioPlayer;

  String? currentPlayingUrl;

  AudioPlayer get audioPlayer => _audioPlayer;

  MediaService({
    ImagePicker? imagePicker,
    AudioRecorder? audioRecorder,
    AudioPlayer? audioPlayer,
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _audioRecorder = audioRecorder ?? AudioRecorder(),
        _audioPlayer = audioPlayer ?? AudioPlayer() {
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        currentPlayingUrl = null;
      }
    });
  }

  /// Requests Camera Permission.
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Requests Microphone Permission.
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Requests Gallery/Storage Permission.
  Future<bool> requestStoragePermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    } else if (Platform.isAndroid) {
      final status = await Permission.photos.request();
      if (status.isGranted) return true;
      
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }

  /// Picks an image from camera or gallery.
  Future<File?> pickImage(ImageSource source) async {
    final XFile? pickedFile = await _imagePicker.pickImage(source: source);
    if (pickedFile == null) return null;
    return File(pickedFile.path);
  }

  /// Picks a video from camera or gallery.
  Future<File?> pickVideo(ImageSource source) async {
    final XFile? pickedFile = await _imagePicker.pickVideo(source: source);
    if (pickedFile == null) return null;
    return File(pickedFile.path);
  }


  /// Compresses the image to target size (max 1920px, 85% quality).
  Future<File?> compressImage(File imageFile) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(
      tempDir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}${p.extension(imageFile.path)}',
    );

    final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      minWidth: 1920,
      minHeight: 1920,
      quality: 85,
    );

    if (compressedXFile == null) return null;
    return File(compressedXFile.path);
  }

  /// Starts recording audio, saving it to a temporary AAC/M4A file.
  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final tempDir = await getTemporaryDirectory();
      final filePath = p.join(
        tempDir.path,
        'audio_record_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );
    } else {
      throw Exception("Microphone permission not granted");
    }
  }

  /// Stops recording and returns the raw file bytes.
  Future<Uint8List?> stopRecording() async {
    final path = await _audioRecorder.stop();
    if (path == null) return null;

    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  /// Plays a given local audio file.
  Future<void> playAudio(String filePath) async {
    currentPlayingUrl = filePath;
    await _audioPlayer.setFilePath(filePath);
    await _audioPlayer.play();
  }

  /// Stops playback.
  Future<void> stopAudio() async {
    currentPlayingUrl = null;
    await _audioPlayer.stop();
  }

  /// Reads and returns the bytes of a file at the given local path.
  Future<Uint8List> getMediaBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File does not exist at path: $path');
    }
    return await file.readAsBytes();
  }

  /// Disposes resources.
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }

  /// Uploads file to Cloudinary and returns the secure URL
  Future<String?> uploadToCloudinary(File file, {bool isEncrypted = false}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/pshkpybp/auto/upload'),
      );
      request.fields['upload_preset'] = 'vybin_unsigned';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(responseData);
        return jsonResponse['secure_url'] as String?;
      } else {
        debugPrint('Cloudinary upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception during Cloudinary upload: $e');
      return null;
    }
  }
}
