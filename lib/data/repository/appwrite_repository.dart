import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../../core/constants/appwrite_constants.dart';

class AppwriteRepository {
  AppwriteRepository._internal() {
    _client = Client()
      ..setEndpoint(AppwriteConstants.endpoint)
      ..setProject(AppwriteConstants.projectId);
    _account = Account(_client);
    _databases = Databases(_client);
    _storage = Storage(_client);
  }

  static final AppwriteRepository _instance = AppwriteRepository._internal();
  factory AppwriteRepository() => _instance;

  late final Client _client;
  late final Account _account;
  late final Databases _databases;
  late final Storage _storage;

  Client get client => _client;
  Account get account => _account;
  Databases get databases => _databases;
  Storage get storage => _storage;

  // Auth
  Future<models.User> getCurrentUser() => _account.get();

  Future<models.Session> login({required String email, required String password}) async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}
    return _account.createEmailPasswordSession(email: email, password: password);
  }

  Future<models.User> register({required String email, required String password, required String name}) =>
      _account.create(userId: ID.unique(), email: email, password: password, name: name);

  Future<void> logout() => _account.deleteSession(sessionId: 'current');

  // Build user-specific permissions list using Appwrite SDK Permission/Role helpers
  List<String> _userPerms(String userId) => [
        Permission.read(Role.user(userId)),
        Permission.update(Role.user(userId)),
        Permission.delete(Role.user(userId)),
      ];

  // Generic document creation with user-specific permissions
  Future<models.Document> _createDoc(
    String collectionId,
    Map<String, dynamic> data,
    String userId,
  ) async {
    return _databases.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: collectionId,
      documentId: ID.unique(),
      data: data,
      permissions: _userPerms(userId),
    );
  }

  Future<models.Document> _updateDoc(
    String collectionId,
    String docId,
    Map<String, dynamic> data,
    String userId,
  ) async {
    return _databases.updateDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: collectionId,
      documentId: docId,
      data: data,
      permissions: _userPerms(userId),
    );
  }

  Future<void> _deleteDoc(String collectionId, String docId) async {
    return _databases.deleteDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: collectionId,
      documentId: docId,
    );
  }

  Future<models.DocumentList> _listDocs(
    String collectionId, {
    List<String>? queries,
  }) async {
    return _databases.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: collectionId,
      queries: queries,
    );
  }

  // Users collection
  Future<models.Document> createUserProfile(String userId, Map<String, dynamic> data) =>
      _createDoc(AppwriteConstants.usersCollection, data, userId);

  Future<models.DocumentList> getUserProfile(String userId) =>
      _listDocs(AppwriteConstants.usersCollection, queries: [Query.equal('user_id', userId)]);

  Future<models.Document> updateUserProfile(String docId, Map<String, dynamic> data, String userId) =>
      _updateDoc(AppwriteConstants.usersCollection, docId, data, userId);

  // Exercises
  Future<models.Document> createExercise(String userId, Map<String, dynamic> data) =>
      _createDoc(AppwriteConstants.exercisesCollection, data, userId);

  Future<models.DocumentList> getExercises(String userId) =>
      _listDocs(AppwriteConstants.exercisesCollection, queries: [Query.equal('user_id', userId), Query.orderDesc('\$createdAt')]);

  Future<models.Document> updateExercise(String docId, Map<String, dynamic> data, String userId) =>
      _updateDoc(AppwriteConstants.exercisesCollection, docId, data, userId);

  Future<void> deleteExercise(String docId, String userId) =>
      _deleteDoc(AppwriteConstants.exercisesCollection, docId);

  // Workouts
  Future<models.Document> createWorkout(String userId, Map<String, dynamic> data) =>
      _createDoc(AppwriteConstants.workoutsCollection, data, userId);

  Future<models.DocumentList> getWorkouts(String userId) =>
      _listDocs(AppwriteConstants.workoutsCollection, queries: [Query.equal('user_id', userId), Query.orderDesc('started_at')]);

  Future<models.DocumentList> getActiveWorkout(String userId) =>
      _listDocs(AppwriteConstants.workoutsCollection, queries: [Query.equal('user_id', userId), Query.equal('is_active', true)]);

  Future<models.Document> updateWorkout(String docId, Map<String, dynamic> data, String userId) =>
      _updateDoc(AppwriteConstants.workoutsCollection, docId, data, userId);

  Future<void> deleteWorkout(String docId, String userId) =>
      _deleteDoc(AppwriteConstants.workoutsCollection, docId);

  // Sets
  Future<models.Document> createSet(String userId, Map<String, dynamic> data) =>
      _createDoc(AppwriteConstants.setsCollection, data, userId);

  Future<models.DocumentList> getSets(String workoutId) =>
      _listDocs(AppwriteConstants.setsCollection, queries: [Query.equal('workout_id', workoutId), Query.orderAsc('set_number')]);

  Future<models.DocumentList> getAllSets(String userId) =>
      _listDocs(AppwriteConstants.setsCollection, queries: [Query.equal('user_id', userId), Query.orderDesc('\$createdAt')]);

  Future<models.Document> updateSet(String docId, Map<String, dynamic> data, String userId) =>
      _updateDoc(AppwriteConstants.setsCollection, docId, data, userId);

  Future<void> deleteSet(String docId, String userId) =>
      _deleteDoc(AppwriteConstants.setsCollection, docId);

  // Preferences
  Future<models.Document> createPreference(String userId, Map<String, dynamic> data) =>
      _createDoc(AppwriteConstants.prefsCollection, data, userId);

  Future<models.DocumentList> getPreferences(String userId) =>
      _listDocs(AppwriteConstants.prefsCollection, queries: [Query.equal('user_id', userId)]);

  Future<models.Document> updatePreference(String docId, Map<String, dynamic> data, String userId) =>
      _updateDoc(AppwriteConstants.prefsCollection, docId, data, userId);

  // Storage
  Future<models.File> uploadImage(String fileId, String path) =>
      _storage.createFile(bucketId: AppwriteConstants.imagesBucket, fileId: fileId, file: InputFile(path: path));

  String getFilePreview(String fileId) =>
      '${AppwriteConstants.endpoint}/storage/buckets/${AppwriteConstants.imagesBucket}/files/$fileId/preview?project=${AppwriteConstants.projectId}';

  Future<void> deleteFile(String fileId) =>
      _storage.deleteFile(bucketId: AppwriteConstants.imagesBucket, fileId: fileId);
}
