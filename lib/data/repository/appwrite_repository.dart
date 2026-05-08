import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as appwrite_models;
import '../../core/constants/appwrite_constants.dart';

/// Singleton repository for all Appwrite server interactions.
///
/// Initialises a shared [Client] once and exposes typed service accessors.
/// Add new Appwrite services (Storage, Functions, etc.) here as the app grows.
class AppwriteRepository {
  AppwriteRepository._internal() {
    _client = Client()
      ..setEndpoint(AppwriteConstants.endpoint)
      ..setProject(AppwriteConstants.projectId);

    _account = Account(_client);
  }

  static final AppwriteRepository _instance = AppwriteRepository._internal();
  factory AppwriteRepository() => _instance;

  late final Client _client;
  late final Account _account;

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Returns the currently logged-in [User], or throws [AppwriteException]
  /// with code 401 if no active session exists.
  Future<appwrite_models.User> getCurrentUser() => _account.get();

  /// Creates an email/password session and returns the new [Session].
  Future<appwrite_models.Session> login({
    required String email,
    required String password,
  }) =>
      _account.createEmailPasswordSession(
        email: email,
        password: password,
      );

  /// Creates a new account and returns the [User].
  Future<appwrite_models.User> register({
    required String email,
    required String password,
    required String name,
  }) =>
      _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );

  /// Deletes the current session (logout).
  Future<void> logout() => _account.deleteSession(sessionId: 'current');

  // ── Health ─────────────────────────────────────────────────────────────────

  /// Pings the Appwrite server. Returns `true` if reachable.
  Future<bool> ping() async {
    try {
      await _client.ping();
      return true;
    } on AppwriteException {
      return false;
    }
  }
}
