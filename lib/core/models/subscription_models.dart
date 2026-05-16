/// Represents a subscription plan definition stored in Appwrite.
/// This is a MODEL class - schema follows app_config collection.
class SubscriptionPlan {
  final String id;
  final String planId; // e.g. "monthly", "yearly", "lifetime"
  final String name; // Display name
  final String description;
  final double price; // 0 for free
  final String currency; // "USD", "EUR", etc.
  final int durationDays; // 0 for lifetime
  final bool isLifetime;
  final bool isFree; // Promotional free plan
  final bool isDefault; // Shown to users by default
  final int freeHistoryDays; // How many days of history free users can see (0 = all)
  final int freeTrialDays; // 0 = no trial
  final List<String> enabledFeatures; // Feature flags this plan unlocks
  final bool adsEnabled; // Whether ads are shown
  final int sortOrder; // Display ordering
  final bool isActive; // false = hidden from store
  final DateTime createdAt;
  final DateTime updatedAt;

  SubscriptionPlan({
    required this.id,
    required this.planId,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.isLifetime,
    required this.isFree,
    required this.isDefault,
    required this.freeHistoryDays,
    required this.freeTrialDays,
    required this.enabledFeatures,
    required this.adsEnabled,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map, {String? docId}) {
    return SubscriptionPlan(
      id: docId ?? '',
      planId: map['plan_id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'USD',
      durationDays: map['duration_days'] ?? 30,
      isLifetime: map['is_lifetime'] ?? false,
      isFree: map['is_free'] ?? false,
      isDefault: map['is_default'] ?? false,
      freeHistoryDays: map['free_history_days'] ?? 0,
      freeTrialDays: map['free_trial_days'] ?? 0,
      enabledFeatures: List<String>.from(map['enabled_features'] ?? []),
      adsEnabled: map['ads_enabled'] ?? true,
      sortOrder: map['sort_order'] ?? 0,
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan_id': planId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'duration_days': durationDays,
      'is_lifetime': isLifetime,
      'is_free': isFree,
      'is_default': isDefault,
      'free_history_days': freeHistoryDays,
      'free_trial_days': freeTrialDays,
      'enabled_features': enabledFeatures,
      'ads_enabled': adsEnabled,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if this plan has a specific feature flag
  bool hasFeature(String feature) => enabledFeatures.contains(feature);

  /// Check if this plan includes a free trial
  bool get hasFreeTrial => freeTrialDays > 0;

  /// Get formatted price string
  String get formattedPrice {
    if (isFree) return 'Free';
    if (isLifetime) return 'Lifetime';
    return '\$${price.toStringAsFixed(2)}';
  }

  /// Get duration display string
  String get durationDisplay {
    if (isLifetime) return 'Forever';
    if (durationDays == 30) return 'Monthly';
    if (durationDays == 365) return 'Yearly';
    return '$durationDays days';
  }
}

/// Represents a user's actual subscription status (purchase, trial, grant, etc.).
/// Stored in user_subscriptions collection.
class UserSubscription {
  final String id;
  final String oderId; // Appwrite user ID
  final String planId; // Reference to plan_id in SubscriptionPlan
  final String status; // "active", "trial", "expired", "cancelled", "granted"
  final DateTime? startedAt;
  final DateTime? expiresAt; // null for lifetime
  final DateTime? trialEndsAt;
  final bool isLifetime;
  final String? promoCode; // If granted via promo
  final String? grantedByAdmin; // Admin user ID who granted it
  final String? storeReceipt; // Platform-specific receipt (for validation)
  final String? storePlatform; // "google_play", "apple_store", "admin", "promo"
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSubscription({
    required this.id,
    required this.oderId,
    required this.planId,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.trialEndsAt,
    required this.isLifetime,
    this.promoCode,
    this.grantedByAdmin,
    this.storeReceipt,
    this.storePlatform,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSubscription.fromMap(Map<String, dynamic> map, {String? docId}) {
    return UserSubscription(
      id: docId ?? '',
      oderId: map['user_id'] ?? '',
      planId: map['plan_id'] ?? '',
      status: map['status'] ?? 'active',
      startedAt: map['started_at'] != null ? DateTime.tryParse(map['started_at']) : null,
      expiresAt: map['expires_at'] != null ? DateTime.tryParse(map['expires_at']) : null,
      trialEndsAt: map['trial_ends_at'] != null ? DateTime.tryParse(map['trial_ends_at']) : null,
      isLifetime: map['is_lifetime'] ?? false,
      promoCode: map['promo_code'],
      grantedByAdmin: map['granted_by_admin'],
      storeReceipt: map['store_receipt'],
      storePlatform: map['store_platform'],
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': oderId,
      'plan_id': planId,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'is_lifetime': isLifetime,
      'promo_code': promoCode,
      'granted_by_admin': grantedByAdmin,
      'store_receipt': storeReceipt,
      'store_platform': storePlatform,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if subscription is currently valid (active or trial)
  bool get isValid {
    if (status == 'granted' || status == 'active') {
      if (isLifetime) return true;
      if (expiresAt != null && expiresAt!.isAfter(DateTime.now())) return true;
    }
    if (status == 'trial' && trialEndsAt != null && trialEndsAt!.isAfter(DateTime.now())) return true;
    return false;
  }

  /// Check if currently in free trial
  bool get isInTrial => status == 'trial' && trialEndsAt != null && trialEndsAt!.isAfter(DateTime.now());

  /// Check if admin granted
  bool get isAdminGranted => grantedByAdmin != null && grantedByAdmin!.isNotEmpty;
}

/// App-wide configuration for ads and features.
/// Stored in app_config collection.
class AppConfig {
  final String id;
  final String configKey;
  final Map<String, dynamic> configValue;
  final DateTime updatedAt;

  AppConfig({
    required this.id,
    required this.configKey,
    required this.configValue,
    required this.updatedAt,
  });

  factory AppConfig.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AppConfig(
      id: docId ?? '',
      configKey: map['config_key'] ?? '',
      configValue: Map<String, dynamic>.from(map['config_value'] ?? {}),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'config_key': configKey,
      'config_value': configValue,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get typed value from config_value
  T? getValue<T>(String key) {
    final val = configValue[key];
    if (val is T) return val;
    return null;
  }
}

/// AdMob configuration stored per environment (test/prod).
/// Stored in ad_config collection.
class AdConfig {
  final String id;
  final String environment; // "test" or "production"
  final String appIdAndroid; // AdMob App ID for Android
  final String appIdIOS; // AdMob App ID for iOS
  final String bannerAdUnitId;
  final String interstitialAdUnitId;
  final String rewardedAdUnitId;
  final String nativeAdUnitId;
  final bool isActive;
  final int interstitialIntervalSeconds; // Min seconds between interstitials
  final int maxInterstitialsPerSession;
  final DateTime updatedAt;

  AdConfig({
    required this.id,
    required this.environment,
    required this.appIdAndroid,
    required this.appIdIOS,
    required this.bannerAdUnitId,
    required this.interstitialAdUnitId,
    required this.rewardedAdUnitId,
    required this.nativeAdUnitId,
    required this.isActive,
    required this.interstitialIntervalSeconds,
    required this.maxInterstitialsPerSession,
    required this.updatedAt,
  });

  factory AdConfig.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AdConfig(
      id: docId ?? '',
      environment: map['environment'] ?? 'test',
      appIdAndroid: map['app_id_android'] ?? '',
      appIdIOS: map['app_id_ios'] ?? '',
      bannerAdUnitId: map['banner_ad_unit_id'] ?? '',
      interstitialAdUnitId: map['interstitial_ad_unit_id'] ?? '',
      rewardedAdUnitId: map['rewarded_ad_unit_id'] ?? '',
      nativeAdUnitId: map['native_ad_unit_id'] ?? '',
      isActive: map['is_active'] ?? false,
      interstitialIntervalSeconds: map['interstitial_interval_seconds'] ?? 60,
      maxInterstitialsPerSession: map['max_interstitials_per_session'] ?? 3,
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'environment': environment,
      'app_id_android': appIdAndroid,
      'app_id_ios': appIdIOS,
      'banner_ad_unit_id': bannerAdUnitId,
      'interstitial_ad_unit_id': interstitialAdUnitId,
      'rewarded_ad_unit_id': rewardedAdUnitId,
      'native_ad_unit_id': nativeAdUnitId,
      'is_active': isActive,
      'interstitial_interval_seconds': interstitialIntervalSeconds,
      'max_interstitials_per_session': maxInterstitialsPerSession,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}