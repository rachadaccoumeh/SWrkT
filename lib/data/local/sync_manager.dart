import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'local_store.dart';
import '../repository/appwrite_repository.dart';
import '../../core/utils/debug_log.dart';
import '../../features/auth/controllers/auth_controller.dart';

/// Tracks connectivity and syncs unsynced local data to Appwrite when back online.
class SyncManager extends GetxService {
  final LocalStore _store;
  final AppwriteRepository _repo = AppwriteRepository();
  final _log = DebugLog.instance;

  final RxBool isOnline = true.obs;
  final RxBool isSyncing = false.obs;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  SyncManager(this._store) {
    _log.sync('SyncManager created');
    _init();
  }

  void _init() {
    _log.sync('Subscribing to connectivity changes');
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final wasOffline = !isOnline.value;
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      isOnline.value = hasConnection;
      _log.sync('Connectivity changed: $results, online=$hasConnection');
      if (hasConnection && wasOffline) {
        _log.sync('Back online - triggering sync');
        _syncAll();
      }
    });
    _checkInitial();
  }

  Future<void> _checkInitial() async {
    _log.sync('Checking initial connectivity');
    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    isOnline.value = hasConnection;
    _log.sync('Initial connectivity: $hasConnection, results=$results');
    if (hasConnection) {
      _log.sync('Online on startup - triggering sync');
      await _syncAll();
    }
  }

  String? get _userId {
    try {
      final uid = Get.find<AuthController>().user.value?.$id;
      _log.sync('Got userId from AuthController: ${uid != null}');
      return uid;
    } catch (e) {
      _log.error('Failed to get userId', data: e.toString());
      return null;
    }
  }

  /// Call after any local write to queue sync
  void queueSync() async {
    _log.sync('queueSync() called, wasOnline=${isOnline.value}, syncing=${isSyncing.value}');
    // Verify actual connectivity before syncing
    final results = await Connectivity().checkConnectivity();
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    isOnline.value = hasConnection;
    _log.sync('Connectivity check: $results, online=$hasConnection');
    if (!hasConnection) {
      _log.sync('Still offline - sync queued');
      return;
    }
    _log.sync('Online - triggering sync');
    _syncAll();
  }

  Future<void> _syncAll() async {
    if (isSyncing.value) {
      _log.sync('Already syncing, skipping');
      return;
    }
    final uid = _userId;
    if (uid == null) {
      _log.sync('No userId - cannot sync');
      return;
    }
    _log.sync('=== Starting full sync for user: $uid ===');
    isSyncing.value = true;
    try {
      await _syncExercises(uid);
      await _syncWorkouts(uid);
      await _syncSets(uid);
      await _syncPrefs(uid);
      _log.sync('=== Sync complete ===');
    } catch (e) {
      _log.error('Sync failed', data: e.toString());
    }
    isSyncing.value = false;
  }

  Future<void> _syncExercises(String uid) async {
    final unsynced = _store.getUnsyncedExercises(uid);
    _log.db('Unsynced exercises: ${unsynced.length}', data: unsynced.map((e) => {'id': e['id'], 'name': e['name'], 'remoteId': e['remoteId']}).toList());

    for (final e in unsynced) {
      try {
        final exerciseId = e['id'];
        final remoteId = e['remoteId'] as String?;
        _log.sync('Syncing exercise $exerciseId, remoteId=$remoteId');

        final data = {
          'name': e['name'] ?? '',
          'user_id': uid,
          'muscle_group': e['muscleGroup'] ?? '',
          'notes': e['notes'] ?? '',
          'image_url': e['imageUrl'] ?? '',
          'is_custom': true,
          'created_at': DateTime.now().toIso8601String(),
        };

        if (remoteId != null && remoteId.isNotEmpty) {
          _log.sync('Updating existing remote exercise $remoteId');
          await _repo.updateExercise(remoteId, data, uid);
          await _store.saveExercise({...e, 'isSynced': true});
        } else {
          _log.sync('Creating new remote exercise');
          final doc = await _repo.createExercise(uid, data);
          _log.sync('Created remote exercise ${doc.$id}');
          await _store.saveExercise({...e, 'isSynced': true, 'remoteId': doc.$id});
        }
      } catch (e) {
        final exerciseId = e is Map ? e['id'] : 'unknown';
        _log.error('Failed to sync exercise $exerciseId', data: e.toString());
      }
    }
  }

  Future<void> _syncWorkouts(String uid) async {
    final unsynced = _store.getUnsyncedWorkouts();
    _log.db('Unsynced workouts: ${unsynced.length}');

    for (final w in unsynced) {
      try {
        final remoteId = w['remoteId'] as String?;
        _log.sync('Syncing workout ${w['id']}, remoteId=$remoteId');

        final data = {
          'name': w['name'] ?? '',
          'user_id': uid,
          'is_active': w['isActive'] ?? true,
          'started_at': w['startedAt'],
          'completed_at': w['completedAt'],
        };

        if (remoteId != null && remoteId.isNotEmpty) {
          await _repo.updateWorkout(remoteId, data, uid);
          await _store.saveWorkout({...w, 'isSynced': true});
        } else {
          final doc = await _repo.createWorkout(uid, data);
          _log.sync('Created remote workout ${doc.$id}');
          await _store.saveWorkout({...w, 'isSynced': true, 'remoteId': doc.$id});
        }
      } catch (e) {
        _log.error('Failed to sync workout ${w['id']}', data: e.toString());
      }
    }
  }

  Future<void> _syncSets(String uid) async {
    final unsynced = _store.getUnsyncedSets();
    _log.db('Unsynced sets: ${unsynced.length}');

    for (final s in unsynced) {
      try {
        final remoteId = s['remoteId'] as String?;
        _log.sync('Syncing set ${s['id']}, remoteId=$remoteId');

        final data = {
          'workout_id': s['workoutId'] ?? '',
          'exercise_id': s['exerciseId'] ?? '',
          'user_id': uid,
          'set_number': s['setNumber'] ?? 0,
          'reps': s['reps'] ?? 0,
          'weight': s['weight'] ?? 0,
          'is_completed': s['isCompleted'] ?? false,
        };

        if (remoteId != null && remoteId.isNotEmpty) {
          await _repo.updateSet(remoteId, data, uid);
          await _store.saveSet({...s, 'isSynced': true});
        } else {
          final doc = await _repo.createSet(uid, data);
          _log.sync('Created remote set ${doc.$id}');
          await _store.saveSet({...s, 'isSynced': true, 'remoteId': doc.$id});
        }
      } catch (e) {
        _log.error('Failed to sync set ${s['id']}', data: e.toString());
      }
    }
  }

  Future<void> _syncPrefs(String uid) async {
    final p = _store.getPrefs(uid);
    if (p == null) {
      _log.db('No prefs to sync');
      return;
    }
    if (p['isSynced'] == true) {
      _log.db('Prefs already synced');
      return;
    }
    try {
      final remoteId = p['remoteId'] as String?;
      _log.sync('Syncing prefs, remoteId=$remoteId');

      final data = {
        'user_id': uid,
        'dark_mode': p['darkMode'] ?? true,
        'weight_unit': p['weightUnit'] ?? 'lbs',
        'created_at': DateTime.now().toIso8601String(),
      };

      if (remoteId != null && remoteId.isNotEmpty) {
        await _repo.updatePreference(remoteId, data, uid);
        await _store.savePrefs({...p, 'isSynced': true});
      } else {
        final doc = await _repo.createPreference(uid, data);
        _log.sync('Created remote prefs ${doc.$id}');
        await _store.savePrefs({...p, 'isSynced': true, 'remoteId': doc.$id});
      }
    } catch (e) {
      _log.error('Failed to sync prefs', data: e.toString());
    }
  }

  @override
  void onClose() {
    _log.sync('SyncManager closing');
    _connSub?.cancel();
    super.onClose();
  }
}