import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/appwrite.dart';
import 'dart:math';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/repository/appwrite_repository.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> with SingleTickerProviderStateMixin {
  final repo = AppwriteRepository();
  List<models.Document> workouts = [];
  List<models.Document> sets = [];
  List<models.Document> exercises = [];
  bool loading = true;
  late TabController _tabCtrl;
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = await repo.getCurrentUser();
      final w = await repo.getWorkouts(user.$id);
      workouts = w.documents.where((d) => d.data['is_active'] == false).toList();
      final e = await repo.getExercises(user.$id);
      exercises = e.documents;
      final s = await repo.getAllSets(user.$id);
      sets = s.documents;
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  int get workoutCount => workouts.length;
  int get totalSets => sets.where((s) => s.data['is_completed'] == true).length;
  int get totalReps => sets.where((s) => s.data['is_completed'] == true).fold(0, (sum, s) => sum + ((s.data['reps'] ?? 0) as num).toInt());
  double get totalVolume => sets.where((s) => s.data['is_completed'] == true).fold(0.0, (sum, s) => sum + ((s.data['reps'] ?? 0) as num).toInt() * ((s.data['weight'] ?? 0.0) as num).toDouble());

  int get streakDays {
    if (workouts.isEmpty) return 0;
    final dates = workouts.map((w) {
      final s = w.data['completed_at'] ?? w.data['started_at'];
      return DateTime.tryParse(s?.toString() ?? '') ?? DateTime.now();
    }).map((d) => DateTime(d.year, d.month, d.day)).toSet().toList();
    dates.sort((a, b) => b.compareTo(a));
    int streak = 0;
    DateTime check = DateTime.now();
    for (final d in dates) {
      if (d.isAtSameDay(check) || d.isAtSameDay(check.subtract(const Duration(days: 1)))) {
        streak++;
        check = d.subtract(const Duration(days: 1));
      } else if (d.isBefore(check)) {
        break;
      }
    }
    return streak;
  }

  Map<String, int> get workoutsByDay {
    final map = <String, int>{};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      map[day.weekdayShort.substring(0, 1)] = 0;
    }
    for (final w in workouts) {
      final s = w.data['completed_at'] ?? w.data['started_at'];
      final d = DateTime.tryParse(s?.toString() ?? '');
      if (d == null) continue;
      final diff = now.difference(d).inDays;
      if (diff < 7) {
        final key = d.weekdayShort.substring(0, 1);
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progress', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.local_fire_department, color: Color(0xFFFF8C42), size: 18),
                              const SizedBox(width: 4),
                              Text('$streakDays day streak', style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _StatsGrid(
                              count: workoutCount,
                              sets: totalSets,
                              reps: totalReps,
                              volume: totalVolume,
                            ),
                            const SizedBox(height: 24),
                            _WeeklyChart(data: workoutsByDay),
                            const SizedBox(height: 24),
                            _RecentPRs(sets: sets, exercises: exercises),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int count;
  final int sets;
  final int reps;
  final double volume;
  const _StatsGrid({required this.count, required this.sets, required this.reps, required this.volume});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Workouts', count.toString(), Icons.fitness_center, AppColors.primary),
      ('Sets', sets.toString(), Icons.repeat, AppColors.secondaryContainer),
      ('Reps', reps.toString(), Icons.trending_up, const Color(0xFFFF8C42)),
      ('Volume', '${volume.clean} lbs', Icons.scale, const Color(0xFF4AE1C6)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: stats.map((s) => _StatCard(label: s.$1, value: s.$2, icon: s.$3, color: s.$4)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: AppColors.onSurface, fontSize: 20, fontWeight: FontWeight.w700)),
              Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final Map<String, int> data;
  const _WeeklyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final keys = data.keys.toList();
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Activity', style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: max(maxVal.toDouble(), 1),
                barGroups: List.generate(keys.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[keys[i]]!.toDouble(),
                        color: data[keys[i]]! > 0 ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.3),
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  );
                }),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= keys.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(keys[idx], style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPRs extends StatelessWidget {
  final List<models.Document> sets;
  final List<models.Document> exercises;
  const _RecentPRs({required this.sets, required this.exercises});

  @override
  Widget build(BuildContext context) {
    final prs = <String, double>{};
    for (final s in sets) {
      if (s.data['is_completed'] != true) continue;
      final exId = s.data['exercise_id']?.toString();
      final w = (s.data['weight'] ?? 0.0) as num;
      if (exId != null && w.toDouble() > (prs[exId] ?? 0.0)) prs[exId] = w.toDouble();
    }
    final sorted = prs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Personal Records', style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...top.map((e) {
          final ex = exercises.firstWhereOrNull((x) => x.$id == e.key);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFF8C42).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.emoji_events, color: Color(0xFFFF8C42), size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(ex?.data['name'] ?? 'Unknown', style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
                ),
                Text('${e.value.clean} lbs', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

extension DateTimeExt on DateTime {
  bool isAtSameDay(DateTime other) => year == other.year && month == other.month && day == other.day;
}
