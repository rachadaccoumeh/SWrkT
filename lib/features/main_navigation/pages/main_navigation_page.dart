import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repository/appwrite_repository.dart';
import '../../home/pages/home_page.dart';
import '../../exercises/pages/exercises_page.dart';
import '../../workout/pages/workout_page.dart';
import '../../progress/pages/progress_page.dart';
import '../../settings/pages/settings_page.dart';

class MainNavigationController extends GetxController {
  final RxInt currentIndex = 0.obs;
  final pages = [
    const HomePage(),
    const ExercisesPage(),
    const WorkoutPage(),
    const ProgressPage(),
    const SettingsPage(),
  ];

  void changePage(int index) => currentIndex.value = index;

  int get navIndex => currentIndex.value;
}

class MainNavigationPage extends StatelessWidget {
  const MainNavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(MainNavigationController());
    return Obx(() => Scaffold(
      body: ctrl.pages[ctrl.currentIndex.value],
      bottomNavigationBar: _CustomBottomNav(
        currentIndex: ctrl.navIndex,
        onTap: ctrl.changePage,
      ),
    ));
  }
}

class _CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _CustomBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'Home', false),
      (Icons.fitness_center_rounded, 'Exercises', false),
      (Icons.play_arrow_rounded, 'Workout', false),
      (Icons.bar_chart_rounded, 'Progress', false),
      (Icons.settings_rounded, 'Settings', false),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 22,
                        color: isActive ? AppColors.primary : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive ? AppColors.primary : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
