import '../entities/user.dart';
import '../repositories/i_auth_repository.dart';

class LoginAsGuestUseCase {
  final IAuthRepository repository;

  LoginAsGuestUseCase(this.repository);

  Future<User> call() async {
    return await repository.loginAsGuest();
  }
}
