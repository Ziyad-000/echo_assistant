import '../../../../core/services/i_speech_service.dart';

class ProcessAudioRecordingUseCase {
  final ISpeechService _speechService;

  ProcessAudioRecordingUseCase(this._speechService);

  Future<String?> call() async {
    return await _speechService.stopAndTranscribe();
  }
}
