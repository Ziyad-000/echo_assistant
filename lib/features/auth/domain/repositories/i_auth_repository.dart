import '../entities/user.dart';

abstract class IAuthRepository {
  Future<User> loginAsGuest();
  Future<bool> isLoggedIn();
}
