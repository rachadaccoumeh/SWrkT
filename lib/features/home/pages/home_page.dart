import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/appwrite.dart';
import '../../../core/theme/app_colors.dart';
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
      recentWorkouts = workouts.documents.where((w) => !(w.data['is_active'] ?? false)).take(5).toList();
      final exercises = await repo.getExercises(user!.$id);
      recentExercises = exercises.documents.take(5).toList();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

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
                                child: profile?.data['avatar_url'] != null && (profile?.data['avatar_url'] as String).isNotEmpty
                                    ? null
                                    : const Icon(Icons.person, color: AppColors.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
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
                                onPressed: () => Get.toNamed('/workout-history'),
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
