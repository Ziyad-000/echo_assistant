import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/login_as_guest_usecase.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginAsGuestUseCase loginAsGuestUseCase;

  AuthCubit({required this.loginAsGuestUseCase}) : super(AuthInitial());

  Future<void> loginAsGuest() async {
    emit(AuthLoading());
    try {
      final user = await loginAsGuestUseCase();
      emit(AuthSuccess(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
