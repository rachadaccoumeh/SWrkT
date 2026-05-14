import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/debug_log.dart';
import 'data/local/local_store.dart';
import 'data/local/sync_manager.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'features/auth/controllers/auth_controller.dart';

late LocalStore localStore;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Init debug logger first so all code can use it
  await DebugLog.instance.init();

  // Initialize local Hive store (offline-first)
  localStore = LocalStore();
  LocalStore.instance = localStore;
  await localStore.init();

  // Register SyncManager
  Get.put(SyncManager(localStore), permanent: true);
  // Register AuthController
  Get.put(AuthController(), permanent: true);

  // Load theme
  bool isDark = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    isDark = prefs.getBool('dark_mode') ?? true;
  } catch (_) {}

  runApp(App(isDarkMode: isDark));
}

class App extends StatelessWidget {
  final bool isDarkMode;
  const App({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Simply Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
      defaultTransition: Transition.fade,
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}