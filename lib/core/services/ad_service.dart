import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_models.dart';
import '../utils/debug_log.dart';
import 'subscription_service.dart';

/// Ad service that wraps Google AdMob.
///
/// ## Setup Requirements (when ready to publish):
/// 1. Create `ad_config` collection in Appwrite with ad unit IDs
/// 2. Set AdMob App IDs in Appwrite (one for Android, one for iOS)
/// 3. Set ad unit IDs for each format in Appwrite
/// 4. Add your AdMob App ID to AndroidManifest.xml and Info.plist
///
/// ## Ad serving logic:
/// - Ads are NEVER loaded for premium users (checked via SubscriptionService)
/// - If no ad config exists in DB, no ads are shown (graceful degradation)
/// - All ad calls are fire-and-forget - failures don't crash the app
///
/// ## Supported ad formats:
/// - Banner (inline display at bottom of screens)
/// - Interstitial (full-screen between workouts)
/// - Rewarded (user opts in to earn rewards/premium access)
class AdService extends GetxService {
  late final SubscriptionService _subsService;
  final _log = DebugLog.instance;

  // Ad state
  final RxBool isInitialized = false.obs;
  final RxBool isLoadingAd = false.obs;
  final RxBool adsEnabled = false.obs; // Global on/off (also checks subscription)
  final Rxn<AdConfig> config = Rxn<AdConfig>();

  // Banner ad
  BannerAd? _bannerAd;
  final RxBool bannerLoaded = false.obs;

  // Interstitial ad
  InterstitialAd? _interstitialAd;
  int _interstitialCountThisSession = 0;
  DateTime? _lastInterstitialTime;
  final RxBool interstitialReady = false.obs;

  // Rewarded ad
  RewardedAd? _rewardedAd;
  final RxBool rewardedReady = false.obs;

  // Cache keys
  static const String _kAdEnabledCache = 'ad_service_enabled';

  @override
  void onInit() {
    super.onInit();
    _subsService = Get.find<SubscriptionService>();
    init();
  }

  /// Initialize the ad service. Safe to call multiple times.
  Future<AdService> init() async {
    if (isInitialized.value) return this;

    try {
      // Subscribe to subscription changes to update ad visibility
      ever(_subsService.currentSubscription, (_) => _updateAdVisibility());

      // Load ad config from subscription service
      config.value = _subsService.adConfig.value;

      // Initial ad visibility check
      await _updateAdVisibility();

      // Initialize Google Mobile Ads SDK
      await _initGoogleAds();

      isInitialized.value = true;
      _log.info('[AdService] Initialized successfully');
    } catch (e) {
      _log.error('[AdService] Init failed', data: e.toString());
      // Don't fail - allow app to work without ads
      isInitialized.value = true;
    }

    return this;
  }

  /// Initialize Google Mobile Ads SDK.
  Future<void> _initGoogleAds() async {
    try {
      // Get app ID from config or use test ID
      final appId = _getAppId();
      
      if (appId.isEmpty) {
        _log.info('[AdService] No AdMob App ID configured (expected if not setup yet)');
        return;
      }

      await MobileAds.instance.initialize();
      _log.info('[AdService] Google Mobile Ads SDK initialized');

      // Load ads based on config
      if (adsEnabled.value && config.value != null) {
        await _loadBannerAd();
        await _preloadInterstitial();
      }
    } catch (e) {
      _log.error('[AdService] Google Ads init failed', data: e.toString());
    }
  }

  /// Get AdMob App ID for current platform.
  String _getAppId() {
    final adCfg = config.value;
    if (adCfg == null || !adCfg.isActive) return '';

    if (Platform.isAndroid) {
      return adCfg.appIdAndroid.isNotEmpty ? adCfg.appIdAndroid : '';
    } else if (Platform.isIOS) {
      return adCfg.appIdIOS.isNotEmpty ? adCfg.appIdIOS : '';
    }
    return '';
  }

  /// Update whether ads should be shown based on subscription status.
  Future<void> _updateAdVisibility() async {
    final shouldShowAds = _shouldWeShowAds();
    adsEnabled.value = shouldShowAds;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdEnabledCache, shouldShowAds);

    _log.info('[AdService] Ads enabled: $shouldShowAds (premium: ${_subsService.isPremiumUser})');

    // Load or unload ads based on visibility
    if (shouldShowAds && isInitialized.value) {
      await _loadAds();
    } else {
      await _unloadAds();
    }
  }

  /// Determine if we should show ads.
  /// Returns true if:
  /// - Ad config exists and is active
  /// - User is NOT a premium subscriber
  /// - App-wide ads are enabled in config
  bool _shouldWeShowAds() {
    // Never show ads for premium users
    if (_subsService.isPremiumUser) {
      _log.info('[AdService] User is premium - no ads');
      return false;
    }

    // Check if ad config exists and is active
    final adCfg = _subsService.adConfig.value;
    if (adCfg == null || !adCfg.isActive) {
      _log.info('[AdService] No active ad config - no ads');
      return false;
    }

    _log.info('[AdService] Ad config active, user is free tier - ads ENABLED');
    return true;
  }

  /// Load all ads.
  Future<void> _loadAds() async {
    await Future.wait([
      _loadBannerAd(),
      _preloadInterstitial(),
    ]);
  }

  /// Unload all ads.
  Future<void> _unloadAds() async {
    _bannerAd?.dispose();
    _bannerAd = null;
    bannerLoaded.value = false;

    _interstitialAd?.dispose();
    _interstitialAd = null;
    interstitialReady.value = false;

    _rewardedAd?.dispose();
    _rewardedAd = null;
    rewardedReady.value = false;
  }

  /// Load banner ad.
  Future<void> _loadBannerAd() async {
    try {
      final adCfg = config.value;
      if (adCfg == null) return;
      if (adCfg.bannerAdUnitId.isEmpty) return;

      _bannerAd?.dispose();
      _bannerAd = BannerAd(
        adUnitId: adCfg.bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _log.info('[AdService] Banner ad loaded');
            bannerLoaded.value = true;
          },
          onAdFailedToLoad: (ad, error) {
            _log.error('[AdService] Banner ad failed to load', data: error.toString());
            bannerLoaded.value = false;
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      _log.error('[AdService] Failed to load banner ad', data: e.toString());
    }
  }

  /// Preload interstitial ad.
  Future<void> _preloadInterstitial() async {
    try {
      final adCfg = config.value;
      if (adCfg == null) return;
      if (adCfg.interstitialAdUnitId.isEmpty) return;

      await InterstitialAd.load(
        adUnitId: adCfg.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _log.info('[AdService] Interstitial ad loaded');
            _interstitialAd = ad;
            interstitialReady.value = true;
          },
          onAdFailedToLoad: (error) {
            _log.error('[AdService] Interstitial ad failed to load', data: error.toString());
            interstitialReady.value = false;
          },
        ),
      );
    } catch (e) {
      _log.error('[AdService] Failed to preload interstitial', data: e.toString());
    }
  }

  /// Load rewarded ad.
  Future<void> _loadRewardedAd() async {
    try {
      final adCfg = config.value;
      if (adCfg == null) return;
      if (adCfg.rewardedAdUnitId.isEmpty) return;

      await RewardedAd.load(
        adUnitId: adCfg.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _log.info('[AdService] Rewarded ad loaded');
            _rewardedAd = ad;
            rewardedReady.value = true;
          },
          onAdFailedToLoad: (error) {
            _log.error('[AdService] Rewarded ad failed to load', data: error.toString());
            rewardedReady.value = false;
          },
        ),
      );
    } catch (e) {
      _log.error('[AdService] Failed to load rewarded ad', data: e.toString());
    }
  }

  /// Check if ads are currently available and should be shown.
  bool get canShowAds => adsEnabled.value && !isLoadingAd.value;

  /// Check if we should show an interstitial ad based on session limits.
  bool shouldShowInterstitial() {
    if (!adsEnabled.value) return false;

    final adCfg = config.value;
    if (adCfg == null) return false;

    // Check session limit
    if (_interstitialCountThisSession >= adCfg.maxInterstitialsPerSession) {
      _log.info('[AdService] Max interstitials per session reached');
      return false;
    }

    // Check time interval
    if (_lastInterstitialTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialTime!).inSeconds;
      if (elapsed < adCfg.interstitialIntervalSeconds) {
        _log.info('[AdService] Interstitial interval not met (${elapsed}s elapsed)');
        return false;
      }
    }

    return interstitialReady.value;
  }

  /// Show an interstitial ad if available and allowed.
  Future<void> showInterstitialIfReady() async {
    if (!shouldShowInterstitial()) {
      _log.info('[AdService] showInterstitialIfReady: conditions not met');
      return;
    }

    _log.info('[AdService] Showing interstitial ad');

    final ad = _interstitialAd;
    if (ad == null) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _log.info('[AdService] Interstitial dismissed');
        _interstitialCountThisSession++;
        _lastInterstitialTime = DateTime.now();
        interstitialReady.value = false;
        _preloadInterstitial(); // Preload next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log.error('[AdService] Interstitial failed to show', data: error.toString());
        interstitialReady.value = false;
        _preloadInterstitial();
      },
    );

    await ad.show();
  }

  /// Show a rewarded ad when user opts in (e.g., to unlock extra features).
  Future<bool> showRewardedAd({VoidCallback? onEarnedReward}) async {
    if (!adsEnabled.value) return false;

    final adCfg = config.value;
    if (adCfg == null || adCfg.rewardedAdUnitId.isEmpty) return false;

    // Load rewarded ad if not loaded
    if (_rewardedAd == null || !rewardedReady.value) {
      await _loadRewardedAd();
      if (_rewardedAd == null) return false;
    }

    final ad = _rewardedAd!;
    bool earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _log.info('[AdService] Rewarded ad dismissed');
        rewardedReady.value = false;
        _loadRewardedAd(); // Preload next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log.error('[AdService] Rewarded ad failed to show', data: error.toString());
        rewardedReady.value = false;
        _loadRewardedAd();
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        _log.info('[AdService] User earned reward: ${reward.amount}');
        earnedReward = true;
        onEarnedReward?.call();
      },
    );

    return earnedReward;
  }

  /// Get banner ad widget to display.
  Widget? getBannerWidget() {
    if (!adsEnabled.value) return null;
    if (_bannerAd == null || !bannerLoaded.value) return null;

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  /// Called when user completes a workout to potentially show an interstitial.
  void onWorkoutCompleted() {
    if (!shouldShowInterstitial()) return;

    _log.info('[AdService] Workout completed - showing interstitial');
    showInterstitialIfReady();
  }

  /// Called when user views progress page.
  void onProgressViewed() {
    if (!shouldShowInterstitial()) return;

    _log.info('[AdService] Progress viewed - showing interstitial');
    showInterstitialIfReady();
  }

  /// Reset session ad counts (e.g., when user starts a new session).
  void resetSessionCounts() {
    _interstitialCountThisSession = 0;
    _lastInterstitialTime = null;
    _log.info('[AdService] Session ad counts reset');
  }

  /// Check if a specific feature requires watching an ad (rewarded).
  bool isRewardedFeature(String feature) {
    // Define which features are ad-supported vs premium-only
    return false;
  }

  /// Refresh ad configuration from Appwrite.
  Future<void> refreshConfig() async {
    await _subsService.refreshAdConfig();
    config.value = _subsService.adConfig.value;
    await _updateAdVisibility();
  }

  /// Force update ad visibility (call when subscription changes).
  void updateAdVisibility() {
    _updateAdVisibility();
  }

  @override
  void onClose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.onClose();
  }
}