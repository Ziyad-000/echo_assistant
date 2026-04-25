import '../repositories/i_auth_repository.dart';

class CheckUserStatusUseCase {
  final IAuthRepository repository;

  CheckUserStatusUseCase(this.repository);

  Future<bool> call() async {
    return await repository.isLoggedIn();
  }
}
