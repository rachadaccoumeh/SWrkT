abstract final class AppwriteConstants {
  static const String projectId = '69fc0a0b0023ca8230d1';
  static const String endpoint = 'https://appwrite.ubity.dev/v1';

  // New database visible in Appwrite Console
  static const String databaseId = '6a048a51003b1153416d';

  static const String usersCollection = 'users';
  static const String exercisesCollection = 'exercises';
  static const String workoutsCollection = 'workouts';
  static const String setsCollection = 'sets';
  static const String prefsCollection = 'preferences';

  static const String imagesBucket = 'exercise_images';

  // === SUBSCRIPTION & BILLING COLLECTIONS ===
  // Stores subscription plan definitions (name, price, duration, features, etc.)
  static const String subscriptionPlansCollection = 'subscription_plans';

  // Global app configuration (ad keys, feature flags, defaults)
  static const String appConfigCollection = 'app_config';

  // Per-user subscription records (actual purchases, trials, grants)
  static const String userSubscriptionsCollection = 'user_subscriptions';

  // Ad configuration (AdMob IDs, ad units, enable/disable per plan)
  static const String adConfigCollection = 'ad_config';

  // Promo/grants for free access periods
  static const String promoGrantsCollection = 'promo_grants';
}