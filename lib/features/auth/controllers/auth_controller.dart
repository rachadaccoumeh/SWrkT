import 'package:get/get.dart';
import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repository/appwrite_repository.dart';
import '../../../routes/app_routes.dart';

class AuthController extends GetxController {
  final AppwriteRepository _repo = AppwriteRepository();
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool isLoggedIn = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkSession();
  }

  Future<void> checkSession() async {
    try {
      await _repo.getCurrentUser();
      isLoggedIn.value = true;
    } on AppwriteException catch (e) {
      if (e.code == 401) isLoggedIn.value = false;
    } catch (_) {
      isLoggedIn.value = false;
    }
  }

  Future<void> login(String email, String password) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _repo.login(email: email, password: password);
      await _ensureUserRecord();
      isLoggedIn.value = true;
      Get.offAllNamed(AppRoutes.home);
    } on AppwriteException catch (e) {
      errorMessage.value = e.message ?? 'Login failed. Please check your credentials.';
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signUp(String name, String email, String password) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final user = await _repo.register(email: email, password: password, name: name);
      // Auto-login after signup
      await _repo.login(email: email, password: password);
      // Create profile
      await _repo.createUserProfile(user.$id, {
        'user_id': user.$id,
        'name': name,
        'email': email,
        'avatar_url': '',
        'created_at': DateTime.now().toIso8601String(),
      });
      // Create preferences
      await _repo.createPreference(user.$id, {
        'user_id': user.$id,
        'dark_mode': true,
        'weight_unit': 'lbs',
        'created_at': DateTime.now().toIso8601String(),
      });
      isLoggedIn.value = true;
      Get.offAllNamed(AppRoutes.home);
    } on AppwriteException catch (e) {
      errorMessage.value = e.message ?? 'Signup failed. Try a different email.';
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    isLoading.value = true;
    try {
      await _repo.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      isLoggedIn.value = false;
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      errorMessage.value = 'Logout failed.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _ensureUserRecord() async {
    try {
      final user = await _repo.getCurrentUser();
      final profiles = await _repo.getUserProfile(user.$id);
      if (profiles.documents.isEmpty) {
        await _repo.createUserProfile(user.$id, {
          'user_id': user.$id,
          'name': user.name,
          'email': user.email,
          'avatar_url': '',
          'created_at': DateTime.now().toIso8601String(),
        });
        await _repo.createPreference(user.$id, {
          'dark_mode': true,
          'weight_unit': 'lbs',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }
}
