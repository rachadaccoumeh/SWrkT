import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appwrite/models.dart' as models;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/repository/appwrite_repository.dart';
import '../../../data/local/local_store.dart';
import '../../../data/local/sync_manager.dart';
import '../../auth/controllers/auth_controller.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final repo = AppwriteRepository();
  Map<String, dynamic>? activeWorkout;
  List<Map<String, dynamic>> exercises = [];
  List<Map<String, dynamic>> workoutSets = [];
  bool loading = true;
  String? userId;
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
      userId = u.$id;

      // Load from local first (instant)
      activeWorkout = LocalStore.instance.getActiveWorkout(userId!);
      if (activeWorkout != null) {
        workoutSets = LocalStore.instance.getSetsForWorkout(activeWorkout!['id']);
      }
      exercises = LocalStore.instance.getExercises(userId!);

      // Load weight unit preference
      final prefs = LocalStore.instance.getPrefs(userId!);
      if (prefs != null) {
        weightUnit = prefs['weightUnit'] ?? 'lbs';
      }

      // Then fetch from Appwrite in background and merge
      try {
        final remoteActive = await repo.getActiveWorkout(userId!);
        if (remoteActive.documents.isNotEmpty) {
          final rDoc = remoteActive.documents.first;
          final remoteWorkout = {
            'id': rDoc.$id,
            'remoteId': rDoc.$id,
            'userId': rDoc.data['user_id'] ?? '',
            'name': rDoc.data['name'] ?? '',
            'isActive': rDoc.data['is_active'] ?? true,
            'startedAt': rDoc.data['started_at'] ?? '',
            'completedAt': rDoc.data['completed_at'],
            'isSynced': true,
          };
          await LocalStore.instance.saveWorkout(remoteWorkout);
          activeWorkout = remoteWorkout;
          workoutSets = LocalStore.instance.getSetsForWorkout(activeWorkout!['id']);
        }
      } catch (_) {}

      try {
        final remoteEx = await repo.getExercises(userId!);
        for (final doc in remoteEx.documents) {
          await LocalStore.instance.saveExercise(_docToMap(doc));
        }
        exercises = LocalStore.instance.getExercises(userId!);
      } catch (_) {}

      if (Get.isRegistered<SyncManager>()) Get.find<SyncManager>().queueSync();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Map<String, dynamic> _docToMap(models.Document doc) {
    return {
      'id': doc.$id,
      'remoteId': doc.$id,
      'userId': doc.data['user_id'] ?? '',
      'name': doc.data['name'] ?? '',
      'muscleGroup': doc.data['muscle_group'] ?? '',
      'notes': doc.data['notes'] ?? '',
      'imageUrl': doc.data['image_url'] ?? '',
      'isSynced': true,
      'createdAt': DateTime.tryParse(doc.data['created_at'] ?? '')?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : activeWorkout == null
                ? _NoActiveWorkout(onStart: () => _startWorkout(context))
                : _ActiveWorkoutView(
                    workout: activeWorkout!,
                    sets: workoutSets,
                    exercises: exercises,
                    userId: userId!,
                    weightUnit: weightUnit,
                    onRefresh: _load,
                  ),
      ),
    );
  }

  Future<void> _startWorkout(BuildContext context) async {
    final name = TextEditingController(text: 'Workout ${DateTime.now().formatted}');
    String? workoutName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Start Workout', style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: name,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: 'Workout name',
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, name.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryContainer, foregroundColor: AppColors.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (workoutName != null && workoutName.isNotEmpty && userId != null) {
      final now = DateTime.now();
      final workout = {
        'id': 'w_${now.millisecondsSinceEpoch}_$userId',
        'userId': userId!,
        'name': workoutName,
        'isActive': true,
        'isSynced': false,
        'startedAt': now.millisecondsSinceEpoch,
        'completedAt': null,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      };
      await LocalStore.instance.saveWorkout(workout);
      activeWorkout = workout;
      workoutSets = [];
      if (Get.isRegistered<SyncManager>()) Get.find<SyncManager>().queueSync();
      if (mounted) setState(() {});
    }
  }
}

class _NoActiveWorkout extends StatelessWidget {
  final VoidCallback onStart;
  const _NoActiveWorkout({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.fitness_center_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('No Active Workout', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Start a new workout session to track your sets and reps.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Start Workout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveWorkoutView extends StatefulWidget {
  final Map<String, dynamic> workout;
  final List<Map<String, dynamic>> sets;
  final List<Map<String, dynamic>> exercises;
  final String userId;
  final String weightUnit;
  final VoidCallback onRefresh;
  const _ActiveWorkoutView({required this.workout, required this.sets, required this.exercises, required this.userId, required this.weightUnit, required this.onRefresh});

  @override
  State<_ActiveWorkoutView> createState() => _ActiveWorkoutViewState();
}

class _ActiveWorkoutViewState extends State<_ActiveWorkoutView> {
  final repo = AppwriteRepository();
  late List<Map<String, dynamic>> _sets;
  late Map<String, List<Map<String, dynamic>>> _groupedSets;
  Timer? _timer;
  Duration elapsed = Duration.zero;
  bool finishing = false;

  @override
  void initState() {
    super.initState();
    _sets = List.from(widget.sets);
    _regroup();
    final startedMs = widget.workout['startedAt'];
    if (startedMs != null) {
      final ms = startedMs is int ? startedMs : int.tryParse(startedMs.toString()) ?? 0;
      elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => elapsed = elapsed + const Duration(seconds: 1));
    });
  }

  void _regroup() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (var s in _sets) {
      final exId = (s['exerciseId'] ?? 'unknown').toString();
      map.putIfAbsent(exId, () => []).add(s);
    }
    for (var l in map.values) {
      l.sort((a, b) => ((a['setNumber'] ?? 0) as num).compareTo((b['setNumber'] ?? 0) as num));
    }
    _groupedSets = map;
  }

  String get _elapsedStr {
    final m = elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _exerciseName(String exId) {
    try {
      final ex = widget.exercises.firstWhere((e) => e['id'] == exId);
      return ex['name'] ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<void> _addSet(String exerciseId, int setNumber) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newSet = {
      'id': 's_${now}_${widget.userId}',
      'userId': widget.userId,
      'workoutId': widget.workout['id'],
      'exerciseId': exerciseId,
      'setNumber': setNumber,
      'reps': 0,
      'weight': 0.0,
      'isCompleted': false,
      'isSynced': false,
      'createdAt': now,
      'updatedAt': now,
    };
    await LocalStore.instance.saveSet(newSet);
    _sets.add(newSet);
    _regroup();
    if (mounted) setState(() {});
  }

  Future<void> _toggleSet(Map<String, dynamic> set, int index) async {
    final completed = !(set['isCompleted'] ?? false);
    final updated = {...set, 'isCompleted': completed, 'updatedAt': DateTime.now().millisecondsSinceEpoch, 'isSynced': false};
    await LocalStore.instance.saveSet(updated);
    _sets[index] = updated;
    _regroup();
    if (Get.isRegistered<SyncManager>()) Get.find<SyncManager>().queueSync();
    if (mounted) setState(() {});
  }

  Future<void> _updateSetRepsWeight(Map<String, dynamic> set, int index, int reps, double weight) async {
    final updated = {...set, 'reps': reps, 'weight': weight, 'updatedAt': DateTime.now().millisecondsSinceEpoch, 'isSynced': false};
    await LocalStore.instance.saveSet(updated);
    _sets[index] = updated;
    if (Get.isRegistered<SyncManager>()) Get.find<SyncManager>().queueSync();
  }

  Future<void> _deleteSet(Map<String, dynamic> set, int index) async {
    await LocalStore.instance.deleteSet(set['id']);
    _sets.removeAt(index);
    _regroup();
    if (mounted) setState(() {});
  }

  Future<void> _finishWorkout() async {
    if (finishing) return;
    finishing = true;
    final updated = {
      ...widget.workout,
      'isActive': false,
      'completedAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'isSynced': false,
    };
    await LocalStore.instance.saveWorkout(updated);
    if (Get.isRegistered<SyncManager>()) Get.find<SyncManager>().queueSync();
    if (mounted) {
      setState(() => finishing = false);
      widget.onRefresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupedSets;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(widget.workout['name'] ?? 'Workout', style: const TextStyle(color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                child: Text(_elapsedStr, style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
              ),
            ),
          ),
          IconButton(
            onPressed: _finishWorkout,
            icon: const Icon(Icons.check_circle, color: AppColors.secondaryContainer),
          ),
        ],
      ),
      body: groups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('Add an exercise to get started', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 15)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: groups.length + 1,
              itemBuilder: (ctx, i) {
                if (i == groups.length) {
                  return _AddExerciseCard(
                    exercises: widget.exercises,
                    existingIds: groups.keys.toList(),
                    onAdd: (exId) {
                      final nextNum = (groups[exId]?.length ?? 0) + 1;
                      _addSet(exId, nextNum);
                    },
                  );
                }
                final entry = groups.entries.elementAt(i);
                final exId = entry.key;
                final sets = entry.value;
                return _ExerciseSetGroup(
                  exerciseName: _exerciseName(exId),
                  sets: sets,
                  weightUnit: widget.weightUnit,
                  onToggle: (idx) => _toggleSet(sets[idx], _sets.indexOf(sets[idx])),
                  onUpdate: (idx, reps, weight) => _updateSetRepsWeight(sets[idx], _sets.indexOf(sets[idx]), reps, weight),
                  onDelete: (idx) => _deleteSet(sets[idx], _sets.indexOf(sets[idx])),
                  onAddSet: () => _addSet(exId, sets.length + 1),
                );
              },
            ),
    );
  }
}

class _ExerciseSetGroup extends StatelessWidget {
  final String exerciseName;
  final List<Map<String, dynamic>> sets;
  final String weightUnit;
  final Function(int) onToggle;
  final Function(int, int, double) onUpdate;
  final Function(int) onDelete;
  final VoidCallback onAddSet;
  const _ExerciseSetGroup({required this.exerciseName, required this.sets, required this.weightUnit, required this.onToggle, required this.onUpdate, required this.onDelete, required this.onAddSet});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exerciseName, style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          ...List.generate(sets.length, (i) {
            final s = sets[i];
            return _SetRow(
              setNumber: (i + 1),
              reps: (s['reps'] ?? 0) as int,
              weight: (s['weight'] ?? 0.0) as double,
              isCompleted: s['isCompleted'] ?? false,
              weightUnit: weightUnit,
              onToggle: () => onToggle(i),
              onUpdate: (r, w) => onUpdate(i, r, w),
              onDelete: () => onDelete(i),
            );
          }),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Set', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final int setNumber;
  final int reps;
  final double weight;
  final bool isCompleted;
  final String weightUnit;
  final VoidCallback onToggle;
  final Function(int, double) onUpdate;
  final VoidCallback onDelete;
  const _SetRow({required this.setNumber, required this.reps, required this.weight, required this.isCompleted, required this.weightUnit, required this.onToggle, required this.onUpdate, required this.onDelete});

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController _repsCtrl;
  late TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _repsCtrl = TextEditingController(text: widget.reps > 0 ? widget.reps.toString() : '');
    _weightCtrl = TextEditingController(text: widget.weight > 0 ? widget.weight.toString() : '');
  }

  @override
  void didUpdateWidget(_SetRow w) {
    super.didUpdateWidget(w);
    if (w.reps != widget.reps) _repsCtrl.text = widget.reps > 0 ? widget.reps.toString() : '';
    if (w.weight != widget.weight) _weightCtrl.text = widget.weight > 0 ? widget.weight.toString() : '';
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    final reps = int.tryParse(_repsCtrl.text) ?? 0;
    final weight = double.tryParse(_weightCtrl.text) ?? 0.0;
    widget.onUpdate(reps, weight);
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.setNumber.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: AppColors.error, size: 20),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.isCompleted ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.isCompleted ? AppColors.primary : AppColors.outlineVariant),
                ),
                child: widget.isCompleted ? const Icon(Icons.check, size: 18, color: AppColors.primary) : null,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(6)),
              child: Center(child: Text('${widget.setNumber}', style: const TextStyle(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _repsCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Reps',
                        hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _commit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('×', style: TextStyle(color: AppColors.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: widget.weightUnit,
                        hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _commit(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddExerciseCard extends StatelessWidget {
  final List<Map<String, dynamic>> exercises;
  final List<String> existingIds;
  final Function(String) onAdd;
  const _AddExerciseCard({required this.exercises, required this.existingIds, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final available = exercises.where((e) => !existingIds.contains(e['id'])).toList();
    if (available.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Exercise', style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: available.take(8).map((e) {
              return ActionChip(
                label: Text(e['name'] ?? '', style: const TextStyle(fontSize: 12)),
                onPressed: () => onAdd(e['id']),
                backgroundColor: AppColors.surfaceHigh,
                labelStyle: const TextStyle(color: AppColors.onSurface),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}