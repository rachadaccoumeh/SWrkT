import 'package:appwrite/appwrite.dart';
import 'package:get/get.dart';
import '../../../data/repository/appwrite_repository.dart';
import '../../../routes/app_routes.dart';

class SplashController extends GetxController {
  final AppwriteRepository _repository = AppwriteRepository();

  @override
  void onReady() {
    super.onReady();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 3));
    final bool isLoggedIn = await _checkAuthState();
    Get.offAllNamed(isLoggedIn ? AppRoutes.home : AppRoutes.login);
  }

  /// Calls Appwrite account.get(). Returns true if a valid session exists.
  /// A 401 AppwriteException means no session → route to login.
  Future<bool> _checkAuthState() async {
    try {
      await _repository.getCurrentUser();
      return true;
    } on AppwriteException catch (e) {
      if (e.code == 401) return false;
      return false;
    } catch (_) {
      return false;
    }
  }
}
