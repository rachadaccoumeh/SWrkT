import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:appwrite/models.dart' as models;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/repository/appwrite_repository.dart';
import '../../../data/local/local_store.dart';
import '../../../data/local/sync_manager.dart';
import '../../auth/controllers/auth_controller.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final repo = AppwriteRepository();
  List<Map<String, dynamic>> allWorkouts = [];
  List<Map<String, dynamic>> allSets = [];
  bool loading = true;
  String weightUnit = 'lbs';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final authCtrl = Get.find<AuthController>();
      var u = authCtrl.user.value;
      if (u == null) {
        u = await repo.getCurrentUser();
        authCtrl.user.value = u;
      }
      final uid = u.$id;

      // Load weight unit preference
      final prefs = LocalStore.instance.getPrefs(uid);
      weightUnit = (prefs?['weightUnit'] ?? 'lbs') as String;

      // Load from local first (instant)
      allWorkouts = LocalStore.instance.getWorkouts(uid);
      allSets = LocalStore.instance.getAllSetsForUser(uid);

      // Then sync from Appwrite in background
      try {
        final remoteWorkouts = await repo.getWorkouts(uid);
        for (final doc in remoteWorkouts.documents) {
          await LocalStore.instance.saveWorkout(_docToWorkout(doc));
        }
        final remoteSets = await repo.getAllSets(uid);
        for (final doc in remoteSets.documents) {
          await LocalStore.instance.saveSet(_docToSet(doc));
        }
        allWorkouts = LocalStore.instance.getWorkouts(uid);
        allSets = LocalStore.instance.getAllSetsForUser(uid);
      } catch (_) {}

      if (Get.isRegistered<SyncManager>()) Get.find<SyncManager>().queueSync();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Map<String, dynamic> _docToWorkout(models.Document doc) => {
    'id': doc.$id, 'remoteId': doc.$id, 'userId': doc.data['user_id'] ?? '', 'name': doc.data['name'] ?? '',
    'isActive': doc.data['is_active'] ?? false, 'isSynced': true,
    'startedAt': DateTime.tryParse(doc.data['started_at'] ?? '')?.millisecondsSinceEpoch ?? 0,
    'completedAt': doc.data['completed_at'] != null ? DateTime.tryParse(doc.data['completed_at'])?.millisecondsSinceEpoch : null,
    'createdAt': DateTime.now().millisecondsSinceEpoch, 'updatedAt': DateTime.now().millisecondsSinceEpoch,
  };

  Map<String, dynamic> _docToSet(models.Document doc) => {
    'id': doc.$id, 'remoteId': doc.$id, 'userId': doc.data['user_id'] ?? '', 'workoutId': doc.data['workout_id'] ?? '',
    'exerciseId': doc.data['exercise_id'], 'setNumber': doc.data['set_number'] ?? 0,
    'reps': doc.data['reps'] ?? 0, 'weight': (doc.data['weight'] ?? 0.0).toDouble(),
    'isCompleted': doc.data['is_completed'] ?? false, 'isSynced': true,
    'createdAt': DateTime.now().millisecondsSinceEpoch, 'updatedAt': DateTime.now().millisecondsSinceEpoch,
  };

  int get totalWorkouts => allWorkouts.where((w) => w['isActive'] != true).length;
  int get totalSets => allSets.where((s) => s['isCompleted'] == true).length;
  int get totalReps => allSets.where((s) => s['isCompleted'] == true).fold(0, (sum, s) => sum + ((s['reps'] ?? 0) as num).toInt());
  double get totalVolume => allSets.where((s) => s['isCompleted'] == true).fold(0.0, (sum, s) => sum + ((s['reps'] ?? 0) as num).toInt() * ((s['weight'] ?? 0.0) as num).toDouble());

  Map<String, int> get weeklyData {
    final now = DateTime.now();
    final map = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d.weekday - 1];
      final dayStart = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
      final dayEnd = dayStart + 86400000;
      map[key] = allWorkouts.where((w) {
        final ts = w['completedAt'] ?? w['startedAt'] ?? 0;
        return ts >= dayStart && ts < dayEnd && w['isActive'] != true;
      }).length;
    }
    return map;
  }

  Map<String, double> get prs {
    final map = <String, double>{};
    for (final s in allSets.where((s) => s['isCompleted'] == true)) {
      final exId = s['exerciseId']?.toString() ?? 'unknown';
      final w = (s['weight'] as num).toDouble();
      if (!map.containsKey(exId) || w > map[exId]!) map[exId] = w;
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
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            const Expanded(child: Text('Progress', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface))),
                            IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: _StatsGrid(count: totalWorkouts, sets: totalSets, reps: totalReps, volume: totalVolume, weightUnit: weightUnit),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _WeeklyChart(data: weeklyData),
                      ),
                    ),
                    if (prs.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: _PRSection(prs: prs, weightUnit: weightUnit),
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

class _StatsGrid extends StatelessWidget {
  final int count; final int sets; final int reps; final double volume; final String weightUnit;
  const _StatsGrid({required this.count, required this.sets, required this.reps, required this.volume, required this.weightUnit});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Workouts', count.toString(), Icons.fitness_center, AppColors.primary),
      ('Sets', sets.toString(), Icons.repeat, AppColors.secondaryContainer),
      ('Reps', reps.toString(), Icons.trending_up, const Color(0xFFFF8C42)),
      ('Volume', '${volume.clean} $weightUnit', Icons.scale, const Color(0xFF4AE1C6)),
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
  final String label; final String value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
    final maxVal = data.values.fold(1, (a, b) => a > b ? a : b);
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
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal.toDouble() + 1,
                barTouchData: BarTouchData(enabled: true, touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    '${rod.toY.toInt()} workouts', const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                )),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(keys[value.toInt()], style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
                    ),
                    reservedSize: 30,
                  )),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(keys.length, (i) => BarChartGroupData(
                  x: i,
                  barRods: [BarChartRodData(
                    toY: data[keys[i]]!.toDouble(),
                    color: AppColors.primary,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  )],
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PRSection extends StatefulWidget {
  final Map<String, double> prs;
  final String weightUnit;
  const _PRSection({required this.prs, required this.weightUnit});

  @override
  State<_PRSection> createState() => _PRSectionState();
}

class _PRSectionState extends State<_PRSection> {
  @override
  Widget build(BuildContext context) {
    final sorted = widget.prs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFF8C42).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.emoji_events, color: Color(0xFFFF8C42), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Personal Records', style: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          ...top.map((e) {
            final name = e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(name, style: const TextStyle(color: AppColors.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${e.value.toStringAsFixed(1)} ${widget.weightUnit}', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}