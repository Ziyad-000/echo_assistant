import '../models/user_model.dart';

abstract class IAuthRemoteDataSource {
  Future<UserModel> loginAsGuest();
  Future<bool> isLoggedIn();
}

class MockAuthRemoteDataSource implements IAuthRemoteDataSource {
  @override
  Future<UserModel> loginAsGuest() async {
    await Future.delayed(const Duration(seconds: 2));
    return const UserModel(id: 'guest_123', name: 'Guest User', isGuest: true);
  }

  @override
  Future<bool> isLoggedIn() async {
    // For now, return false to test the login flow.
    // In a real app, this would check local storage (e.g., SharedPreferences).
    return false;
  }
}
