# SWRkT App - Subscription & Billing Setup Guide

## Overview
This document describes how to set up the subscription, billing, and ad system in Appwrite when you're ready.

---

## 1. Create Appwrite Collections

### Collection: `subscription_plans`
Stores subscription plan definitions. Create in Appwrite Dashboard > Database > {databaseId} > New Collection.

**Attributes:**
| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| plan_id | String | Yes | Unique ID like "monthly", "yearly", "lifetime" |
| name | String | Yes | Display name like "Premium Monthly" |
| description | String | No | Short description |
| price | Double | Yes | Price in USD (0 for free) |
| currency | String | Yes | "USD", "EUR", etc. |
| duration_days | Integer | Yes | 30 for monthly, 365 for yearly, 0 for lifetime |
| is_lifetime | Boolean | Yes | True for lifetime plans |
| is_free | Boolean | Yes | True for free tier |
| is_default | Boolean | Yes | True to show as default/selected |
| free_history_days | Integer | Yes | Days free users can see (0 = unlimited) |
| free_trial_days | Integer | Yes | 0 = no trial, 7/14/30 for trial period |
| enabled_features | String[] | No | Feature flags like ["advanced_analytics", "offline_sync"] |
| ads_enabled | Boolean | Yes | Whether this plan shows ads |
| sort_order | Integer | Yes | Display order |
| is_active | Boolean | Yes | False to hide from store |
| created_at | Datetime | Auto | Creation timestamp |
| updated_at | Datetime | Auto | Last update timestamp |

**Indexes:**
- `plan_id` (unique)
- `is_active` (for filtering active plans)

---

### Collection: `app_config`
Stores global app configuration (feature flags, defaults, etc.).

**Attributes:**
| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| config_key | String | Yes | Unique key like "global_config" |
| config_value | String[] | No | JSON-like key-value pairs |
| updated_at | Datetime | Auto | Last update timestamp |

**Sample `config_value` (JSON):**
```json
{
  "default_free_history_days": 30,
  "max_free_history_days": 90,
  "ad_refresh_interval_seconds": 60,
  "feature_flags": {
    "enable_beta_features": false,
    "require_email_verification": true
  }
}
```

---

### Collection: `user_subscriptions`
Stores each user's subscription status.

**Attributes:**
| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| user_id | String | Yes | Appwrite user ID |
| plan_id | String | Yes | Reference to plan_id in subscription_plans |
| status | String | Yes | "active", "trial", "expired", "cancelled", "granted" |
| started_at | Datetime | No | Subscription start date |
| expires_at | Datetime | No | Expiration date (null for lifetime) |
| trial_ends_at | Datetime | No | Trial end date |
| is_lifetime | Boolean | Yes | True for lifetime access |
| promo_code | String | No | Promo code used (if any) |
| granted_by_admin | String | No | Admin user ID who granted (for admin grants) |
| store_receipt | String | No | Store purchase receipt |
| store_platform | String | No | "google_play", "apple_store", "admin", "promo" |
| created_at | Datetime | Auto | Creation timestamp |
| updated_at | Datetime | Auto | Last update timestamp |

**Indexes:**
- `user_id` (for fast lookup)
- `status` (for filtering active subscriptions)

---

### Collection: `ad_config`
Stores AdMob configuration.

**Attributes:**
| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| environment | String | Yes | "test" or "production" |
| app_id_android | String | No | AdMob App ID for Android |
| app_id_ios | String | No | AdMob App ID for iOS |
| banner_ad_unit_id | String | No | AdMob Banner Ad Unit ID |
| interstitial_ad_unit_id | String | No | AdMob Interstitial Ad Unit ID |
| rewarded_ad_unit_id | String | No | AdMob Rewarded Ad Unit ID |
| native_ad_unit_id | String | No | AdMob Native Ad Unit ID |
| is_active | Boolean | Yes | Enable/disable ads |
| interstitial_interval_seconds | Integer | No | Min seconds between interstitials (default: 60) |
| max_interstitials_per_session | Integer | No | Max interstitials per session (default: 3) |
| updated_at | Datetime | Auto | Last update timestamp |

---

### Collection: `promo_grants`
Stores promotional grants and promo codes.

**Attributes:**
| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| plan_id | String | Yes | Plan to grant for free |
| promo_code | String | No | Unique promo code (optional - if empty, applies to all) |
| start_time | Datetime | Yes | When promo becomes active |
| end_time | Datetime | No | When promo expires (null = no end) |
| max_claims | Integer | No | Max number of claims (null = unlimited) |
| current_claims | Integer | Yes | Current number of claims made |
| is_active | Boolean | Yes | Enable/disable promo |
| created_at | Datetime | Auto | Creation timestamp |
| updated_at | Datetime | Auto | Last update timestamp |

---

## 2. Sample Data

### Default Subscription Plan (Free)
```json
{
  "plan_id": "free",
  "name": "Free Plan",
  "description": "Basic access with limited history",
  "price": 0,
  "currency": "USD",
  "duration_days": 0,
  "is_lifetime": false,
  "is_free": true,
  "is_default": true,
  "free_history_days": 30,
  "free_trial_days": 0,
  "enabled_features": [],
  "ads_enabled": true,
  "sort_order": 0,
  "is_active": true
}
```

### Premium Monthly Plan
```json
{
  "plan_id": "monthly",
  "name": "Premium Monthly",
  "description": "Full access with unlimited history and no ads",
  "price": 4.99,
  "currency": "USD",
  "duration_days": 30,
  "is_lifetime": false,
  "is_free": false,
  "is_default": false,
  "free_history_days": 0,
  "free_trial_days": 7,
  "enabled_features": ["advanced_analytics", "offline_sync", "custom_exercises", "data_export"],
  "ads_enabled": false,
  "sort_order": 1,
  "is_active": true
}
```

### Premium Yearly Plan
```json
{
  "plan_id": "yearly",
  "name": "Premium Yearly",
  "description": "Best value - full access at a discounted rate",
  "price": 29.99,
  "currency": "USD",
  "duration_days": 365,
  "is_lifetime": false,
  "is_free": false,
  "is_default": false,
  "free_history_days": 0,
  "free_trial_days": 14,
  "enabled_features": ["advanced_analytics", "offline_sync", "custom_exercises", "data_export"],
  "ads_enabled": false,
  "sort_order": 2,
  "is_active": true
}
```

### Lifetime Plan
```json
{
  "plan_id": "lifetime",
  "name": "Lifetime Premium",
  "description": "One-time payment for lifetime access",
  "price": 99.99,
  "currency": "USD",
  "duration_days": 0,
  "is_lifetime": true,
  "is_free": false,
  "is_default": false,
  "free_history_days": 0,
  "free_trial_days": 0,
  "enabled_features": ["advanced_analytics", "offline_sync", "custom_exercises", "data_export"],
  "ads_enabled": false,
  "sort_order": 3,
  "is_active": true
}
```

### App Config (Global Settings)
```json
{
  "config_key": "global_config",
  "config_value": {
    "default_free_history_days": 30,
    "max_free_history_days": 90,
    "ad_refresh_interval_seconds": 60
  }
}
```

### Ad Config (Test Mode)
```json
{
  "environment": "test",
  "app_id_android": "ca-app-pub-0000000000000000~0000000000",
  "app_id_ios": "ca-app-pub-0000000000000000~0000000000",
  "banner_ad_unit_id": "ca-app-pub-0000000000000000/0000000000",
  "interstitial_ad_unit_id": "ca-app-pub-0000000000000000/0000000000",
  "rewarded_ad_unit_id": "ca-app-pub-0000000000000000/0000000000",
  "is_active": true,
  "interstitial_interval_seconds": 60,
  "max_interstitials_per_session": 3
}
```

---

## 3. Admin Operations

### Grant Subscription (via AdminService)
You can grant subscription access without purchase:

```dart
// In your admin code:
Get.find<AdminService>().grantSubscription(
  targetUserId: 'user_id_to_grant',
  planId: 'monthly',
  durationDays: 30, // or -1 for lifetime
  reason: 'Testing account',
);
```

### Create Promotional Plan (time-limited free access)
```dart
Get.find<AdminService>().createPromotionalPlan(
  planId: 'monthly',
  startTime: DateTime.now(),
  endTime: DateTime.now().add(Duration(days: 7)),
  maxClaims: 100,
  promoCode: 'LAUNCH2024',
);
```

### Revoke Subscription
```dart
Get.find<AdminService>().revokeSubscription(
  targetUserId: 'user_id',
  subscriptionId: 'subscription_doc_id',
  reason: 'Violation of terms',
);
```

---

## 4. AdMob Setup

1. Create AdMob account at https://apps.admob.com
2. Add your app (Android and iOS separately)
3. Create ad units:
   - Banner ad unit
   - Interstitial ad unit
   - Rewarded ad unit (optional)
4. Copy the App IDs and Ad Unit IDs
5. Add them to the `ad_config` collection in Appwrite

**Important:**
- Use test IDs during development: `ca-app-pub-3940256099942544/6300978111`
- Replace with real IDs only when ready to publish
- Test ads are always shown for test IDs, no real impressions

---

## 5. In-App Purchase Setup

### Google Play
1. Create Google Play Developer account
2. Create products/subscriptions in Play Console
3. Set product IDs in plan's `store_product_ids` config

### Apple Store
1. Create Apple Developer account
2. Create in-app purchases in App Store Connect
3. Set product IDs in plan's `store_product_ids` config

---

## 6. Feature Flags

Available features you can assign to plans:
- `advanced_analytics` - Charts, graphs, detailed stats
- `offline_sync` - Full offline access with sync
- `custom_exercises` - Create/edit custom exercises
- `data_export` - Export workout data

---

## 7. Testing Checklist

Before publishing:

- [ ] Create all collections in Appwrite
- [ ] Add default subscription plans (at least free + one paid)
- [ ] Add app_config with your defaults
- [ ] Test free tier - verify history limits work
- [ ] Test subscription purchase flow
- [ ] Test free trial start and expiration
- [ ] Test admin grant - give yourself premium without paying
- [ ] Test ad display (if configured)
- [ ] Test ad hiding for premium users
- [ ] Test promo code creation and claiming
- [ ] Verify no crashes when collections are empty (graceful degradation)