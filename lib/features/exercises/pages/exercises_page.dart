import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repository/appwrite_repository.dart';

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  final repo = AppwriteRepository();
  List<models.Document> exercises = [];
  List<models.Document> filtered = [];
  bool loading = true;
  String search = '';
  models.User? user;

  final muscleGroups = [
    'All',
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Core',
    'Cardio',
    'Full Body',
  ];
  String selectedGroup = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      user = await repo.getCurrentUser();
      final list = await repo.getExercises(user!.$id);
      exercises = list.documents;
      _applyFilter();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  void _applyFilter() {
    filtered = exercises.where((e) {
      final name = (e.data['name'] ?? '').toString().toLowerCase();
      final group = e.data['muscle_group'] ?? '';
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
                  const Expanded(
                    child: Text('Exercises', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) {
                  search = v;
                  setState(_applyFilter);
                },
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
                      onSelected: (_) {
                        setState(() {
                          selectedGroup = g;
                          _applyFilter();
                        });
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: active ? AppColors.primary : AppColors.onSurfaceVariant,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
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
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: 6,
                      itemBuilder: (_, __) => const _ExerciseShimmer(),
                    )
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
                            itemBuilder: (ctx, i) => _ExerciseListCard(filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExercise(BuildContext context) {
    Get.to(() => const _AddExercisePage())?.then((_) => _load());
  }
}

class _ExerciseListCard extends StatelessWidget {
  final models.Document doc;
  const _ExerciseListCard(this.doc);

  @override
  Widget build(BuildContext context) {
    final img = doc.data['image_url']?.toString();
    return Container(
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
                ? CachedNetworkImage(
                    imageUrl: img,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 56, height: 56, color: AppColors.surfaceHigh),
                    errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: AppColors.surfaceHigh, child: const Icon(Icons.image, color: AppColors.onSurfaceVariant)),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.fitness_center, color: AppColors.onSurfaceVariant),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.data['name'] ?? 'Exercise', style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(doc.data['muscle_group'] ?? 'General', style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showOptions(context, doc),
            icon: const Icon(Icons.more_vert, color: AppColors.onSurfaceVariant, size: 20),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, models.Document doc) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.primary),
              title: const Text('Edit', style: TextStyle(color: AppColors.onSurface)),
              onTap: () {
                Get.back();
                Get.to(() => _EditExercisePage(doc: doc))?.then((_) {
                  if (context.mounted) (context as Element).markNeedsBuild();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Get.back();
                final exUser = await AppwriteRepository().getCurrentUser();
                await AppwriteRepository().deleteExercise(doc.$id, exUser.$id);
                if (context.mounted) {
                  final parent = context.findAncestorStateOfType<_ExercisesPageState>();
                  parent?._load();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddExercisePage extends StatefulWidget {
  const _AddExercisePage();

  @override
  State<_AddExercisePage> createState() => _AddExercisePageState();
}

class _AddExercisePageState extends State<_AddExercisePage> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String muscleGroup = 'Chest';
  File? imageFile;
  bool submitting = false;
  final groups = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core', 'Cardio', 'Full Body'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (picked != null) setState(() => imageFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => submitting = true);
    try {
      final user = await AppwriteRepository().getCurrentUser();
      String? imageUrl;
      if (imageFile != null) {
        final fileId = ID.unique();
        final file = await AppwriteRepository().uploadImage(fileId, imageFile!.path);
        imageUrl = AppwriteRepository().getFilePreview(file.$id);
      }
      await AppwriteRepository().createExercise(user!.$id, {
        'name': _nameCtrl.text.trim(),
        'muscle_group': muscleGroup,
        'notes': _notesCtrl.text.trim(),
        'image_url': imageUrl ?? '',
        'user_id': user.$id,
        'is_custom': true,
        'created_at': DateTime.now().toIso8601String(),
      });
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Failed to add exercise', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Exercise', style: TextStyle(color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Field(label: 'Exercise Name', controller: _nameCtrl, hint: 'e.g. Bench Press'),
            const SizedBox(height: 16),
            const Text('Muscle Group', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groups.map((g) {
                final active = g == muscleGroup;
                return ChoiceChip(
                  label: Text(g),
                  selected: active,
                  onSelected: (_) => setState(() => muscleGroup = g),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(color: active ? AppColors.primary : AppColors.onSurfaceVariant, fontWeight: active ? FontWeight.w600 : FontWeight.w500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: active ? AppColors.primary.withValues(alpha: 0.3) : AppColors.outlineVariant, width: 1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _Field(label: 'Notes (optional)', controller: _notesCtrl, hint: 'Form tips, variations...', maxLines: 3),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: imageFile != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(imageFile!, fit: BoxFit.cover, width: double.infinity))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, color: AppColors.onSurfaceVariant, size: 32),
                          SizedBox(height: 8),
                          Text('Tap to add image', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                    : const Text('Save Exercise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditExercisePage extends StatefulWidget {
  final models.Document doc;
  const _EditExercisePage({required this.doc});

  @override
  State<_EditExercisePage> createState() => _EditExercisePageState();
}

class _EditExercisePageState extends State<_EditExercisePage> {
  late final _nameCtrl = TextEditingController(text: widget.doc.data['name']);
  late final _notesCtrl = TextEditingController(text: widget.doc.data['notes'] ?? '');
  late String muscleGroup = widget.doc.data['muscle_group'] ?? 'Chest';
  bool submitting = false;
  final groups = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core', 'Cardio', 'Full Body'];

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => submitting = true);
    try {
      await AppwriteRepository().updateExercise(widget.doc.$id, {
        'name': _nameCtrl.text.trim(),
        'muscle_group': muscleGroup,
        'notes': _notesCtrl.text.trim(),
      }, '');
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Failed to update', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Exercise', style: TextStyle(color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Field(label: 'Exercise Name', controller: _nameCtrl, hint: 'e.g. Bench Press'),
            const SizedBox(height: 16),
            const Text('Muscle Group', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groups.map((g) {
                final active = g == muscleGroup;
                return ChoiceChip(
                  label: Text(g),
                  selected: active,
                  onSelected: (_) => setState(() => muscleGroup = g),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(color: active ? AppColors.primary : AppColors.onSurfaceVariant, fontWeight: active ? FontWeight.w600 : FontWeight.w500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: active ? AppColors.primary.withValues(alpha: 0.3) : AppColors.outlineVariant, width: 1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _Field(label: 'Notes (optional)', controller: _notesCtrl, hint: 'Form tips...', maxLines: 3),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: submitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryContainer, foregroundColor: AppColors.background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                child: submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                    : const Text('Update Exercise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  const _Field({required this.label, required this.hint, required this.controller, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _ExerciseShimmer extends StatelessWidget {
  const _ExerciseShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceHigh,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 80,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
