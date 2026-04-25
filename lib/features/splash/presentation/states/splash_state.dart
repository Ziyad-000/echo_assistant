abstract class SplashState {}

class SplashWaiting extends SplashState {}

class SplashNavigateToLogin extends SplashState {}

class SplashNavigateToChat extends SplashState {}

class SplashError extends SplashState {
  final String message;
  SplashError(this.message);
}
