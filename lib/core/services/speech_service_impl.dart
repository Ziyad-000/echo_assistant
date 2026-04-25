import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'i_speech_service.dart';

class SpeechServiceImpl implements ISpeechService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final Dio _dio = Dio();
  String? _tempFilePath;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<double> get amplitudeStream {
    return _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 50))
        .map((amp) {
          double normalized = (amp.current + 160) / 160;
          if (normalized < 0.0) return 0.0;
          if (normalized > 1.0) return 1.0;
          return normalized;
        });
  }

  @override
  Future<bool> initialize() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  @override
  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      _tempFilePath =
          '${dir.path}/speech_temp_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _tempFilePath!,
      );
      _isRecording = true;
    } else {
      throw Exception('Microphone permission denied');
    }
  }

  @override
  Future<String?> stopAndTranscribe() async {
    final path = await _audioRecorder.stop();
    _isRecording = false;

    if (path == null) return null;

    final groqApiKey = dotenv.env['Groq_SPECCH_TO_TEXT_API_KEY'] ?? '';
    if (groqApiKey.isEmpty) {
      throw Exception('Groq_SPECCH_TO_TEXT_API_KEY not found in .env file');
    }

    try {
      final file = File(path);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: 'audio.m4a'),
        'model': 'whisper-large-v3',
      });

      final response = await _dio.post(
        'https://api.groq.com/openai/v1/audio/transcriptions',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $groqApiKey'}),
      );

      // Cleanup
      if (await file.exists()) {
        await file.delete();
      }

      if (response.statusCode == 200) {
        debugPrint('Groq API Response: ${response.data}');
        return response.data['text'] as String?;
      } else {
        throw Exception('Transcription failed: ${response.statusCode}');
      }
    } catch (e) {
      if (_tempFilePath != null) {
        final file = File(_tempFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      throw Exception('Failed to transcribe audio: $e');
    }
  }

  @override
  Future<void> cancelRecording() async {
    await _audioRecorder.stop();
    _isRecording = false;
    if (_tempFilePath != null) {
      final file = File(_tempFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
