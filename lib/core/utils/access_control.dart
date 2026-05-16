import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/subscription_service.dart';
import '../services/ad_service.dart';
import '../theme/app_colors.dart';

/// Access control helper for subscription-gated content.
///
/// Use this class throughout the app to:
/// - Check if user can access certain features
/// - Check if content should be visible/gated
/// - Determine history date limits for free users
class AccessControl extends GetxService {
  late final SubscriptionService _subsService;
  late final AdService _adService;

  /// Initialize access control (called from main.dart after services are ready)
  Future<void> init() async {
    _subsService = Get.find<SubscriptionService>();
    _adService = Get.find<AdService>();
  }

  /// Check if user has premium access
  bool get isPremium => _subsService.isPremiumUser;

  /// Check if user is in free trial
  bool get isInTrial => _subsService.isInTrial;

  /// Check if ads should be visible (ads enabled AND not premium)
  bool get showAds => _adService.adsEnabled.value;

  /// Get max history days for current user (0 = unlimited)
  int get historyDaysLimit => _subsService.historyAccessDays;

  /// Check if a workout date is within accessible history range.
  /// Returns true if workout is accessible (date is within allowed history window).
  bool canAccessWorkoutDate(DateTime workoutDate) {
    // Premium users have unlimited access
    if (isPremium || isInTrial) return true;

    // Free users have limited history
    final limit = historyDaysLimit;
    if (limit == 0) return true; // No limit configured, allow all

    final cutoffDate = DateTime.now().subtract(Duration(days: limit));
    return workoutDate.isAfter(cutoffDate) || workoutDate.isAtSameMomentAs(cutoffDate);
  }

  /// Get workouts that are accessible for the current user.
  /// Filters out workouts older than the history limit for free users.
  List<Map<String, dynamic>> filterAccessibleWorkouts(List<Map<String, dynamic>> workouts) {
    if (isPremium || isInTrial) return workouts;

    final limit = historyDaysLimit;
    if (limit == 0) return workouts;

    final cutoffMs = DateTime.now().subtract(Duration(days: limit)).millisecondsSinceEpoch;
    return workouts.where((w) {
      final ts = w['startedAt'] ?? 0;
      return ts >= cutoffMs;
    }).toList();
  }

  /// Check if user has a specific feature enabled
  bool hasFeature(String feature) => _subsService.hasFeature(feature);

  /// Check if user can use advanced analytics
  bool get canUseAdvancedAnalytics => hasFeature('advanced_analytics');

  /// Check if user can use offline sync
  bool get canUseOfflineSync => hasFeature('offline_sync');

  /// Check if user can use custom exercises
  bool get canUseCustomExercises => hasFeature('custom_exercises');

  /// Check if user can export data
  bool get canExportData => hasFeature('data_export');

  /// Get greeting based on subscription level
  String get accessLevelGreeting {
    if (isPremium) return 'Premium Member';
    if (isInTrial) return 'Trial Member';
    return 'Free User';
  }

  /// Check if history is limited (for displaying "upgrade to see more" banners)
  bool get isHistoryLimited => !isPremium && !isInTrial && historyDaysLimit > 0;

  /// Get days until history limit warning (for displaying upgrade prompts)
  int? getDaysUntilHistoryLimitWarning(DateTime workoutDate) {
    if (isPremium || isInTrial) return null;
    if (historyDaysLimit == 0) return null;

    final daysSince = DateTime.now().difference(workoutDate).inDays;
    final daysUntilLimit = historyDaysLimit - daysSince;

    // Return warning if within 7 days of limit
    if (daysUntilLimit <= 7 && daysUntilLimit > 0) return daysUntilLimit;
    return null;
  }
}

/// Widget that wraps premium-only content.
/// Shows upgrade prompt instead of content for free users.
///
/// Usage:
/// ```dart
/// PremiumGate(
///   feature: 'advanced_analytics',
///   child: AdvancedAnalyticsChart(),
///   fallback: BasicChart(),
/// )
/// ```
class PremiumGate extends StatelessWidget {
  final String? feature;
  final Widget child;
  final Widget? fallback;
  final bool showUpgradePrompt;

  const PremiumGate({
    super.key,
    this.feature,
    required this.child,
    this.fallback,
    this.showUpgradePrompt = true,
  });

  @override
  Widget build(BuildContext context) {
    final access = Get.find<AccessControl>();

    // If no specific feature, just check premium status
    if (feature == null) {
      if (access.isPremium || access.isInTrial) return child;
      return fallback ?? const SizedBox.shrink();
    }

    // Check specific feature
    if (access.hasFeature(feature!)) return child;

    if (!showUpgradePrompt) return fallback ?? const SizedBox.shrink();

    // Show upgrade prompt
    return _UpgradePrompt(feature: feature!);
  }
}

class _UpgradePrompt extends StatelessWidget {
  final String feature;

  const _UpgradePrompt({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getFeatureTitle(feature),
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock with Premium',
            style: TextStyle(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Get.toNamed('/subscription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  String _getFeatureTitle(String feature) {
    switch (feature) {
      case 'advanced_analytics':
        return 'Advanced Analytics';
      case 'offline_sync':
        return 'Offline Sync';
      case 'custom_exercises':
        return 'Custom Exercises';
      case 'data_export':
        return 'Data Export';
      case 'unlimited_history':
        return 'Full History';
      default:
        return feature.replaceAll('_', ' ').capitalizeFirst ?? feature;
    }
  }
}

/// Widget that shows a banner prompting upgrade if history is limited.
class HistoryLimitBanner extends StatelessWidget {
  final int daysRemaining;

  const HistoryLimitBanner({super.key, required this.daysRemaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Limited History',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upgrade to view workouts older than $daysRemaining days',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => Get.toNamed('/subscription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Upgrade', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}