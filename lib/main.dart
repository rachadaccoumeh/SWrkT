import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/debug_log.dart';
import 'core/utils/access_control.dart';
import 'core/services/subscription_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/store_service.dart';
import 'core/services/admin_service.dart';
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

  // Register core services (order matters)
  Get.put(SyncManager(localStore), permanent: true);
  Get.put(AuthController(), permanent: true);

  // Initialize subscription service and wait for it
  final subsService = SubscriptionService();
  Get.put(subsService, permanent: true);
  await subsService.init();

  // Initialize ad service (depends on subscription service)
  final adService = AdService();
  Get.put(adService, permanent: true);
  await adService.init();

  // Initialize store service (depends on subscription service)
  final storeService = StoreService();
  Get.put(storeService, permanent: true);
  await storeService.init();

  // Initialize admin service
  Get.put(AdminService(), permanent: true);

  // Initialize AccessControl helper
  final accessControl = AccessControl();
  Get.put(accessControl, permanent: true);
  await accessControl.init();

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