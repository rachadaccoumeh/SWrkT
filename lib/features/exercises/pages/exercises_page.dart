import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appwrite/models.dart' as models;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/debug_log.dart';
import '../../../data/repository/appwrite_repository.dart';
import '../../../data/local/local_store.dart';
import '../../../data/local/sync_manager.dart';
import '../../auth/controllers/auth_controller.dart';

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  final repo = AppwriteRepository();
  List<Map<String, dynamic>> exercises = [];
  List<Map<String, dynamic>> filtered = [];
  bool loading = true;
  String search = '';
  models.User? user;

  final muscleGroups = [
    'All', 'Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core', 'Cardio', 'Full Body',
  ];
  String selectedGroup = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = DebugLog.instance;
    log.ui('ExercisesPage _load() started');
    try {
      final authCtrl = Get.find<AuthController>();
      user = authCtrl.user.value;
      if (user == null) {
        log.auth('No user in AuthController, fetching from Appwrite');
        user = await repo.getCurrentUser();
        authCtrl.user.value = user;
      }
      if (user == null) {
        log.error('Still no user after getCurrentUser - redirecting to login');
        Get.offAllNamed('/login');
        return;
      }
      final uid = user!.$id;
      log.ui('ExercisesPage userId: $uid');

      // Load from local first (instant)
      final local = LocalStore.instance.getExercises(uid);
      log.db('Local exercises: ${local.length}');
      if (local.isNotEmpty) {
        exercises = local;
        _applyFilter();
      }

      // Then fetch from Appwrite and merge
      try {
        log.ui('Fetching exercises from Appwrite');
        final remote = await repo.getExercises(uid);
        log.db('Remote exercises: ${remote.documents.length}');
        for (final doc in remote.documents) {
          final ex = _docToMap(doc);
          await LocalStore.instance.saveExercise(ex);
        }
        exercises = LocalStore.instance.getExercises(uid);
        log.db('Merged exercises: ${exercises.length}');
        _applyFilter();
      } catch (e) {
        log.error('Failed to fetch remote exercises', data: e.toString());
      }

      // Start background sync
      if (Get.isRegistered<SyncManager>()) {
        log.sync('Calling queueSync() from _load()');
        Get.find<SyncManager>().queueSync();
      }
    } catch (e) {
      log.error('ExercisesPage _load() failed', data: e.toString());
    }
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

  void _applyFilter() {
    filtered = exercises.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final group = e['muscleGroup'] ?? '';
      final matchesSearch = name.contains(search.toLowerCase());
      final matchesGroup = selectedGroup == 'All' || group == selectedGroup;
      return matchesSearch && matchesGroup;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExercise(context),
        backgroundColor: AppColors.secondaryContainer,
        icon: const Icon(Icons.add, color: AppColors.background),
        label: const Text('Add Exercise', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Exercises', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface))),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) { search = v; setState(_applyFilter); },
                style: const TextStyle(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search exercises...',
                  hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant, size: 20),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: muscleGroups.length,
                itemBuilder: (ctx, i) {
                  final g = muscleGroups[i];
                  final active = g == selectedGroup;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: active,
                      onSelected: (_) => setState(() { selectedGroup = g; _applyFilter(); }),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(color: active ? AppColors.primary : AppColors.onSurfaceVariant, fontWeight: active ? FontWeight.w600 : FontWeight.w500, fontSize: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: active ? AppColors.primary.withValues(alpha: 0.3) : AppColors.outlineVariant, width: 1),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: loading
                  ? ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: 6, itemBuilder: (_, __) => const _ExerciseShimmer())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fitness_center_outlined, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text('No exercises yet', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 15)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => _ExerciseListCard(filtered[i], onDelete: () => _deleteExercise(i)),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExercise(BuildContext context) {
    final uid = user?.$id ?? '';
    if (uid.isEmpty) { Get.snackbar('Error', 'Not logged in'); return; }
    Get.to(() => _AddExercisePage(uid: uid))?.then((_) => _load());
  }

  Future<void> _deleteExercise(int index) async {
    final ex = filtered[index];
    await LocalStore.instance.deleteExercise(ex['id']);
    // Also delete from Appwrite
    try {
      await repo.deleteExercise(ex['id'], ex['userId'] ?? user?.$id ?? '');
    } catch (_) {}
    filtered.removeAt(index);
    exercises.removeWhere((e) => e['id'] == ex['id']);
    if (mounted) setState(() {});
  }
}

class _ExerciseListCard extends StatelessWidget {
  final Map<String, dynamic> ex;
  final VoidCallback onDelete;
  const _ExerciseListCard(this.ex, {required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final img = ex['imageUrl']?.toString();
    return Dismissible(
      key: Key(ex['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Delete Exercise', style: TextStyle(color: AppColors.onSurface)),
            content: Text('Delete "${ex['name']}"?', style: const TextStyle(color: AppColors.onSurfaceVariant)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: img != null && img.isNotEmpty
                  ? CachedNetworkImage(imageUrl: img, width: 56, height: 56, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(width: 56, height: 56, color: AppColors.surfaceHigh),
                      errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: AppColors.surfaceHigh, child: const Icon(Icons.image, color: AppColors.onSurfaceVariant)))
                  : Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.fitness_center, color: AppColors.onSurfaceVariant)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex['name'] ?? 'Exercise', style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(ex['muscleGroup'] ?? 'General', style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            if (!(ex['isSynced'] ?? true))
              const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.cloud_off, size: 14, color: AppColors.onSurfaceVariant)),
            IconButton(
              onPressed: () {
                Get.bottomSheet(
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 20),
                        ListTile(
                          leading: const Icon(Icons.edit, color: AppColors.primary),
                          title: const Text('Edit', style: TextStyle(color: AppColors.onSurface)),
                          onTap: () { Get.back(); Get.to(() => _EditExercisePage(ex: ex))?.then((_) { }); },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete, color: AppColors.error),
                          title: const Text('Delete', style: TextStyle(color: AppColors.error)),
                          onTap: () { Get.back(); onDelete(); },
                        ),
                      ],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.more_vert, color: AppColors.onSurfaceVariant, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddExercisePage extends StatefulWidget {
  final String uid;
  const _AddExercisePage({required this.uid});

  @override
  State<_AddExercisePage> createState() => _AddExercisePageState();
}

class _AddExercisePageState extends State<_AddExercisePage> {
  final nameController = TextEditingController();
  final notesController = TextEditingController();
  String selectedMuscle = 'Chest';
  String? imageUrl;
  File? pickedImage;
  bool saving = false;

  final muscleGroups = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core', 'Cardio', 'Full Body'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (img != null) {
      pickedImage = File(img.path);
      try {
        final repo = AppwriteRepository();
        final id = 'img_${DateTime.now().millisecondsSinceEpoch}';
        final file = await repo.uploadImage(id, img.path);
        imageUrl = repo.getFilePreview(file.$id);
      } catch (_) {}
      if (mounted) setState(() {});
    }
  }

  Future<void> _save() async {
    final log = DebugLog.instance;
    if (nameController.text.trim().isEmpty) return;
    setState(() => saving = true);
    log.ui('_save() called for new exercise');
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = 'ex_${now}_${widget.uid}';
      log.db('Creating exercise with id: $id, userId: ${widget.uid}');

      final ex = {
        'id': id,
        'remoteId': '',
        'userId': widget.uid,
        'name': nameController.text.trim(),
        'muscleGroup': selectedMuscle,
        'notes': notesController.text.trim(),
        'imageUrl': imageUrl ?? '',
        'isSynced': false,
        'createdAt': now,
        'updatedAt': now,
      };
      await LocalStore.instance.saveExercise(ex);
      log.db('Exercise saved to local store');

      if (Get.isRegistered<SyncManager>()) {
        log.sync('Calling queueSync() from _save()');
        Get.find<SyncManager>().queueSync();
      } else {
        log.sync('SyncManager not registered!');
      }
      Get.back();
    } catch (e) {
      log.error('_save() failed', data: e.toString());
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Add Exercise', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [TextButton(onPressed: saving ? null : _save, child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4))),
                child: pickedImage != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(pickedImage!, fit: BoxFit.cover))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('Add Photo', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13)),
                      ]),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: InputDecoration(labelText: 'Exercise Name', labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
                  filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 16),
            const Text('Muscle Group', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: muscleGroups.map((g) {
              final selected = g == selectedMuscle;
              return ChoiceChip(
                label: Text(g),
                selected: selected,
                onSelected: (_) => setState(() => selectedMuscle = g),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(color: selected ? AppColors.primary : AppColors.onSurfaceVariant, fontSize: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: selected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.outlineVariant),
              );
            }).toList()),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: InputDecoration(labelText: 'Notes (optional)', labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
                  filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditExercisePage extends StatefulWidget {
  final Map<String, dynamic> ex;
  const _EditExercisePage({required this.ex});

  @override
  State<_EditExercisePage> createState() => _EditExercisePageState();
}

class _EditExercisePageState extends State<_EditExercisePage> {
  late TextEditingController nameController;
  late TextEditingController notesController;
  late String selectedMuscle;
  String? imageUrl;
  File? pickedImage;
  bool saving = false;

  final muscleGroups = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core', 'Cardio', 'Full Body'];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.ex['name'] ?? '');
    notesController = TextEditingController(text: widget.ex['notes'] ?? '');
    selectedMuscle = widget.ex['muscleGroup'] ?? 'Chest';
    imageUrl = widget.ex['imageUrl'];
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (img != null) {
      pickedImage = File(img.path);
      try {
        final repo = AppwriteRepository();
        final id = 'img_${DateTime.now().millisecondsSinceEpoch}';
        final file = await repo.uploadImage(id, img.path);
        imageUrl = repo.getFilePreview(file.$id);
      } catch (_) {}
      if (mounted) setState(() {});
    }
  }

  Future<void> _save() async {
    if (nameController.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      final updated = {
        ...widget.ex,
        'name': nameController.text.trim(),
        'muscleGroup': selectedMuscle,
        'notes': notesController.text.trim(),
        'imageUrl': imageUrl ?? '',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'isSynced': false,
      };
      await LocalStore.instance.saveExercise(updated);
      if (Get.isRegistered<SyncManager>()) Get.find<SyncManager>().queueSync();
      Get.back();
    } catch (_) {}
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        title: const Text('Edit Exercise', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [TextButton(onPressed: saving ? null : _save, child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4))),
                child: pickedImage != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(pickedImage!, fit: BoxFit.cover))
                    : imageUrl != null && imageUrl!.isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(16), child: CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _imagePlaceholder()))
                        : _imagePlaceholder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: InputDecoration(labelText: 'Exercise Name', labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
                  filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 16),
            const Text('Muscle Group', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: muscleGroups.map((g) {
              final selected = g == selectedMuscle;
              return ChoiceChip(
                label: Text(g),
                selected: selected,
                onSelected: (_) => setState(() => selectedMuscle = g),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(color: selected ? AppColors.primary : AppColors.onSurfaceVariant, fontSize: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: selected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.outlineVariant),
              );
            }).toList()),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: InputDecoration(labelText: 'Notes (optional)', labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
                  filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.onSurfaceVariant),
      const SizedBox(height: 8),
      Text('Change Photo', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13)),
    ]);
}

class _ExerciseShimmer extends StatelessWidget {
  const _ExerciseShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceHigh,
      child: Container(
        height: 84,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}