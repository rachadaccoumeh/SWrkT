import 'package:appwrite/appwrite.dart';
import 'package:get/get.dart';
import '../constants/appwrite_constants.dart';
import '../models/subscription_models.dart';
import '../../data/repository/appwrite_repository.dart';
import '../utils/debug_log.dart';
import 'subscription_service.dart';

/// Service for admin-level operations.
/// Allows granting subscription access without purchase for testing/promos.
///
/// ## Security Note:
/// In production, you should add Appwrite's "admin" role check here.
/// Only users with admin privileges should be able to call these methods.
/// For now, this is a simple implementation - secure it based on your auth setup.
class AdminService extends GetxService {
  final AppwriteRepository _repo = AppwriteRepository();
  final _log = DebugLog.instance;
  late final SubscriptionService _subsService;

  @override
  void onInit() {
    super.onInit();
    _subsService = Get.find<SubscriptionService>();
  }

  /// Grant subscription to a user WITHOUT purchase.
  /// Used for:
  /// - Testing/demo accounts
  /// - Promotional giveaways
  /// - Compensation for issues
  /// - Beta program access
  ///
  /// Parameters:
  /// - targetUserId: Appwrite user ID to grant access to
  /// - planId: Plan to grant (e.g., "monthly", "yearly", "lifetime")
  /// - durationDays: Override duration (null = use plan's default, -1 = lifetime)
  /// - reason: Note for audit trail
  Future<void> grantSubscription({
    required String targetUserId,
    required String planId,
    int? durationDays,
    String? reason,
  }) async {
    _log.admin('Granting subscription to user: $targetUserId, plan: $planId');

    try {
      final plan = _subsService.plans.firstWhereOrNull((p) => p.planId == planId);
      if (plan == null) throw Exception('Plan not found: $planId');

      final now = DateTime.now();
      DateTime? expiresAt;

      if (durationDays != null) {
        if (durationDays == -1) {
          // Lifetime
        } else {
          expiresAt = now.add(Duration(days: durationDays));
        }
      } else if (plan.isLifetime) {
        // Use plan's lifetime setting
      } else {
        expiresAt = now.add(Duration(days: plan.durationDays));
      }

      // Get current admin user ID (you'd get this from your auth system)
      final adminUserId = await _getCurrentAdminUserId();

      // Create subscription record
      await _subsService.grantSubscription(
        planId: planId,
        grantedByAdmin: adminUserId,
        expiresAt: expiresAt,
        isLifetime: durationDays == -1 || plan.isLifetime,
      );

      // Also create a promo grant record for audit trail
      await _createPromoGrantRecord(
        targetUserId: targetUserId,
        planId: planId,
        grantedBy: adminUserId,
        reason: reason ?? 'Admin grant',
        expiresAt: expiresAt,
      );

      _log.admin('Successfully granted subscription to $targetUserId');
    } catch (e) {
      _log.error('Admin grant failed', data: e.toString());
      rethrow;
    }
  }

  /// Revoke subscription from a user.
  Future<void> revokeSubscription({
    required String targetUserId,
    required String subscriptionId,
    String? reason,
  }) async {
    _log.admin('Revoking subscription: $subscriptionId from user: $targetUserId');

    try {
      // Update subscription status to revoked
      await _repo.updateDocPublic(
        AppwriteConstants.userSubscriptionsCollection,
        subscriptionId,
        {
          'status': 'revoked',
          'revoked_at': DateTime.now().toIso8601String(),
          'revoked_reason': reason ?? 'Admin revocation',
        },
        targetUserId,
      );

      _log.admin('Successfully revoked subscription $subscriptionId');
    } catch (e) {
      _log.error('Revoke subscription failed', data: e.toString());
      rethrow;
    }
  }

  /// Set a specific plan to be free for a limited time period.
  /// Anyone can get this plan for free during the promotional window.
  ///
  /// Parameters:
  /// - planId: Plan to make free
  /// - startTime: When the promo starts
  /// - endTime: When the promo ends (null = no end)
  /// - maxClaims: Max number of claims allowed (null = unlimited)
  Future<void> createPromotionalPlan({
    required String planId,
    required DateTime startTime,
    DateTime? endTime,
    int? maxClaims,
    String? promoCode,
  }) async {
    _log.admin('Creating promotional plan: $planId');

    try {
      final now = DateTime.now();
      final data = {
        'plan_id': planId,
        'promo_code': promoCode ?? '',
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'max_claims': maxClaims,
        'current_claims': 0,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await _repo.createDocPublic(
        AppwriteConstants.promoGrantsCollection,
        data,
        await _getCurrentAdminUserId(),
      );

      _log.admin('Promotional plan created successfully');
    } catch (e) {
      _log.error('Create promotional plan failed', data: e.toString());
      rethrow;
    }
  }

  /// Check if a promotional plan is currently active and claimable.
  Future<PromoGrant?> getActivePromo(String promoCode) async {
    try {
      final docs = await _repo.listDocsPublic(
        AppwriteConstants.promoGrantsCollection,
        queries: [
          Query.equal('promo_code', promoCode),
          Query.equal('is_active', true),
        ],
      );

      if (docs.documents.isEmpty) return null;

      final doc = docs.documents.first;
      final promo = PromoGrant.fromMap(doc.data, docId: doc.$id);

      // Check if expired
      if (promo.endTime != null && promo.endTime!.isBefore(DateTime.now())) {
        return null;
      }

      // Check max claims
      if (promo.maxClaims != null && promo.currentClaims >= promo.maxClaims!) {
        return null;
      }

      return promo;
    } catch (e) {
      _log.error('getActivePromo failed', data: e.toString());
      return null;
    }
  }

  /// Claim a promotional plan (increment claim counter).
  Future<void> claimPromo(String promoCode, String userId) async {
    try {
      final promo = await getActivePromo(promoCode);
      if (promo == null) throw Exception('Promo not available');

      // Increment claims
      await _repo.updateDocPublic(
        AppwriteConstants.promoGrantsCollection,
        promo.id,
        {
          'current_claims': promo.currentClaims + 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        promo.id,
      );

      // Grant the plan
      await grantSubscription(
        targetUserId: userId,
        planId: promo.planId,
        reason: 'Promo code: $promoCode',
      );
    } catch (e) {
      _log.error('Claim promo failed', data: e.toString());
      rethrow;
    }
  }

  /// Get list of all promo grants (for admin dashboard).
  Future<List<PromoGrant>> getAllPromoGrants() async {
    try {
      final docs = await _repo.listDocsPublic(
        AppwriteConstants.promoGrantsCollection,
        queries: [Query.orderDesc('created_at')],
      );

      return docs.documents
          .map((d) => PromoGrant.fromMap(d.data, docId: d.$id))
          .toList();
    } catch (e) {
      _log.error('getAllPromoGrants failed', data: e.toString());
      return [];
    }
  }

  /// Get admin's own user ID (placeholder - implement based on your auth).
  Future<String> _getCurrentAdminUserId() async {
    // In production, get this from your auth context
    // For now, return a placeholder
    try {
      final user = await _repo.getCurrentUser();
      return user.$id;
    } catch (_) {
      return 'admin_unknown';
    }
  }

  /// Create audit trail record for grants.
  Future<void> _createPromoGrantRecord({
    required String targetUserId,
    required String planId,
    required String grantedBy,
    required String reason,
    DateTime? expiresAt,
  }) async {
    try {
      final now = DateTime.now();
      await _repo.createDocPublic(
        AppwriteConstants.promoGrantsCollection,
        {
          'target_user_id': targetUserId,
          'plan_id': planId,
          'granted_by': grantedBy,
          'reason': reason,
          'expires_at': expiresAt?.toIso8601String(),
          'type': 'admin_grant',
          'created_at': now.toIso8601String(),
        },
        grantedBy,
      );
    } catch (e) {
      // Non-critical, just log
      _log.error('Failed to create promo grant record', data: e.toString());
    }
  }
}

/// Model for promotional grants.
class PromoGrant {
  final String id;
  final String planId;
  final String? promoCode;
  final DateTime startTime;
  final DateTime? endTime;
  final int? maxClaims;
  final int currentClaims;
  final bool isActive;
  final DateTime createdAt;

  PromoGrant({
    required this.id,
    required this.planId,
    this.promoCode,
    required this.startTime,
    this.endTime,
    this.maxClaims,
    required this.currentClaims,
    required this.isActive,
    required this.createdAt,
  });

  factory PromoGrant.fromMap(Map<String, dynamic> map, {String? docId}) {
    return PromoGrant(
      id: docId ?? '',
      planId: map['plan_id'] ?? '',
      promoCode: map['promo_code'],
      startTime: DateTime.parse(map['start_time'] ?? DateTime.now().toIso8601String()),
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time']) : null,
      maxClaims: map['max_claims'],
      currentClaims: map['current_claims'] ?? 0,
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isExpired {
    if (endTime == null) return false;
    return endTime!.isBefore(DateTime.now());
  }

  bool get isClaimable {
    if (!isActive || isExpired) return false;
    if (maxClaims != null && currentClaims >= maxClaims!) return false;
    if (startTime.isAfter(DateTime.now())) return false;
    return true;
  }

  int? get remainingClaims {
    if (maxClaims == null) return null;
    return maxClaims! - currentClaims;
  }
}