import 'package:get/get.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/store_service.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/models/subscription_models.dart';

/// Controller for the subscription management screen.
class SubscriptionController extends GetxController {
  late final SubscriptionService _subsService;
  late final StoreService _storeService;
  late final AdService _adService;

  // UI State
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnString successMessage = RxnString();
  final RxBool isPurchasing = false.obs;

  // Selected plan for display/purchase
  final Rxn<SubscriptionPlan> selectedPlan = Rxn<SubscriptionPlan>();

  @override
  void onInit() {
    super.onInit();
    _subsService = Get.find<SubscriptionService>();
    _storeService = Get.find<StoreService>();
    _adService = Get.find<AdService>();

    // Listen to subscription changes
    ever(_subsService.currentSubscription, (_) => update());

    // Listen to store errors
    ever(_storeService.errorMessage, (err) {
      if (err != null) errorMessage.value = err;
    });
  }

  /// Get all available plans
  List<SubscriptionPlan> get availablePlans => _subsService.activePlans;

  /// Get current user's subscription
  UserSubscription? get currentSubscription => _subsService.currentSubscription.value;

  /// Get current plan details
  SubscriptionPlan? get currentPlan => _subsService.currentPlan;

  /// Check if user is premium
  bool get isPremium => _subsService.isPremiumUser;

  /// Check if user is in trial
  bool get isInTrial => _subsService.isInTrial;

  /// Check if ads are shown
  bool get adsVisible => _adService.adsEnabled.value;

  /// Get user's history access days (0 = unlimited)
  int get historyAccessDays => _subsService.historyAccessDays;

  /// Check if user has a specific feature
  bool hasFeature(String feature) => _subsService.hasFeature(feature);

  /// Select a plan for purchase
  void selectPlan(SubscriptionPlan plan) {
    selectedPlan.value = plan;
    errorMessage.value = null;
    successMessage.value = null;
  }

  /// Clear selected plan
  void clearSelection() {
    selectedPlan.value = null;
  }

  /// Purchase selected plan
  Future<void> purchaseSelectedPlan() async {
    final plan = selectedPlan.value;
    if (plan == null) return;

    isPurchasing.value = true;
    errorMessage.value = null;
    successMessage.value = null;

    try {
      final success = await _storeService.requestSubscription(plan.planId);
      if (success) {
        successMessage.value = 'Successfully subscribed to ${plan.name}!';
        clearSelection();
        // Ads should automatically hide now that user is subscribed
        _adService.updateAdVisibility();
      }
    } catch (e) {
      errorMessage.value = 'Purchase failed. Please try again.';
    } finally {
      isPurchasing.value = false;
    }
  }

  /// Start free trial for selected plan
  Future<void> startFreeTrial() async {
    final plan = selectedPlan.value;
    if (plan == null) return;

    if (!plan.hasFreeTrial) {
      errorMessage.value = 'Free trial not available for this plan';
      return;
    }

    isPurchasing.value = true;
    errorMessage.value = null;
    successMessage.value = null;

    try {
      final success = await _storeService.startFreeTrial(plan.planId);
      if (success) {
        successMessage.value = 'Free trial started for ${plan.name}!';
        clearSelection();
      }
    } catch (e) {
      errorMessage.value = 'Failed to start free trial. Please try again.';
    } finally {
      isPurchasing.value = false;
    }
  }

  /// Restore purchases (reinstall, switch device)
  Future<void> restorePurchases() async {
    isLoading.value = true;
    errorMessage.value = null;
    successMessage.value = null;

    try {
      await _storeService.restorePurchases();
      successMessage.value = 'Purchases restored successfully!';
    } catch (e) {
      errorMessage.value = 'No previous purchases found.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Get status text for current subscription
  String get subscriptionStatusText {
    final sub = currentSubscription;
    final plan = currentPlan;

    if (sub == null) {
      return 'Free Plan - Limited History';
    }

    switch (sub.status) {
      case 'active':
        if (sub.isLifetime) return 'Lifetime Access';
        if (sub.expiresAt != null) {
          final days = sub.expiresAt!.difference(DateTime.now()).inDays;
          return 'Active - $days days remaining';
        }
        return 'Active';
      case 'trial':
        if (sub.trialEndsAt != null) {
          final days = sub.trialEndsAt!.difference(DateTime.now()).inDays;
          return 'Free Trial - $days days left';
        }
        return 'Free Trial';
      case 'granted':
        return 'Promotional Access';
      case 'expired':
        return 'Subscription Expired';
      case 'cancelled':
        return 'Subscription Cancelled';
      default:
        return sub.status;
    }
  }

  /// Check if selected plan has free trial
  bool get selectedPlanHasTrial => selectedPlan.value?.hasFreeTrial ?? false;

  /// Check if selected plan is free
  bool get selectedPlanIsFree => selectedPlan.value?.isFree ?? selectedPlan.value?.price == 0;

  /// Clear messages
  void clearMessages() {
    errorMessage.value = null;
    successMessage.value = null;
  }

  /// Refresh all subscription data
  Future<void> refresh() async {
    isLoading.value = true;
    try {
      await _subsService.refreshAll();
    } finally {
      isLoading.value = false;
    }
  }
}