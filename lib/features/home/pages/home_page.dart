import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appwrite/models.dart' as models;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/repository/appwrite_repository.dart';
import '../../../data/local/local_store.dart';
import '../../../data/local/sync_manager.dart';
import '../../main_navigation/pages/main_navigation_page.dart';
import '../../auth/controllers/auth_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final repo = AppwriteRepository();
  models.User? user;
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> allWorkouts = [];
  List<Map<String, dynamic>> recentWorkouts = [];
  List<Map<String, dynamic>> recentExercises = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final authCtrl = Get.find<AuthController>();
      user = authCtrl.user.value;
      if (user == null) {
        user = await repo.getCurrentUser();
        authCtrl.user.value = user;
      }
      final uid = user!.$id;

      // Load from local first (instant)
      profile = LocalStore.instance.getProfile(uid);
      allWorkouts = LocalStore.instance.getWorkouts(uid);
      recentWorkouts = allWorkouts.where((w) => w['isActive'] != true).take(5).toList();
      recentExercises = LocalStore.instance.getExercises(uid).take(5).toList();

      // Then sync from Appwrite in background
      try {
        final remoteProfiles = await repo.getUserProfile(uid);
        if (remoteProfiles.documents.isNotEmpty) {
          final doc = remoteProfiles.documents.first;
          profile = {
            'id': doc.$id,
            'remoteId': doc.$id,
            'userId': doc.data['user_id'] ?? '',
            'name': doc.data['name'] ?? '',
            'email': doc.data['email'] ?? '',
            'avatarUrl': doc.data['avatar_url'] ?? '',
            'isSynced': true,
          };
          await LocalStore.instance.saveProfile(profile!);
        }
        final remoteWorkouts = await repo.getWorkouts(uid);
        for (final doc in remoteWorkouts.documents) {
          await LocalStore.instance.saveWorkout(_docToWorkout(doc));
        }
        final remoteEx = await repo.getExercises(uid);
        for (final doc in remoteEx.documents) {
          await LocalStore.instance.saveExercise(_docToExercise(doc));
        }
        allWorkouts = LocalStore.instance.getWorkouts(uid);
        recentWorkouts = allWorkouts.where((w) => w['isActive'] != true).take(5).toList();
        recentExercises = LocalStore.instance.getExercises(uid).take(5).toList();
      } catch (_) {}

      if (Get.isRegistered<SyncManager>()) Get.find<SyncManager>().queueSync();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Map<String, dynamic> _docToWorkout(models.Document doc) {
    return {
      'id': doc.$id,
      'remoteId': doc.$id,
      'userId': doc.data['user_id'] ?? '',
      'name': doc.data['name'] ?? '',
      'isActive': doc.data['is_active'] ?? false,
      'isSynced': true,
      'startedAt': DateTime.tryParse(doc.data['started_at'] ?? '')?.millisecondsSinceEpoch ?? 0,
      'completedAt': doc.data['completed_at'] != null ? DateTime.tryParse(doc.data['completed_at'])?.millisecondsSinceEpoch : null,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _docToExercise(models.Document doc) {
    return {
      'id': doc.$id,
      'remoteId': doc.$id,
      'userId': doc.data['user_id'] ?? '',
      'name': doc.data['name'] ?? '',
      'muscleGroup': doc.data['muscle_group'] ?? '',
      'notes': doc.data['notes'] ?? '',
      'imageUrl': doc.data['image_url'] ?? '',
      'isSynced': true,
      'createdAt': DateTime.tryParse(doc.data['created_at'] ?? '')?.millisecondsSinceEpoch ?? 0,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  int get _workoutsThisWeek {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    return allWorkouts.where((w) => (w['completedAt'] ?? w['startedAt'] ?? 0) >= weekAgo && w['isActive'] != true).length;
  }

  double get _totalVolumeThisWeek {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    double vol = 0;
    for (final w in allWorkouts) {
      final ts = w['completedAt'] ?? w['startedAt'] ?? 0;
      if (ts < weekAgo || w['isActive'] == true) continue;
      final sets = LocalStore.instance.getSetsForWorkout(w['id']);
      for (final s in sets) {
        if (s['isCompleted'] == true) {
          vol += ((s['reps'] ?? 0) as num).toInt() * ((s['weight'] ?? 0.0) as num).toDouble();
        }
      }
    }
    return vol;
  }

  int get _streakDays {
    if (allWorkouts.isEmpty) return 0;
    final completed = allWorkouts.where((w) => w['isActive'] != true).toList();
    if (completed.isEmpty) return 0;
    final dates = completed.map((w) {
      final ts = w['completedAt'] ?? w['startedAt'] ?? 0;
      final d = DateTime.fromMillisecondsSinceEpoch(ts as int);
      return DateTime(d.year, d.month, d.day);
    }).toSet().toList()..sort((a, b) => b.compareTo(a));
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
    final name = profile?['name'] ?? user?.name ?? 'Athlete';
    final avatarUrl = profile?['avatarUrl']?.toString();
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                                child: avatarUrl == null || avatarUrl.isEmpty ? const Icon(Icons.person, color: AppColors.onSurfaceVariant) : null,
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
  final Map<String, dynamic> workout;
  const _WorkoutCard(this.workout);

  @override
  Widget build(BuildContext context) {
    final startedMs = workout['startedAt'] as int? ?? 0;
    final started = DateTime.fromMillisecondsSinceEpoch(startedMs);
    final completedMs = workout['completedAt'] as int?;
    final completed = completedMs != null ? DateTime.fromMillisecondsSinceEpoch(completedMs) : null;
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
                Text(workout['name']?.toString() ?? 'Workout', style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(completed != null ? completed.formatted : started.formatted, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          if (workout['isSynced'] != true)
            const Icon(Icons.cloud_off, size: 14, color: AppColors.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> ex;
  const _ExerciseCard(this.ex);

  @override
  Widget build(BuildContext context) {
    final img = ex['imageUrl']?.toString();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: img != null && img.isNotEmpty
                  ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, width: double.infinity,
                      placeholder: (_, __) => Container(color: AppColors.surfaceHigh, child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
                      errorWidget: (_, __, ___) => Container(color: AppColors.surfaceHigh, child: const Icon(Icons.fitness_center, color: AppColors.onSurfaceVariant)))
                  : Container(color: AppColors.surfaceHigh, child: const Center(child: Icon(Icons.fitness_center, color: AppColors.onSurfaceVariant, size: 32))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ex['name']?.toString() ?? 'Exercise', style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(ex['muscleGroup']?.toString() ?? 'General', style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}