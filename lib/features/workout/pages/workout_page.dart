import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/appwrite.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/repository/appwrite_repository.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final repo = AppwriteRepository();
  models.Document? activeWorkout;
  List<models.Document> exercises = [];
  List<models.Document> workoutSets = [];
  bool loading = true;
  models.User? user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      user = await repo.getCurrentUser();
      final active = await repo.getActiveWorkout(user!.$id);
      if (active.documents.isNotEmpty) {
        activeWorkout = active.documents.first;
        final sets = await repo.getSets(activeWorkout!.$id);
        workoutSets = sets.documents;
      }
      final ex = await repo.getExercises(user!.$id);
      exercises = ex.documents;
    } catch (_) {}
    if (mounted) setState(() => loading = false);
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
                : ActiveWorkoutView(
                    workout: activeWorkout!,
                    sets: workoutSets,
                    exercises: exercises,
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
    if (workoutName != null && workoutName.isNotEmpty) {
      await repo.createWorkout(user!.$id, {
        'name': workoutName,
        'user_id': user!.$id,
        'started_at': DateTime.now().toIso8601String(),
        'is_active': true,
      });
      _load();
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

class ActiveWorkoutView extends StatefulWidget {
  final models.Document workout;
  final List<models.Document> sets;
  final List<models.Document> exercises;
  final VoidCallback onRefresh;
  const ActiveWorkoutView({super.key, required this.workout, required this.sets, required this.exercises, required this.onRefresh});

  @override
  State<ActiveWorkoutView> createState() => _ActiveWorkoutViewState();
}

class _ActiveWorkoutViewState extends State<ActiveWorkoutView> {
  final repo = AppwriteRepository();
  models.User? user;
  Timer? _timer;
  Duration elapsed = Duration.zero;
  bool finishing = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    final started = DateTime.tryParse(widget.workout.data['started_at']?.toString() ?? '') ?? DateTime.now();
    elapsed = DateTime.now().difference(started);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => elapsed = elapsed + const Duration(seconds: 1));
    });
  }

  Future<void> _loadUser() async {
    user = await repo.getCurrentUser();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _elapsedStr {
    final m = elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Map<String, List<models.Document>> get _groupedSets {
    final map = <String, List<models.Document>>{};
    for (var s in widget.sets) {
      final exId = s.data['exercise_id']?.toString() ?? 'unknown';
      map.putIfAbsent(exId, () => []).add(s);
    }
    for (var l in map.values) {
      l.sort((a, b) => (a.data['set_number'] ?? 0).compareTo(b.data['set_number'] ?? 0));
    }
    return map;
  }

  String _exerciseName(String exId) {
    final ex = widget.exercises.firstWhereOrNull((e) => e.$id == exId);
    return ex?.data['name'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupedSets;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(widget.workout.data['name'] ?? 'Workout', style: const TextStyle(color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                child: Text(_elapsedStr, style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])), key: const Key('elapsed')),
            ),
          ),
          IconButton(
            onPressed: _finishWorkout,
            icon: const Icon(Icons.check_circle, color: AppColors.secondaryContainer),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: groups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('Add exercises to your workout', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: groups.length,
                    itemBuilder: (ctx, i) {
                      final exId = groups.keys.elementAt(i);
                      final sets = groups[exId]!;
                      return _ExerciseSection(
                        name: _exerciseName(exId),
                        sets: sets,
                        exerciseId: exId,
                        workoutId: widget.workout.$id,
                        onRefresh: widget.onRefresh,
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _showAddExerciseSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Add Exercise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishWorkout() async {
    if (finishing) return;
    setState(() => finishing = true);
    try {
      await repo.updateWorkout(widget.workout.$id, {
        'is_active': false,
        'completed_at': DateTime.now().toIso8601String(),
      }, user!.$id);
      widget.onRefresh();
    } catch (_) {}
    if (mounted) setState(() => finishing = false);
  }

  void _showAddExerciseSheet(BuildContext context) {
    if (widget.exercises.isEmpty) {
      Get.snackbar('No exercises', 'Add exercises in the Exercises tab first.', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.surface, colorText: AppColors.onSurface);
      return;
    }
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),
            const Text('Select Exercise', style: TextStyle(color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.exercises.length,
                itemBuilder: (ctx, i) {
                  final ex = widget.exercises[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(ex.data['name'] ?? 'Exercise', style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text(ex.data['muscle_group'] ?? '', style: const TextStyle(color: AppColors.onSurfaceVariant)),
                    trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    onTap: () async {
                      Get.back();
                      await _addSet(ex.$id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _addSet(String exerciseId) async {
    try {
      final existing = widget.sets.where((s) => s.data['exercise_id'] == exerciseId).toList();
      final setNum = existing.length + 1;
      final user = await repo.getCurrentUser();
      await repo.createSet(user.$id, {
        'workout_id': widget.workout.$id,
        'exercise_id': exerciseId,
        'user_id': user.$id,
        'set_number': setNum,
        'reps': 0,
        'weight': 0.0,
        'is_completed': false,
        'recorded_at': DateTime.now().toIso8601String(),
      });
      widget.onRefresh();
    } catch (_) {}
  }
}

class _ExerciseSection extends StatefulWidget {
  final String name;
  final List<models.Document> sets;
  final String exerciseId;
  final String workoutId;
  final VoidCallback onRefresh;
  const _ExerciseSection({required this.name, required this.sets, required this.exerciseId, required this.workoutId, required this.onRefresh});

  @override
  State<_ExerciseSection> createState() => _ExerciseSectionState();
}

class _ExerciseSectionState extends State<_ExerciseSection> {
  final repo = AppwriteRepository();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.name, style: const TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  IconButton(
                    onPressed: _addSet,
                    icon: const Icon(Icons.add, color: AppColors.primary, size: 20),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: _deleteExercise,
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: Text('Set', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: Text('Reps', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: Text('Weight', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600))),
              const SizedBox(width: 32),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(widget.sets.length, (i) => _SetRow(set: widget.sets[i], onRefresh: widget.onRefresh)),
        ],
      ),
    );
  }

  Future<void> _addSet() async {
    try {
      final user = await repo.getCurrentUser();
      await repo.createSet(user.$id, {
        'workout_id': widget.workoutId,
        'exercise_id': widget.exerciseId,
        'user_id': user.$id,
        'set_number': widget.sets.length + 1,
        'reps': 0,
        'weight': 0.0,
        'is_completed': false,
        'recorded_at': DateTime.now().toIso8601String(),
      });
      widget.onRefresh();
    } catch (_) {}
  }

  Future<void> _deleteExercise() async {
    final currentUser = await repo.getCurrentUser();
    for (var s in widget.sets) {
      await repo.deleteSet(s.$id, currentUser.$id);
    }
    widget.onRefresh();
  }
}

class _SetRow extends StatefulWidget {
  final models.Document set;
  final VoidCallback onRefresh;
  const _SetRow({required this.set, required this.onRefresh});

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  final repo = AppwriteRepository();
  late final _repsCtrl = TextEditingController(text: widget.set.data['reps']?.toString() ?? '0');
  late final _weightCtrl = TextEditingController(text: widget.set.data['weight']?.toString() ?? '0');
  late bool completed = widget.set.data['is_completed'] ?? false;

  @override
  void dispose() {
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    try {
      final reps = int.tryParse(_repsCtrl.text) ?? 0;
      final weight = double.tryParse(_weightCtrl.text) ?? 0;
      final user = await repo.getCurrentUser();
      await repo.updateSet(widget.set.$id, {
        'reps': reps,
        'weight': weight,
        'is_completed': completed,
      }, user.$id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('${widget.set.data['set_number']}', style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: _MiniField(
              controller: _repsCtrl,
              onChanged: () => _update(),
            ),
          ),
          Expanded(
            flex: 3,
            child: _MiniField(
              controller: _weightCtrl,
              onChanged: () => _update(),
              suffix: ' lbs',
            ),
          ),
          SizedBox(
            width: 32,
            child: Checkbox(
              value: completed,
              onChanged: (v) {
                setState(() => completed = v ?? false);
                _update();
              },
              activeColor: AppColors.secondaryContainer,
              side: const BorderSide(color: AppColors.outlineVariant),
            ),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              onPressed: () async {
                final currentUser = await repo.getCurrentUser();
              await repo.deleteSet(widget.set.$id, currentUser.$id);
                widget.onRefresh();
              },
              icon: const Icon(Icons.close, color: AppColors.error, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onChanged;
  final String? suffix;
  const _MiniField({required this.controller, this.onChanged, this.suffix});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}
