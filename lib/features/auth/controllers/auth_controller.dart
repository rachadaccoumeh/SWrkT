import 'package:get/get.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repository/appwrite_repository.dart';
import '../../../data/local/local_store.dart';
import '../../../data/local/sync_manager.dart';
import '../../../core/utils/debug_log.dart';
import '../../../routes/app_routes.dart';

class AuthController extends GetxController {
  final AppwriteRepository _repo = AppwriteRepository();
  final _log = DebugLog.instance;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool isLoggedIn = false.obs;
  final Rx<models.User?> user = Rx<models.User?>(null);

  @override
  void onInit() {
    super.onInit();
    _log.auth('AuthController onInit');
    checkSession();
  }

  Future<void> checkSession() async {
    _log.auth('checkSession() called');
    try {
      final u = await _repo.getCurrentUser();
      user.value = u;
      isLoggedIn.value = true;
      _log.auth('checkSession succeeded, user: ${u?.$id}');
    } on AppwriteException catch (e) {
      _log.auth('checkSession AppwriteException: ${e.code}');
      if (e.code == 401) isLoggedIn.value = false;
    } catch (e) {
      _log.error('checkSession failed', data: e.toString());
      isLoggedIn.value = false;
    }
  }

  Future<void> login(String email, String password) async {
    _log.auth('login() called for: $email');
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _repo.login(email: email, password: password);
      user.value = await _repo.getCurrentUser();
      _log.auth('login succeeded, user: ${user.value?.$id}');
      await _ensureUserRecord();
      isLoggedIn.value = true;
      Get.offAllNamed(AppRoutes.home);
    } on AppwriteException catch (e) {
      _log.error('login AppwriteException', data: '${e.code}: ${e.message}');
      errorMessage.value = e.message ?? 'Login failed. Please check your credentials.';
    } catch (e) {
      _log.error('login failed', data: e.toString());
      errorMessage.value = 'An unexpected error occurred.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signUp(String name, String email, String password) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final newUser = await _repo.register(email: email, password: password, name: name);
      await _repo.login(email: email, password: password);
      user.value = newUser;

      // Create in Appwrite
      await _repo.createUserProfile(user.value!.$id, {
        'user_id': user.value!.$id,
        'name': name,
        'email': email,
        'avatar_url': '',
        'created_at': DateTime.now().toIso8601String(),
      });
      await _repo.createPreference(user.value!.$id, {
        'user_id': user.value!.$id,
        'dark_mode': true,
        'weight_unit': 'lbs',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Sync to local store
      await _syncProfileAndPrefsToLocal(user.value!.$id, name, email);

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
      await LocalStore.instance.clearAll();
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
      await _syncProfileAndPrefsToLocal(user.$id, user.name, user.email);
    } catch (_) {}
  }

  Future<void> _syncProfileAndPrefsToLocal(String userId, String name, String email) async {
    // Save profile to local
    await LocalStore.instance.saveProfile({
      'id': 'profile_$userId',
      'userId': userId,
      'name': name,
      'email': email,
      'avatarUrl': '',
      'isSynced': true,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    // Save prefs to local
    await LocalStore.instance.savePrefs({
      'id': 'prefs_$userId',
      'userId': userId,
      'darkMode': true,
      'weightUnit': 'lbs',
      'isSynced': true,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    // Also save locally to SharedPreferences for startup theme
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', true);
    await prefs.setString('weight_unit', 'lbs');
  }

  Future<void> updateLocalProfile(String userId, Map<String, dynamic> data) async {
    await LocalStore.instance.saveProfile(data);
  }

  Future<void> updateLocalPrefs(String userId, Map<String, dynamic> data) async {
    await LocalStore.instance.savePrefs(data);
    final prefs = await SharedPreferences.getInstance();
    if (data.containsKey('darkMode')) {
      await prefs.setBool('dark_mode', data['darkMode'] as bool);
    }
    if (data.containsKey('weightUnit')) {
      await prefs.setString('weight_unit', data['weightUnit'] as String);
    }
  }
}