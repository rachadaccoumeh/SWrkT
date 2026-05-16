import 'package:get/get.dart';
import '../features/splash/pages/splash_page.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/signup_page.dart';
import '../features/main_navigation/pages/main_navigation_page.dart';
import '../features/subscription/pages/subscription_page.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage> pages = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
    ),
    GetPage(
      name: AppRoutes.signup,
      page: () => const SignUpPage(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const MainNavigationPage(),
    ),
    GetPage(
      name: AppRoutes.subscription,
      page: () => const SubscriptionPage(),
    ),
  ];
}
