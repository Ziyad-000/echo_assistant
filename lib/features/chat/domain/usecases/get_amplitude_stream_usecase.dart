import 'dart:async';
import '../../../../core/services/i_speech_service.dart';

class GetAmplitudeStreamUseCase {
  final ISpeechService _speechService;

  GetAmplitudeStreamUseCase(this._speechService);

  Stream<double> call() {
    return _speechService.amplitudeStream;
  }
}
