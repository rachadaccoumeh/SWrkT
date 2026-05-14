import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appwrite/models.dart' as models;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/debug_log.dart';
import '../../../data/repository/appwrite_repository.dart';
import '../../../data/local/local_store.dart';
import '../../../data/local/sync_manager.dart';
import '../../auth/controllers/auth_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final repo = AppwriteRepository();
  models.User? user;
  Map<String, dynamic>? localProfile;
  Map<String, dynamic>? localPrefs;
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
      final uid = user!.$id;

      // Load local first (instant)
      localProfile = LocalStore.instance.getProfile(uid);
      localPrefs = LocalStore.instance.getPrefs(uid);
      if (localPrefs != null) {
        darkMode = localPrefs!['darkMode'] ?? true;
        weightUnit = localPrefs!['weightUnit'] ?? 'lbs';
        Get.changeThemeMode(darkMode ? ThemeMode.dark : ThemeMode.light);
      }

      // Then sync from Appwrite
      try {
        final remoteProfiles = await repo.getUserProfile(uid);
        if (remoteProfiles.documents.isNotEmpty) {
          final doc = remoteProfiles.documents.first;
          localProfile = {
            'id': doc.$id,
            'userId': uid,
            'name': doc.data['name'] ?? '',
            'email': doc.data['email'] ?? '',
            'avatarUrl': doc.data['avatar_url'] ?? '',
            'isSynced': true,
          };
          await LocalStore.instance.saveProfile(localProfile!);
        }
        final p = await repo.getPreferences(uid);
        if (p.documents.isNotEmpty) {
          final doc = p.documents.first;
          localPrefs = {
            'id': doc.$id,
            'userId': uid,
            'darkMode': doc.data['dark_mode'] ?? true,
            'weightUnit': doc.data['weight_unit'] ?? 'lbs',
            'isSynced': true,
          };
          await LocalStore.instance.savePrefs(localPrefs!);
          darkMode = localPrefs!['darkMode'] ?? true;
          weightUnit = localPrefs!['weightUnit'] ?? 'lbs';
          Get.changeThemeMode(darkMode ? ThemeMode.dark : ThemeMode.light);
        }
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _savePreferences() async {
    if (user == null) return;
    final uid = user!.$id;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = {
      'id': localPrefs?['id'] ?? 'prefs_$uid',
      'userId': uid,
      'darkMode': darkMode,
      'weightUnit': weightUnit,
      'isSynced': false,
      'updatedAt': now,
    };
    await LocalStore.instance.savePrefs(updated);

    // Save to SharedPreferences for startup
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', darkMode);
    await prefs.setString('weight_unit', weightUnit);

    if (Get.isRegistered<SyncManager>()) Get.find<SyncManager>().queueSync();
    Get.snackbar('Saved', 'Preferences updated', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.surface, colorText: AppColors.onSurface);
  }

  Widget _syncStatus() {
    if (!Get.isRegistered<SyncManager>()) return const SizedBox.shrink();
    final sync = Get.find<SyncManager>();
    return Obx(() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(sync.isOnline.value ? Icons.cloud_done : Icons.cloud_off, color: sync.isOnline.value ? AppColors.primary : AppColors.onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sync.isOnline.value ? 'Online' : 'Offline', style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w500, fontSize: 13)),
                if (sync.isSyncing.value) const Text('Syncing...', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Future<void> _showLogsDialog(BuildContext context) async {
    final log = DebugLog.instance;
    final content = await log.readLatestLog();
    final totalSize = await log.totalLogSize();
    final sizeStr = totalSize < 1024 ? '${totalSize}B' : '${(totalSize / 1024).toStringAsFixed(1)}KB';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Text('Debug Logs', style: TextStyle(color: AppColors.onSurface)),
            const Spacer(),
            Text('~$sizeStr', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(content, style: const TextStyle(color: AppColors.onSurface, fontSize: 11, fontFamily: 'monospace')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile() async {
    if (user == null) return;
    setState(() => saving = true);
    final uid = user!.$id;
    final name = localProfile?['name'] ?? user!.name;
    final now = DateTime.now().millisecondsSinceEpoch;
    String? imageUrl;

    if (selectedImage != null) {
      try {
        final id = 'img_$now';
        final file = await repo.uploadImage(id, selectedImage!.path);
        imageUrl = repo.getFilePreview(file.$id);
      } catch (_) {}
    }

    final updated = {
      'id': localProfile?['id'] ?? 'profile_$uid',
      'userId': uid,
      'name': name,
      'email': user!.email,
      'avatarUrl': imageUrl ?? localProfile?['avatarUrl'] ?? '',
      'isSynced': false,
      'createdAt': localProfile?['createdAt'] ?? now,
      'updatedAt': now,
    };
    await LocalStore.instance.saveProfile(updated);

    if (Get.isRegistered<SyncManager>()) Get.find<SyncManager>().queueSync();
    selectedImage = null;
    if (mounted) setState(() => saving = false);
    Get.snackbar('Saved', 'Profile updated', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.surface, colorText: AppColors.onSurface);
  }

  Future<void> _changePassword() async {
    final currentPass = TextEditingController();
    final newPass = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Change Password', style: TextStyle(color: AppColors.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPass,
              obscureText: true,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: const InputDecoration(labelText: 'Current Password', labelStyle: TextStyle(color: AppColors.onSurfaceVariant), filled: true, fillColor: AppColors.background),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPass,
              obscureText: true,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: const InputDecoration(labelText: 'New Password', labelStyle: TextStyle(color: AppColors.onSurfaceVariant), filled: true, fillColor: AppColors.background),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await repo.account.updatePassword(password: newPass.text, oldPassword: currentPass.text);
                Get.snackbar('Success', 'Password updated', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.surface, colorText: AppColors.onSurface);
              } catch (e) {
                Get.snackbar('Error', 'Failed to update password', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(backgroundColor: AppColors.background, body: const Center(child: CircularProgressIndicator(color: AppColors.primary)));
    final name = localProfile?['name'] ?? user?.name ?? '';
    final avatarUrl = localProfile?['avatarUrl']?.toString();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Expanded(child: Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.onSurface))),
                    IconButton(
                      onPressed: () async {
                        await Get.find<AuthController>().logout();
                      },
                      icon: const Icon(Icons.logout, color: AppColors.error, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Profile card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
                              if (img != null) {
                                selectedImage = File(img.path);
                                if (mounted) setState(() {});
                              }
                            },
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 44,
                                  backgroundColor: AppColors.surfaceHigh,
                                  backgroundImage: selectedImage != null ? FileImage(selectedImage!) : (avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null) as ImageProvider?,
                                  child: (avatarUrl == null || avatarUrl.isEmpty) && selectedImage == null ? const Icon(Icons.person, color: AppColors.onSurfaceVariant, size: 40) : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _EditableField(
                            initialValue: name,
                            icon: Icons.person_outline,
                            onSave: (v) async {
                              await LocalStore.instance.saveProfile({...localProfile!, 'name': v, 'updatedAt': DateTime.now().millisecondsSinceEpoch, 'isSynced': false});
                              localProfile = {...localProfile!, 'name': v};
                              await _updateProfile();
                            },
                          ),
                          const SizedBox(height: 10),
                          _EditableField(
                            initialValue: user?.email ?? '',
                            icon: Icons.email_outlined,
                            enabled: false,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: saving ? null : _updateProfile,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryContainer, foregroundColor: AppColors.background, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background)) : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Preferences
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                            child: Text('Preferences', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                          ),
                          SwitchListTile(
                            value: darkMode,
                            onChanged: (v) {
                              setState(() => darkMode = v);
                              Get.changeThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                              _savePreferences();
                            },
                            activeColor: AppColors.secondaryContainer,
                            title: const Text('Dark Mode', style: TextStyle(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
                            secondary: const Icon(Icons.dark_mode, color: AppColors.primary),
                          ),
                          const Divider(height: 1, color: AppColors.outlineVariant),
                          ListTile(
                            leading: const Icon(Icons.scale, color: AppColors.primary),
                            title: const Text('Weight Unit', style: TextStyle(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
                            trailing: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'lbs', label: Text('lbs', style: TextStyle(fontSize: 12))),
                                ButtonSegment(value: 'kg', label: Text('kg', style: TextStyle(fontSize: 12))),
                              ],
                              selected: {weightUnit},
                              onSelectionChanged: (s) {
                                setState(() => weightUnit = s.first);
                                _savePreferences();
                              },
                            ),
                          ),
                          const Divider(height: 1, color: AppColors.outlineVariant),
                          ListTile(
                            onTap: _changePassword,
                            leading: const Icon(Icons.lock_outline, color: AppColors.primary),
                            title: const Text('Change Password', style: TextStyle(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
                            trailing: const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Sync status
                    _syncStatus(),
                    const SizedBox(height: 20),
                    // App info and logs
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                            child: Text('App Info', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                          ),
                          ListTile(
                            leading: const Icon(Icons.bug_report, color: AppColors.primary),
                            title: const Text('View Debug Logs', style: TextStyle(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
                            trailing: const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
                            onTap: () => _showLogsDialog(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableField extends StatefulWidget {
  final String initialValue;
  final IconData icon;
  final bool enabled;
  final Future<void> Function(String)? onSave;
  const _EditableField({required this.initialValue, required this.icon, this.enabled = true, this.onSave});

  @override
  State<_EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  late TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
      child: Row(
        children: [
          Icon(widget.icon, color: AppColors.onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                    autofocus: true,
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                    onSubmitted: (v) async {
                      await widget.onSave?.call(v);
                      setState(() => _editing = false);
                    },
                  )
                : GestureDetector(
                    onTap: widget.enabled ? () => setState(() => _editing = true) : null,
                    child: Text(_controller.text, style: const TextStyle(color: AppColors.onSurface, fontSize: 14)),
                  ),
          ),
          if (_editing)
            IconButton(
              onPressed: () => setState(() { _controller.text = widget.initialValue; _editing = false; }),
              icon: const Icon(Icons.close, size: 18, color: AppColors.onSurfaceVariant),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else if (widget.enabled)
            IconButton(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit, size: 16, color: AppColors.onSurfaceVariant),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}