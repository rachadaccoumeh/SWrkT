import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/appwrite_constants.dart';
import '../models/subscription_models.dart';
import '../../data/repository/appwrite_repository.dart';
import '../utils/debug_log.dart';

/// Central service for subscription management.
/// Handles fetching plans, user subscription status, access control,
/// promo grants, and caching locally.
class SubscriptionService extends GetxService {
  final AppwriteRepository _repo = AppwriteRepository();
  final _log = DebugLog.instance;

  // Cached data
  final RxList<SubscriptionPlan> plans = <SubscriptionPlan>[].obs;
  final Rxn<UserSubscription> currentSubscription = Rxn<UserSubscription>();
  final Rxn<AdConfig> adConfig = Rxn<AdConfig>();
  final Rxn<AppConfig> appConfig = Rxn<AppConfig>();

  // Reactive state
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;

  // Local cache keys
  static const String _kPlansCache = 'subscription_plans_cache';
  static const String _kAdConfigCache = 'ad_config_cache';
  static const String _kAppConfigCache = 'app_config_cache';

  @override
  void onInit() {
    super.onInit();
    _log.info('SubscriptionService initialized');
  }

  /// Initialize by loading cached data first, then fetching from network.
  Future<SubscriptionService> init() async {
    isLoading.value = true;
    try {
      // Then refresh from Appwrite in background
      await refreshAll();

      // Check if user has any active subscription
      await _loadUserSubscription();
    } catch (e) {
      _log.error('SubscriptionService init failed', data: e.toString());
    } finally {
      isLoading.value = false;
      isInitialized.value = true;
    }
    return this;
  }

  /// Refresh all data from Appwrite
  Future<void> refreshAll() async {
    await Future.wait([
      refreshPlans(),
      refreshAdConfig(),
      refreshAppConfig(),
    ]);
  }

  /// Fetch subscription plans from Appwrite
  Future<void> refreshPlans() async {
    try {
      final docs = await _repo.listDocsPublic(
        AppwriteConstants.subscriptionPlansCollection,
        queries: [
          Query.equal('is_active', true),
          Query.orderAsc('sort_order'),
        ],
      );

      final fetchedPlans = docs.documents.map((d) => SubscriptionPlan.fromMap(d.data, docId: d.$id)).toList();
      plans.value = fetchedPlans;

      debugPrint('[SubscriptionService] Loaded ${fetchedPlans.length} subscription plans');
    } catch (e) {
      _log.error('Failed to refresh plans', data: e.toString());
      // Load from cache if network fails - simplified, no full cache implementation
    }
  }

  /// Fetch ad configuration from Appwrite
  Future<void> refreshAdConfig() async {
    try {
      final docs = await _repo.listDocsPublic(
        AppwriteConstants.adConfigCollection,
        queries: [
          Query.equal('is_active', true),
        ],
      );

      if (docs.documents.isNotEmpty) {
        adConfig.value = AdConfig.fromMap(docs.documents.first.data, docId: docs.documents.first.$id);
      }
    } catch (e) {
      _log.error('Failed to refresh ad config', data: e.toString());
    }
  }

  /// Fetch app-wide configuration from Appwrite
  Future<void> refreshAppConfig() async {
    try {
      final docs = await _repo.listDocsPublic(AppwriteConstants.appConfigCollection);
      if (docs.documents.isNotEmpty) {
        appConfig.value = AppConfig.fromMap(docs.documents.first.data, docId: docs.documents.first.$id);
      }
    } catch (e) {
      _log.error('Failed to refresh app config', data: e.toString());
    }
  }

  /// Load user's current subscription from Appwrite
  Future<void> _loadUserSubscription() async {
    try {
      final user = await _repo.getCurrentUser();
      final docs = await _repo.listDocsPublic(
        AppwriteConstants.userSubscriptionsCollection,
        queries: [
          Query.equal('user_id', user.$id),
          Query.orderDesc('created_at'),
        ],
      );

      if (docs.documents.isNotEmpty) {
        // Find the most recent valid subscription
        final subs = docs.documents.map((d) => UserSubscription.fromMap(d.data, docId: d.$id)).toList();
        final valid = subs.firstWhereOrNull((s) => s.isValid) ?? subs.first;
        currentSubscription.value = valid;

        debugPrint('[SubscriptionService] Loaded user subscription: ${valid.planId} - ${valid.status}');
      } else {
        currentSubscription.value = null;
      }
    } catch (e) {
      _log.error('Failed to load user subscription', data: e.toString());
    }
  }

  /// Get all active plans sorted by sort_order
  List<SubscriptionPlan> get activePlans => plans.where((p) => p.isActive).toList();

  /// Get the default/free plan
  SubscriptionPlan? get defaultPlan => plans.firstWhereOrNull((p) => p.isDefault && p.isActive);

  /// Check if user has premium access
  bool get isPremiumUser {
    final sub = currentSubscription.value;
    if (sub == null) return false;
    return sub.isValid;
  }

  /// Check if user is in free trial
  bool get isInTrial {
    final sub = currentSubscription.value;
    return sub?.isInTrial ?? false;
  }

  /// Check if ads should be shown to this user
  bool get shouldShowAds {
    // If no subscription or not premium, show ads
    if (!isPremiumUser) return true;

    // If has subscription, check plan's ad setting
    final sub = currentSubscription.value;
    if (sub == null) return true;

    final plan = plans.firstWhereOrNull((p) => p.planId == sub.planId);
    return plan?.adsEnabled ?? true;
  }

  /// Get the plan object for current subscription
  SubscriptionPlan? get currentPlan {
    final sub = currentSubscription.value;
    if (sub == null) return null;
    return plans.firstWhereOrNull((p) => p.planId == sub.planId);
  }

  /// Get how many days of history this user can access
  /// 0 means full access (premium), >0 is limited days (free tier)
  int get historyAccessDays {
    final sub = currentSubscription.value;
    if (sub == null) return getDefaultFreeHistoryDays();

    final plan = plans.firstWhereOrNull((p) => p.planId == sub.planId);
    if (plan == null) return getDefaultFreeHistoryDays();

    // If plan has 0 free history days, it means unlimited
    return plan.freeHistoryDays;
  }

  /// Get default free history days from app config
  int getDefaultFreeHistoryDays() {
    final cfg = appConfig.value;
    return cfg?.getValue<int>('default_free_history_days') ?? 30;
  }

  /// Check if user can access a specific feature
  bool hasFeature(String feature) {
    final sub = currentSubscription.value;
    if (sub == null) {
      // Check default plan features
      final defPlan = defaultPlan;
      return defPlan?.hasFeature(feature) ?? false;
    }

    final plan = plans.firstWhereOrNull((p) => p.planId == sub.planId);
    return plan?.hasFeature(feature) ?? false;
  }

  /// Record a new subscription (purchase, trial, or admin grant)
  Future<void> recordSubscription({
    required String planId,
    required String status,
    required String storePlatform,
    String? storeReceipt,
    String? promoCode,
    String? grantedByAdmin,
    DateTime? expiresAt,
    bool isLifetime = false,
    int? trialDays,
  }) async {
    try {
      final user = await _repo.getCurrentUser();

      final now = DateTime.now();
      DateTime? trialEnd;
      if (trialDays != null && trialDays > 0) {
        trialEnd = now.add(Duration(days: trialDays));
      }

      final data = {
        'user_id': user.$id,
        'plan_id': planId,
        'status': status,
        'started_at': now.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'trial_ends_at': trialEnd?.toIso8601String(),
        'is_lifetime': isLifetime,
        'store_receipt': storeReceipt ?? '',
        'store_platform': storePlatform,
        'promo_code': promoCode ?? '',
        'granted_by_admin': grantedByAdmin ?? '',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Create new subscription record
      final doc = await _repo.createDocPublic(
        AppwriteConstants.userSubscriptionsCollection,
        data,
        user.$id,
      );

      final newSub = UserSubscription.fromMap(data, docId: doc.$id);
      currentSubscription.value = newSub;

      debugPrint('[SubscriptionService] Recorded subscription: $planId - $status');
    } catch (e) {
      _log.error('Failed to record subscription', data: e.toString());
      rethrow;
    }
  }

  /// Start a free trial for a plan
  Future<void> startFreeTrial(String planId, {int? trialDays}) async {
    final plan = plans.firstWhereOrNull((p) => p.planId == planId);
    if (plan == null) throw Exception('Plan not found: $planId');

    final days = trialDays ?? plan.freeTrialDays;
    if (days <= 0) throw Exception('No free trial available for this plan');

    await recordSubscription(
      planId: planId,
      status: 'trial',
      storePlatform: 'free_trial',
      trialDays: days,
    );
  }

  /// Grant subscription via admin/promo (no purchase)
  Future<void> grantSubscription({
    required String planId,
    required String grantedByAdmin,
    String? promoCode,
    DateTime? expiresAt,
    bool isLifetime = false,
  }) async {
    await recordSubscription(
      planId: planId,
      status: 'granted',
      storePlatform: 'admin',
      grantedByAdmin: grantedByAdmin,
      promoCode: promoCode,
      expiresAt: expiresAt,
      isLifetime: isLifetime,
    );
  }

  /// Purchase a subscription (record after store purchase)
  Future<void> purchaseSubscription({
    required String planId,
    required String storePlatform,
    required String storeReceipt,
    DateTime? expiresAt,
    bool isLifetime = false,
  }) async {
    await recordSubscription(
      planId: planId,
      status: 'active',
      storePlatform: storePlatform,
      storeReceipt: storeReceipt,
      expiresAt: expiresAt,
      isLifetime: isLifetime,
    );
  }

  /// Check if user has already used a free trial for a plan
  bool hasUsedTrialFor(String planId) {
    // This would be checked against stored user subscription records
    return false; // TODO: implement proper trial tracking
  }

  /// Get AdMob configuration for current platform
  AdConfig? getPlatformAdConfig() {
    final config = adConfig.value;
    if (config == null || !config.isActive) return null;
    return config;
  }
}