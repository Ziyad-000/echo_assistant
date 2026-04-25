import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/usecases/check_user_status_usecase.dart';

// --- States ---
abstract class SplashState {}

class SplashWaiting extends SplashState {}

class SplashNavigateToLogin extends SplashState {}

class SplashNavigateToChat extends SplashState {}

// --- Cubit ---
class SplashCubit extends Cubit<SplashState> {
  final CheckUserStatusUseCase checkUserStatusUseCase;

  SplashCubit({required this.checkUserStatusUseCase}) : super(SplashWaiting());

  void startSplash() async {
    // Optional: Add a small delay for branding if needed
    await Future.delayed(const Duration(seconds: 2));

    // Check authentication status
    final bool isLoggedIn = await checkUserStatusUseCase();

    if (isLoggedIn) {
      emit(SplashNavigateToChat());
    } else {
      emit(SplashNavigateToLogin());
    }
  }
}
