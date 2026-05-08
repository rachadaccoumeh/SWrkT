import 'package:get/get.dart';
import '../features/splash/bindings/splash_binding.dart';
import '../features/splash/pages/splash_page.dart';
import '../features/auth/pages/login_page.dart';
import '../features/home/pages/home_page.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage> pages = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
    ),
  ];
}
