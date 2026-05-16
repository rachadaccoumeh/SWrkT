import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/subscription_models.dart';
import '../controllers/subscription_controller.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SubscriptionController());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.onSurface),
          onPressed: () => Get.back(),
        ),
        title: const Text('Upgrade', style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          if (controller.isPremium)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star, color: AppColors.primary, size: 16),
                  SizedBox(width: 4),
                  Text('Premium', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.availablePlans.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final plans = controller.availablePlans;

        return RefreshIndicator(
          onRefresh: controller.refresh,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Current status card
              _StatusCard(controller: controller),
              const SizedBox(height: 24),

              // Free trial notice if applicable
              if (controller.isInTrial) ...[
                _TrialNotice(controller: controller),
                const SizedBox(height: 16),
              ],

              // Plans header
              Text(
                controller.isPremium ? 'Change Plan' : 'Choose Your Plan',
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Plans list
              ...plans.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlanCard(
                  plan: plan,
                  isSelected: controller.selectedPlan.value?.planId == plan.planId,
                  onTap: () => controller.selectPlan(plan),
                ),
              )),

              // Selected plan CTA
              if (controller.selectedPlan.value != null) ...[
                const SizedBox(height: 8),
                _PurchaseSection(controller: controller),
              ],

              // Features comparison
              const SizedBox(height: 24),
              _FeaturesSection(controller: controller),

              // Restore purchases
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: controller.restorePurchases,
                  child: const Text(
                    'Restore Purchases',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      }),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final SubscriptionController controller;
  const _StatusCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: controller.isPremium
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  controller.isPremium ? Icons.star_rounded : Icons.person_outline_rounded,
                  color: controller.isPremium ? AppColors.primary : AppColors.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.isPremium
                          ? (controller.currentPlan?.name ?? 'Premium')
                          : 'Free Plan',
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.subscriptionStatusText,
                      style: TextStyle(
                        color: controller.isPremium ? AppColors.primary : AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!controller.isPremium) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.history, size: 14, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Limited to ${controller.historyAccessDays > 0 ? controller.historyAccessDays : "all"} days history',
                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                ),
                const Spacer(),
                if (controller.adsVisible)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Ads shown',
                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrialNotice extends StatelessWidget {
  final SubscriptionController controller;
  const _TrialNotice({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You\'re on a free trial! Enjoy full access until it ends.',
              style: TextStyle(color: AppColors.primary.withValues(alpha: 0.9), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = plan.isDefault && !plan.isFree;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'POPULAR',
                                style: TextStyle(
                                  color: AppColors.onSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (plan.hasFreeTrial) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'FREE TRIAL',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.description,
                        style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.formattedPrice,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!plan.isFree && !plan.isLifetime)
                      Text(
                        plan.durationDisplay,
                        style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
            if (plan.enabledFeatures.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: plan.enabledFeatures.take(4).map((f) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatFeatureName(f),
                      style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (plan.hasFreeTrial) ...[
              const SizedBox(height: 10),
              Text(
                '${plan.freeTrialDays} days free, then ${plan.formattedPrice}/${plan.durationDisplay.toLowerCase()}',
                style: const TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatFeatureName(String feature) {
    // Convert snake_case or camelCase to Title Case
    return feature
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}

class _PurchaseSection extends StatelessWidget {
  final SubscriptionController controller;
  const _PurchaseSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final plan = controller.selectedPlan.value!;
    final hasTrial = plan.hasFreeTrial;
    final isFree = plan.isFree || plan.price == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selected:',
                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
              ),
              Text(
                plan.name,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isFree)
            ElevatedButton(
              onPressed: controller.isPurchasing.value ? null : () => controller.purchaseSelectedPlan(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: controller.isPurchasing.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2),
                    )
                  : const Text('Get Free Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            )
          else if (hasTrial)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: controller.isPurchasing.value ? null : () => controller.startFreeTrial(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: controller.isPurchasing.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2),
                        )
                      : Text('Start ${plan.freeTrialDays} Day Free Trial', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: controller.isPurchasing.value ? null : () => controller.purchaseSelectedPlan(),
                  child: Text(
                    'Or subscribe now - no trial',
                    style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.8), fontSize: 13),
                  ),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: controller.isPurchasing.value ? null : () => controller.purchaseSelectedPlan(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: controller.isPurchasing.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2),
                    )
                  : Text('Subscribe - ${plan.formattedPrice}/${plan.durationDisplay.toLowerCase()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),

          // Messages
          if (controller.errorMessage.value != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                controller.errorMessage.value!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],
          if (controller.successMessage.value != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                controller.successMessage.value!,
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  final SubscriptionController controller;
  const _FeaturesSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final freePlan = controller.availablePlans.firstWhereOrNull((p) => p.isDefault);
    final premiumPlan = controller.availablePlans.firstWhereOrNull((p) => !p.isDefault && !p.isFree);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What You Get',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _FeatureRow(
          icon: Icons.history,
          label: 'Workout History',
          freeValue: '${freePlan?.freeHistoryDays ?? 30} days',
          premiumValue: 'Unlimited',
          isPremium: controller.isPremium,
        ),
        _FeatureRow(
          icon: Icons.show_chart,
          label: 'Progress Analytics',
          freeValue: 'Basic',
          premiumValue: 'Advanced',
          isPremium: controller.hasFeature('advanced_analytics'),
        ),
        _FeatureRow(
          icon: Icons.cloud_off,
          label: 'Offline Access',
          freeValue: 'Limited',
          premiumValue: 'Full',
          isPremium: controller.hasFeature('offline_sync'),
        ),
        _FeatureRow(
          icon: Icons.ad_units,
          label: 'Ad-Free Experience',
          freeValue: 'No',
          premiumValue: 'Yes',
          isPremium: !controller.adsVisible,
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String freeValue;
  final String premiumValue;
  final bool isPremium;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.freeValue,
    required this.premiumValue,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPremium ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPremium ? AppColors.primary.withValues(alpha: 0.2) : AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isPremium ? AppColors.primary : AppColors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isPremium ? AppColors.primary : AppColors.onSurface,
                fontSize: 14,
                fontWeight: isPremium ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            isPremium ? premiumValue : freeValue,
            style: TextStyle(
              color: isPremium ? AppColors.primary : AppColors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: isPremium ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isPremium ? Icons.check_circle : Icons.lock_outline,
            size: 16,
            color: isPremium ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}