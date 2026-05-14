import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Simple local-only data store using Hive (no code generation).
/// All reads/writes go to local storage; sync to Appwrite happens on top.
class LocalStore {
  LocalStore._();
  static final LocalStore _instance = LocalStore._();
  factory LocalStore() => _instance;

  /// Global accessor — initialized in main.dart before runApp()
  static late LocalStore instance;

  late Box _exercises;
  late Box _workouts;
  late Box _sets;
  late Box _profile;
  late Box _prefs;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
    _exercises = await Hive.openBox('exercises');
    _workouts = await Hive.openBox('workouts');
    _sets = await Hive.openBox('sets');
    _profile = await Hive.openBox('profile');
    _prefs = await Hive.openBox('prefs');
  }

  // ---- Exercises ----
  List<Map<String, dynamic>> getExercises(String userId) {
    final all = _exercises.values
        .where((e) => (e as Map)['userId'] == userId)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    all.sort((a, b) => ((b['createdAt'] ?? 0) as num).compareTo((a['createdAt'] ?? 0) as num));
    return all;
  }

  List<Map<String, dynamic>> getUnsyncedExercises(String userId) {
    return _exercises.values
        .where((e) => (e as Map)['userId'] == userId && e['isSynced'] != true)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> saveExercise(Map<String, dynamic> ex) async {
    await _exercises.put(ex['id'], ex);
  }

  Future<void> deleteExercise(String id) async {
    await _exercises.delete(id);
  }

  // ---- Workouts ----
  List<Map<String, dynamic>> getWorkouts(String userId) {
    final all = _workouts.values
        .where((w) => (w as Map)['userId'] == userId)
        .map((w) => Map<String, dynamic>.from(w as Map))
        .toList();
    all.sort((a, b) => ((b['startedAt'] ?? 0) as num).compareTo((a['startedAt'] ?? 0) as num));
    return all;
  }

  Map<String, dynamic>? getActiveWorkout(String userId) {
    try {
      return Map<String, dynamic>.from(
        _workouts.values.firstWhere(
          (w) => (w as Map)['userId'] == userId && (w)['isActive'] == true,
        ) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWorkout(Map<String, dynamic> w) async {
    await _workouts.put(w['id'], w);
  }

  Future<void> deleteWorkout(String id) async {
    await _workouts.delete(id);
  }

  List<Map<String, dynamic>> getUnsyncedWorkouts() {
    return _workouts.values
        .where((w) => (w as Map)['isSynced'] != true)
        .map((w) => Map<String, dynamic>.from(w as Map))
        .toList();
  }

  Future<void> markWorkoutSynced(String id) async {
    final w = _workouts.get(id);
    if (w != null) {
      await _workouts.put(id, {...Map<String, dynamic>.from(w as Map), 'isSynced': true});
    }
  }

  // ---- Sets ----
  List<Map<String, dynamic>> getSetsForWorkout(String workoutId) {
    final all = _sets.values
        .where((s) => (s as Map)['workoutId'] == workoutId)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    all.sort((a, b) => ((a['setNumber'] ?? 0) as num).compareTo((b['setNumber'] ?? 0) as num));
    return all;
  }

  List<Map<String, dynamic>> getAllSetsForUser(String userId) {
    return _sets.values
        .where((s) => (s as Map)['userId'] == userId)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList()
      ..sort((a, b) => ((b['createdAt'] ?? 0) as num).compareTo((a['createdAt'] ?? 0) as num));
  }

  Future<void> saveSet(Map<String, dynamic> s) async {
    await _sets.put(s['id'], s);
  }

  Future<void> deleteSet(String id) async {
    await _sets.delete(id);
  }

  List<Map<String, dynamic>> getUnsyncedSets() {
    return _sets.values
        .where((s) => (s as Map)['isSynced'] != true)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
  }

  Future<void> markSetSynced(String id) async {
    final s = _sets.get(id);
    if (s != null) {
      await _sets.put(id, {...Map<String, dynamic>.from(s as Map), 'isSynced': true});
    }
  }

  // ---- Profile ----
  Map<String, dynamic>? getProfile(String userId) {
    try {
      return Map<String, dynamic>.from(
        _profile.values.firstWhere((p) => (p as Map)['userId'] == userId) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(Map<String, dynamic> p) async {
    await _profile.put(p['id'], p);
  }

  // ---- Preferences ----
  Map<String, dynamic>? getPrefs(String userId) {
    try {
      return Map<String, dynamic>.from(
        _prefs.values.firstWhere((p) => (p as Map)['userId'] == userId) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePrefs(Map<String, dynamic> p) async {
    await _prefs.put(p['id'], p);
  }

  // ---- Generic ----
  Future<void> clearAll() async {
    await _exercises.clear();
    await _workouts.clear();
    await _sets.clear();
    await _profile.clear();
    await _prefs.clear();
  }
}
