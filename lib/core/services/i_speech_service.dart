abstract class ISpeechService {
  Future<bool> initialize();
  Future<void> startRecording();
  Future<String?> stopAndTranscribe();
  Future<void> cancelRecording();
  bool get isRecording;
  Stream<double> get amplitudeStream;
}
