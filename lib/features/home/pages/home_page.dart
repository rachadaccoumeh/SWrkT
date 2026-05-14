import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/appwrite.dart';
import '../../../core/theme/app_colors.dart';
import '../../main_navigation/pages/main_navigation_page.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/repository/appwrite_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final repo = AppwriteRepository();
  models.User? user;
  models.Document? profile;
  List<models.Document> recentWorkouts = [];
  List<models.Document> recentExercises = [];
  List<models.Document> allWorkouts = [];
  List<models.Document> allSets = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      user = await repo.getCurrentUser();
      final profiles = await repo.getUserProfile(user!.$id);
      if (profiles.documents.isNotEmpty) profile = profiles.documents.first;
      final workouts = await repo.getWorkouts(user!.$id);
      allWorkouts = workouts.documents;
      recentWorkouts = workouts.documents.where((w) => !(w.data['is_active'] ?? false)).take(5).toList();
      final exercises = await repo.getExercises(user!.$id);
      recentExercises = exercises.documents.take(5).toList();
      final sets = await repo.getAllSets(user!.$id);
      allSets = sets.documents;
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  int get _workoutsThisWeek {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return allWorkouts.where((w) {
      final d = DateTime.tryParse(w.data['completed_at'] ?? w.data['started_at'] ?? '');
      return d != null && d.isAfter(weekAgo) && w.data['is_active'] == false;
    }).length;
  }

  double get _totalVolumeThisWeek {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    double vol = 0;
    for (final w in allWorkouts) {
      final d = DateTime.tryParse(w.data['completed_at'] ?? w.data['started_at'] ?? '');
      if (d == null || d.isBefore(weekAgo) || w.data['is_active'] == true) continue;
      for (final s in allSets) {
        if (s.data['workout_id'] == w.$id && s.data['is_completed'] == true) {
          vol += ((s.data['reps'] ?? 0) as int) * ((s.data['weight'] ?? 0.0) as double);
        }
      }
    }
    return vol;
  }

  int get _streakDays {
    if (allWorkouts.isEmpty) return 0;
    final completed = allWorkouts.where((w) => w.data['is_active'] == false).toList();
    if (completed.isEmpty) return 0;
    final dates = completed.map((w) {
      final d = DateTime.tryParse(w.data['completed_at'] ?? w.data['started_at'] ?? '');
      return d != null ? DateTime(d.year, d.month, d.day) : null;
    }).whereType<DateTime>().toSet().toList()..sort((a, b) => b.compareTo(a));
    if (dates.isEmpty) return 0;
    int streak = 0;
    DateTime check = DateTime.now();
    for (final d in dates) {
      if (_isSameDay(d, check) || _isSameDay(d, check.subtract(const Duration(days: 1)))) {
        streak++;
        check = d.subtract(const Duration(days: 1));
      } else if (d.isBefore(check)) {
        break;
      }
    }
    return streak;
  }

  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final name = profile?.data['name'] ?? user?.name ?? 'Athlete';
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: loading
              ? const _HomeShimmer()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Hello,', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant)),
                                  Text(name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Get.toNamed('/settings'),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.surface,
                                backgroundImage: profile?.data['avatar_url'] != null && (profile?.data['avatar_url'] as String).isNotEmpty
                                    ? NetworkImage(profile!.data['avatar_url'] as String)
                                    : null,
                                child: profile?.data['avatar_url'] == null || (profile?.data['avatar_url'] as String).isEmpty
                                    ? const Icon(Icons.person, color: AppColors.onSurfaceVariant)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _QuickStatsRow(
                          workoutsThisWeek: _workoutsThisWeek,
                          totalVolume: _totalVolumeThisWeek,
                          streak: _streakDays,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: _QuickStartCard(onTap: () => Get.find<MainNavigationController>().changePage(2)),
                      ),
                    ),
                    if (recentWorkouts.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Recent Workouts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              TextButton(
                                onPressed: () => Get.find<MainNavigationController>().changePage(3),
                                child: const Text('See All', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (recentWorkouts.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _WorkoutCard(recentWorkouts[i]),
                            childCount: recentWorkouts.length,
                          ),
                        ),
                      ),
                    if (recentExercises.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                          child: Text('Your Exercises', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (recentExercises.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _ExerciseCard(recentExercises[i]),
                            childCount: recentExercises.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final int workoutsThisWeek;
  final double totalVolume;
  final int streak;
  const _QuickStatsRow({required this.workoutsThisWeek, required this.totalVolume, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MiniStatCard(label: 'This Week', value: '$workoutsThisWeek workouts', icon: Icons.calendar_today_rounded, color: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: _MiniStatCard(label: 'Volume', value: '${totalVolume.clean} lbs', icon: Icons.scale_rounded, color: const Color(0xFF4AE1C6))),
        const SizedBox(width: 10),
        Expanded(child: _MiniStatCard(label: 'Streak', value: '$streak days', icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF8C42))),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: AppColors.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickStartCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.secondaryContainer.withValues(alpha: 0.8), AppColors.primary.withValues(alpha: 0.6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.background.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.play_arrow_rounded, color: AppColors.background, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Workout', style: TextStyle(color: AppColors.background, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Tap to begin a new session', style: TextStyle(color: AppColors.background.withValues(alpha: 0.8), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.background, size: 18),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final models.Document doc;
  const _WorkoutCard(this.doc);

  @override
  Widget build(BuildContext context) {
    final started = DateTime.tryParse(doc.data['started_at']?.toString() ?? '') ?? DateTime.now();
    final completed = doc.data['completed_at'] != null ? DateTime.tryParse(doc.data['completed_at']?.toString() ?? '') : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.data['name'] ?? 'Workout', style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(started.formatted, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: completed != null ? AppColors.secondaryContainer.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              completed != null ? 'Done' : 'Active',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: completed != null ? AppColors.secondaryContainer : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final models.Document doc;
  const _ExerciseCard(this.doc);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.secondaryContainer.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.sports_gymnastics, color: AppColors.secondaryContainer, size: 20),
          ),
          const SizedBox(height: 12),
          Text(doc.data['name'] ?? 'Exercise', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(doc.data['muscle_group'] ?? 'General', style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}

class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 40, height: 14, color: AppColors.surfaceHigh),
                  const SizedBox(height: 8),
                  Container(width: 120, height: 28, color: AppColors.surfaceHigh),
                ],
              ),
            ),
            const CircleAvatar(radius: 24, backgroundColor: AppColors.surfaceHigh),
          ],
        ),
        const SizedBox(height: 32),
        Container(height: 100, decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(16))),
        const SizedBox(height: 16),
        Container(height: 100, decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(16))),
      ],
    );
  }
}
