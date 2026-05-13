import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repository/appwrite_repository.dart';
import '../../auth/controllers/auth_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final repo = AppwriteRepository();
  models.User? user;
  models.Document? profile;
  models.Document? prefsDoc;
  bool loading = true;
  bool darkMode = true;
  String weightUnit = 'lbs';
  File? selectedImage;
  bool saving = false;

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
      final p = await repo.getPreferences(user!.$id);
      if (p.documents.isNotEmpty) {
        prefsDoc = p.documents.first;
        darkMode = prefsDoc!.data['dark_mode'] ?? true;
        weightUnit = prefsDoc!.data['weight_unit'] ?? 'lbs';
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _savePreferences() async {
    if (prefsDoc == null) return;
    try {
      await repo.updatePreference(prefsDoc!.$id, {
        'dark_mode': darkMode,
        'weight_unit': weightUnit,
      }, user!.$id);
    } catch (_) {}
  }

  Future<void> _updateName() async {
    if (profile == null) return;
    final ctrl = TextEditingController(text: profile!.data['name'] ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Name', style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryContainer, foregroundColor: AppColors.background),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await repo.updateUserProfile(profile!.$id, {'name': newName}, user!.$id);
      _load();
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400);
    if (picked == null || profile == null) return;
    setState(() => saving = true);
    try {
      final fileId = ID.unique();
      final file = await repo.uploadImage(fileId, picked.path);
      final url = repo.getFilePreview(file.$id);
      await repo.updateUserProfile(profile!.$id, {'avatar_url': url}, user!.$id);
      _load();
    } catch (_) {
      Get.snackbar('Error', 'Failed to upload image', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password', style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PwField(controller: oldCtrl, hint: 'Current password'),
            const SizedBox(height: 12),
            _PwField(controller: newCtrl, hint: 'New password'),
            const SizedBox(height: 12),
            _PwField(controller: confirmCtrl, hint: 'Confirm new password'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant))),
          ElevatedButton(
            onPressed: () {
              if (newCtrl.text.length < 8) {
                Get.snackbar('Error', 'Password must be 8+ characters', snackPosition: SnackPosition.BOTTOM);
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                Get.snackbar('Error', 'Passwords do not match', snackPosition: SnackPosition.BOTTOM);
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryContainer, foregroundColor: AppColors.background),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        await repo.account.updatePassword(password: newCtrl.text, oldPassword: oldCtrl.text);
        Get.snackbar('Success', 'Password updated', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.surface, colorText: AppColors.onSurface);
      } on AppwriteException catch (e) {
        Get.snackbar('Error', e.message ?? 'Failed to update password', snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = profile?.data['name'] ?? user?.name ?? 'User';
    final email = user?.email ?? '';
    final avatar = profile?.data['avatar_url']?.toString() ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    const SizedBox(height: 24),
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: AppColors.surface,
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty ? const Icon(Icons.person, size: 40, color: AppColors.onSurfaceVariant) : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndUploadAvatar,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(24)),
                                child: saving
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                                    : const Icon(Icons.camera_alt, color: AppColors.background, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface))),
                    Center(child: Text(email, style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant))),
                    const SizedBox(height: 32),
                    _Section(title: 'ACCOUNT', children: [
                      _Tile(icon: Icons.person_outline, label: 'Edit Name', onTap: _updateName),
                      _Tile(icon: Icons.password, label: 'Change Password', onTap: _changePassword),
                    ]),
                    const SizedBox(height: 24),
                    _Section(title: 'PREFERENCES', children: [
                      SwitchListTile(
                        value: darkMode,
                        onChanged: (v) {
                          setState(() => darkMode = v);
                          _savePreferences();
                        },
                        activeColor: AppColors.secondaryContainer,
                        title: const Text('Dark Mode', style: TextStyle(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
                        secondary: const Icon(Icons.dark_mode, color: AppColors.primary),
                      ),
                      ListTile(
                        leading: const Icon(Icons.scale, color: AppColors.primary),
                        title: const Text('Weight Unit', style: TextStyle(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _UnitChip(label: 'lbs', active: weightUnit == 'lbs', onTap: () {
                              setState(() => weightUnit = 'lbs');
                              _savePreferences();
                            }),
                            const SizedBox(width: 8),
                            _UnitChip(label: 'kg', active: weightUnit == 'kg', onTap: () {
                              setState(() => weightUnit = 'kg');
                              _savePreferences();
                            }),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _Section(title: 'ABOUT', children: [
                      const _Tile(icon: Icons.info_outline, label: 'Version 1.0.0'),
                    ]),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Get.find<AuthController>().logout(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A1A1A),
                          foregroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Sign Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.08)),
        ),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Tile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(label, style: const TextStyle(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: onTap != null ? const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant, size: 20) : null,
      onTap: onTap,
    );
  }
}

class _UnitChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _UnitChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.3) : AppColors.outlineVariant),
        ),
        child: Text(label, style: TextStyle(color: active ? AppColors.primary : AppColors.onSurfaceVariant, fontWeight: active ? FontWeight.w600 : FontWeight.w500, fontSize: 13)),
      ),
    );
  }
}

class _PwField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _PwField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
