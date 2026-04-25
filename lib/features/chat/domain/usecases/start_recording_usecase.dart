import '../../../../core/services/i_speech_service.dart';

class StartRecordingUseCase {
  final ISpeechService _speechService;

  StartRecordingUseCase(this._speechService);

  Future<void> call() async {
    await _speechService.startRecording();
  }
}
