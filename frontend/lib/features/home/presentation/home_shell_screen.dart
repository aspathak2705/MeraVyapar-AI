import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/presentation/fintech_widgets.dart';
import '../../../core/localization/language_selector_button.dart';
import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/local_auth_repository.dart';
import '../../onboarding/data/local_business_profile_repository.dart';
import '../../onboarding/domain/merchant_business_profile.dart';
import '../../intelligence/domain/local_financial_intelligence_engine.dart';
import '../../intelligence/presentation/unified_financial_intelligence_screen.dart';
import '../../memory/data/local_memory_repository.dart';
import '../../procurement/data/local_procurement_repository.dart';
import '../../actions/data/local_action_repository.dart';
import '../../actions/domain/communication_action_model.dart';
import '../../market_intelligence/data/local_supplier_shortlist_repository.dart';

// --- Dashboard Riverpod Providers ---

final dashboardBusinessProfileProvider =
    FutureProvider.autoDispose<MerchantBusinessProfile?>((ref) async {
  final authRepo = ref.watch(localAuthRepositoryProvider);
  final merchantId = authRepo.activeMerchantId;
  if (merchantId == null) return null;
  final profileRepo = ref.watch(localBusinessProfileRepositoryProvider);
  final fallbackName = authRepo.currentSession?.displayName;
  return await profileRepo.getProfile(
      merchantId: merchantId, fallbackName: fallbackName);
});

class DashboardObligationsSummary {
  final int openPromiseCount;
  final int openPromiseTotalPaise;
  final int overduePromiseCount;
  final int pendingPayableCount;
  final int pendingPayableTotalPaise;

  const DashboardObligationsSummary({
    required this.openPromiseCount,
    required this.openPromiseTotalPaise,
    required this.overduePromiseCount,
    required this.pendingPayableCount,
    required this.pendingPayableTotalPaise,
  });
}

final dashboardObligationsSummaryProvider =
    FutureProvider.autoDispose<DashboardObligationsSummary>((ref) async {
  final authRepo = ref.watch(localAuthRepositoryProvider);
  final merchantId = authRepo.activeMerchantId;
  if (merchantId == null) {
    return const DashboardObligationsSummary(
      openPromiseCount: 0,
      openPromiseTotalPaise: 0,
      overduePromiseCount: 0,
      pendingPayableCount: 0,
      pendingPayableTotalPaise: 0,
    );
  }
  final memRepo = ref.watch(localMemoryRepositoryProvider);
  final promises =
      await memRepo.getPaymentPromises(merchantId: merchantId, status: 'OPEN');
  final now = DateTime.now();
  int promisePaise = 0;
  int overdueCount = 0;
  for (final p in promises) {
    final amtRupees = double.tryParse(p.promisedAmount) ?? 0.0;
    promisePaise += (amtRupees * 100).round();
    if (p.dueAt.isBefore(now)) {
      overdueCount++;
    }
  }

  final procRepo = ref.watch(localProcurementRepositoryProvider);
  final obligations =
      await procRepo.getSupplierObligations(merchantId: merchantId);
  int payablePaise = 0;
  int pendingPayableCount = 0;
  for (final ob in obligations) {
    if (ob.status == 'PENDING' || ob.status == 'PARTIALLY_SETTLED') {
      pendingPayableCount++;
      payablePaise += ob.outstandingMinorUnits;
    }
  }

  return DashboardObligationsSummary(
    openPromiseCount: promises.length,
    openPromiseTotalPaise: promisePaise,
    overduePromiseCount: overdueCount,
    pendingPayableCount: pendingPayableCount,
    pendingPayableTotalPaise: payablePaise,
  );
});

final dashboardPriorityActionsProvider =
    FutureProvider.autoDispose<List<CommunicationAction>>((ref) async {
  final authRepo = ref.watch(localAuthRepositoryProvider);
  final merchantId = authRepo.activeMerchantId;
  if (merchantId == null) return [];
  final actionRepo = ref.watch(localActionRepositoryProvider);
  return await actionRepo.fetchActions(
      merchantId: merchantId, statusFilter: 'DRAFT');
});

class DashboardMarketSummary {
  final int shortlistedCount;
  final String? category;
  final String? city;

  const DashboardMarketSummary({
    required this.shortlistedCount,
    this.category,
    this.city,
  });
}

final dashboardMarketSummaryProvider =
    FutureProvider.autoDispose<DashboardMarketSummary>((ref) async {
  final authRepo = ref.watch(localAuthRepositoryProvider);
  final merchantId = authRepo.activeMerchantId;
  if (merchantId == null) {
    return const DashboardMarketSummary(shortlistedCount: 0);
  }

  final shortlistRepo = ref.watch(localSupplierShortlistRepositoryProvider);
  final shortlist = await shortlistRepo.getShortlist(merchantId: merchantId);

  final profileRepo = ref.watch(localBusinessProfileRepositoryProvider);
  final profile = await profileRepo.getProfile(merchantId: merchantId);

  return DashboardMarketSummary(
    shortlistedCount: shortlist.length,
    category:
        profile.businessCategory.isNotEmpty ? profile.businessCategory : null,
    city: profile.city.isNotEmpty ? profile.city : null,
  );
});

/// Unified Merchant Dashboard combining profile context, financial overview,
/// money movements, payment obligations, market intelligence, and priority actions.
class HomeShellScreen extends ConsumerWidget {
  final VoidCallback? onSignOut;
  final VoidCallback? onAddPaymentReceived;
  final VoidCallback? onAddExpense;
  final VoidCallback? onUploadProof;
  final VoidCallback? onViewHistory;
  final VoidCallback? onViewReconciledTransactions;
  final VoidCallback? onOpenCaptureCenter;
  final VoidCallback? onOpenRelationships;
  final VoidCallback? onOpenPromises;
  final VoidCallback? onOpenEvents;
  final VoidCallback? onOpenReceivables;
  final VoidCallback? onOpenAssistant;
  final VoidCallback? onOpenVoiceAssistant;
  final VoidCallback? onOpenMarketSignals;
  final VoidCallback? onOpenActionCenter;
  final VoidCallback? onOpenFinancialIntelligence;
  final VoidCallback? onImportStatement;
  final void Function(String route)? onNavigateToRoute;

  const HomeShellScreen({
    super.key,
    this.onSignOut,
    this.onAddPaymentReceived,
    this.onAddExpense,
    this.onUploadProof,
    this.onViewHistory,
    this.onViewReconciledTransactions,
    this.onOpenCaptureCenter,
    this.onOpenRelationships,
    this.onOpenPromises,
    this.onOpenEvents,
    this.onOpenReceivables,
    this.onOpenAssistant,
    this.onOpenVoiceAssistant,
    this.onOpenMarketSignals,
    this.onOpenActionCenter,
    this.onOpenFinancialIntelligence,
    this.onImportStatement,
    this.onNavigateToRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final positionAsync = ref.watch(financialPositionMetricsProvider);
    final profileAsync = ref.watch(dashboardBusinessProfileProvider);
    final obligationsAsync = ref.watch(dashboardObligationsSummaryProvider);
    final actionsAsync = ref.watch(dashboardPriorityActionsProvider);
    final marketAsync = ref.watch(dashboardMarketSummaryProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkSecondaryBackground
          : AppColors.lightSecondaryBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkLavenderSurface
                    : AppColors.lightLavender,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                AppIcons.business,
                color: isDark
                    ? AppColors.darkPrimaryPurple
                    : AppColors.primaryPurple,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.appTitle ?? 'MeraVyapar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  l10n?.privateDeviceLedger ?? 'Private Device Ledger',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Language Selector Button
          const LanguageSelectorButton(),
          // Business Profile Settings Button
          IconButton(
            icon: const Icon(Icons.storefront_rounded, size: 20),
            tooltip: l10n?.businessProfile ?? 'Business Profile',
            onPressed: () => onNavigateToRoute?.call('/settings/profile'),
          ),
          // Permissions / Privacy Settings Button
          IconButton(
            icon: const Icon(Icons.security_rounded, size: 20),
            tooltip: l10n?.devicePermissions ?? 'Device Permissions & Privacy',
            onPressed: () => onNavigateToRoute?.call('/settings/permissions'),
          ),
          IconButton(
            icon: const Icon(AppIcons.lock, size: 20),
            tooltip: l10n?.lockWorkspace ?? 'Lock Workspace',
            onPressed: onSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Business Profile Context Bar
              _buildBusinessProfileBar(context, isDark, profileAsync, l10n),

              // 2. Financial Overview Hero Card
              _buildFinancialHeroCard(context, isDark, positionAsync, l10n),

              const SizedBox(height: 14),

              // 3. Immediate Action Bar (Money In, Money Out, Statement Import)
              _buildProminentQuickActions(context, isDark, l10n),

              const SizedBox(height: 20),

              // 4. Priority Actions & Business Insights
              _buildPriorityActionsCard(
                  context, isDark, actionsAsync, positionAsync, l10n),

              const SizedBox(height: 20),

              // 5. Payment Promises & Supplier Obligations
              _buildObligationsCard(context, isDark, obligationsAsync, l10n),

              const SizedBox(height: 20),

              // 6. VyaparPulse Market Intelligence Summary
              _buildMarketIntelligenceCard(
                  context, isDark, marketAsync, l10n),

              const SizedBox(height: 20),

              // 7. Financial Services & Tools Grid
              Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.darkPrimaryPurple
                        : AppColors.primaryPurple,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n?.financialServices ?? 'Financial Services',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildQuickActionGrid(context, isDark, l10n),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (idx) {
          switch (idx) {
            case 0:
              break;
            case 1:
              (onOpenFinancialIntelligence ??
                  () => onNavigateToRoute?.call('/intelligence'))();
              break;
            case 2:
              (onViewReconciledTransactions ??
                  () => onNavigateToRoute?.call('/transactions'))();
              break;
            case 3:
              (onOpenReceivables ??
                  () => onNavigateToRoute?.call('/receivables'))();
              break;
            case 4:
              (onOpenActionCenter ??
                  () => onNavigateToRoute?.call('/actions'))();
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(AppIcons.homeOutlined),
            activeIcon: const Icon(AppIcons.home),
            label: l10n?.home ?? 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Icon(AppIcons.analyticsOutlined),
            activeIcon: const Icon(AppIcons.analytics),
            label: l10n?.insights ?? 'Intelligence',
          ),
          BottomNavigationBarItem(
            icon: const Icon(AppIcons.transactionsOutlined),
            activeIcon: const Icon(AppIcons.transactions),
            label: l10n?.transactions ?? 'Passbook',
          ),
          BottomNavigationBarItem(
            icon: const Icon(AppIcons.receivables),
            activeIcon: const Icon(AppIcons.receivables),
            label: l10n?.receivables ?? 'Receivables',
          ),
          BottomNavigationBarItem(
            icon: const Icon(AppIcons.actionsOutlined),
            activeIcon: const Icon(AppIcons.actions),
            label: l10n?.actions ?? 'Actions',
          ),
        ],
      ),
    );
  }

  // --- 1. Business Profile Bar ---
  Widget _buildBusinessProfileBar(
    BuildContext context,
    bool isDark,
    AsyncValue<MerchantBusinessProfile?> profileAsync,
    AppLocalizations? l10n,
  ) {
    return profileAsync.maybeWhen(
      data: (profile) {
        final bName = (profile?.businessName.isNotEmpty == true &&
                profile!.businessName != 'My Business')
            ? profile.businessName
            : (l10n?.businessProfile ?? 'My Business');
        final category = profile?.businessCategory ?? '';
        final location = [
          if (profile?.city.isNotEmpty == true) profile!.city,
          if (profile?.state.isNotEmpty == true) profile!.state,
        ].join(', ');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.lightLavender.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkLavenderSurface
                      : AppColors.lightLavender,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.darkPrimaryPurple
                      : AppColors.primaryPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2E2440)
                                  : const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFD8B4FE)
                                    : AppColors.primaryPurple,
                              ),
                            ),
                          ),
                        if (location.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on,
                                    size: 10, color: Colors.grey),
                                const SizedBox(width: 2),
                                Text(
                                  location,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Private Ledger',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 22),
                tooltip: l10n?.edit ?? 'Edit Profile',
                onPressed: () => onNavigateToRoute?.call('/settings/profile'),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  // --- 2. Financial Overview Hero Card ---
  Widget _buildFinancialHeroCard(
    BuildContext context,
    bool isDark,
    AsyncValue<FinancialPositionMetrics> positionAsync, [
    AppLocalizations? l10n,
  ]) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.primaryPurple,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: positionAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        error: (err, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.netCashMovement ?? 'Net Cash Movement',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text(
              '₹0',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Ready to record transactions ($err)',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        data: (metrics) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n?.netCashMovement ?? 'Net Cash Movement',
                    style: const TextStyle(
                      color: Color(0xFFE9D8FD),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${metrics.transactionCount} txs',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                Money.formatRupees(metrics.netCashMovementInr,
                    showDecimals: false),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n?.totalMoneyIn ?? 'Inflows',
                            style: const TextStyle(
                                color: Color(0xFFE9D8FD), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          Money.formatRupees(metrics.totalInflowsInr,
                              showDecimals: false),
                          style: const TextStyle(
                              color: Color(0xFF86EFAC),
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n?.totalMoneyOut ?? 'Outflows',
                            style: const TextStyle(
                                color: Color(0xFFE9D8FD), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          Money.formatRupees(metrics.totalOutflowsInr,
                              showDecimals: false),
                          style: const TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n?.receivables ?? 'Receivables',
                            style: const TextStyle(
                                color: Color(0xFFE9D8FD), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          Money.formatRupees(metrics.totalReceivablesInr,
                              showDecimals: false),
                          style: const TextStyle(
                            color: Color(0xFFFDE047),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 3. Immediate Action Bar ---
  Widget _buildProminentQuickActions(BuildContext context, bool isDark,
      [AppLocalizations? l10n]) {
    return Row(
      children: [
        // 1. Import Statement (PDF/CSV)
        Expanded(
          child: InkWell(
            onTap: onImportStatement,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF2E2440) : const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF583B8B)
                      : const Color(0xFFD8B4FE),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    color: isDark
                        ? const Color(0xFFD8B4FE)
                        : const Color(0xFF6B21A8),
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n?.importStatement ?? 'Import Statement',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF4C1D95),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PDF / CSV File',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFC4B5FD)
                          : const Color(0xFF6D28D9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 2. Add Income (+ Receive)
        Expanded(
          child: InkWell(
            onTap: onAddPaymentReceived,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF132F23) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF047857)
                      : const Color(0xFFA7F3D0),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    color: isDark
                        ? const Color(0xFF6EE7B7)
                        : const Color(0xFF047857),
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n != null ? '+ ${l10n.moneyIn}' : '+ Add Income',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cash / Credit',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 3. Add Expense (- Pay)
        Expanded(
          child: InkWell(
            onTap: onAddExpense,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF3B1F20) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFB91C1C)
                      : const Color(0xFFFECACA),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_upward_rounded,
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFB91C1C),
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n != null ? '- ${l10n.moneyOut}' : '- Add Expense',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Debit / Spend',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFFECACA)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- 4. Priority Actions & Business Insights ---
  Widget _buildPriorityActionsCard(
    BuildContext context,
    bool isDark,
    AsyncValue<List<CommunicationAction>> actionsAsync,
    AsyncValue<FinancialPositionMetrics> positionAsync,
    AppLocalizations? l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: isDark
                      ? AppColors.darkPrimaryPurple
                      : AppColors.primaryPurple,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n?.priorityActions ?? 'Priority Actions & Insights',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => (onOpenActionCenter ??
                  () => onNavigateToRoute?.call('/actions'))(),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  l10n?.viewAll ?? 'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkPrimaryPurple
                        : AppColors.primaryPurple,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        actionsAsync.when(
          loading: () => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark
                        ? AppColors.darkPrimaryPurple
                        : AppColors.primaryPurple,
                  ),
                ),
              ),
            ),
          ),
          error: (err, _) => const SizedBox.shrink(),
          data: (actions) {
            if (actions.isNotEmpty) {
              final topAction = actions.first;
              return Card(
                elevation: 0,
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF583B8B)
                        : AppColors.lightLavender,
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2E2440)
                                  : const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              topAction.actionType
                                  .toServerString()
                                  .replaceAll('_', ' '),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFD8B4FE)
                                    : AppColors.primaryPurple,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n?.highPriority ?? 'High Priority',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.amber.shade300
                                    : Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n?.reminderDraftTitle ?? 'Payment Reminder Draft',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        topAction.draftContent,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: Text(
                              l10n?.reviewAndSend ?? 'Review & Send Draft'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? AppColors.darkPrimaryPurple
                                : AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            if (topAction.promiseId != null &&
                                topAction.promiseId!.isNotEmpty) {
                              onNavigateToRoute?.call('/actions/draft');
                            } else {
                              (onOpenActionCenter ??
                                  () => onNavigateToRoute
                                      ?.call('/actions'))();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Contextual insight when no drafts exist
            final pos = positionAsync.asData?.value;
            if (pos != null && pos.totalOverdueReceivablesPaise > 0) {
              return Card(
                elevation: 0,
                color: isDark
                    ? const Color(0xFF2D2319)
                    : const Color(0xFFFFFBEB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF78350F)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: isDark
                              ? Colors.amber.shade300
                              : Colors.amber.shade800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Money.formatRupees(pos.totalOverdueReceivablesInr)} ${l10n?.overdue ?? "Overdue"}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.amber.shade200
                                    : Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n?.debtorFollowups ??
                                  'Follow up with overdue debtors',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.amber.shade100
                                    : Colors.brown.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => (onOpenReceivables ??
                            () => onNavigateToRoute?.call('/receivables'))(),
                        child: Text(
                          l10n?.viewDetails ?? 'View',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.amber.shade300
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Clean calm state
            return Card(
              elevation: 0,
              color: isDark ? AppColors.darkCard : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.task_alt_rounded,
                          size: 20, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.noActionsPending ?? 'No Pending Actions',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n?.noActionsPendingDesc ??
                                'All financial actions and reminders are currently up to date.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- 5. Upcoming Obligations & Promises ---
  Widget _buildObligationsCard(
    BuildContext context,
    bool isDark,
    AsyncValue<DashboardObligationsSummary> obligationsAsync,
    AppLocalizations? l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: isDark
                      ? AppColors.darkPrimaryPurple
                      : AppColors.primaryPurple,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n?.upcomingObligations ??
                      'Upcoming Obligations & Promises',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => (onOpenPromises ??
                  () => onNavigateToRoute?.call('/promises'))(),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  l10n?.manage ?? 'Manage',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkPrimaryPurple
                        : AppColors.primaryPurple,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        obligationsAsync.when(
          loading: () => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark
                        ? AppColors.darkPrimaryPurple
                        : AppColors.primaryPurple,
                  ),
                ),
              ),
            ),
          ),
          error: (err, _) => const SizedBox.shrink(),
          data: (data) {
            final hasPromises = data.openPromiseCount > 0;
            final hasPayables = data.pendingPayableCount > 0;

            if (!hasPromises && !hasPayables) {
              return Card(
                elevation: 0,
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkLavenderSurface
                              : AppColors.lightLavender,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.done_all_rounded,
                          size: 20,
                          color: isDark
                              ? AppColors.darkPrimaryPurple
                              : AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n?.allObligationsSettled ??
                              'All obligations settled · No pending promises or payables',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Row(
              children: [
                // 1. Payment Promises (Receivables) Tile
                Expanded(
                  child: InkWell(
                    onTap: () => (onOpenPromises ??
                        () => onNavigateToRoute?.call('/promises'))(),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.call_received_rounded,
                                    size: 16, color: Color(0xFF047857)),
                              ),
                              if (data.overduePromiseCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${data.overduePromiseCount} ${l10n?.overdue ?? "Overdue"}',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n?.paymentPromises ?? 'Payment Promises',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Money.formatRupees(
                                data.openPromiseTotalPaise / 100,
                                showDecimals: false),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${data.openPromiseCount} ${l10n?.openStatus ?? "Open"}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 2. Supplier Payables Tile
                Expanded(
                  child: InkWell(
                    onTap: () => onNavigateToRoute?.call('/procurement'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.call_made_rounded,
                                    size: 16, color: Color(0xFFB91C1C)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2E2440)
                                      : const Color(0xFFF3E8FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n?.pendingAmount ?? 'Payable',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? const Color(0xFFD8B4FE)
                                        : AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n?.supplierObligations ?? 'Supplier Payables',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Money.formatRupees(
                                data.pendingPayableTotalPaise / 100,
                                showDecimals: false),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${data.pendingPayableCount} ${l10n?.pendingObligations ?? "Pending"}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // --- 6. VyaparPulse Market Intelligence Summary ---
  Widget _buildMarketIntelligenceCard(
    BuildContext context,
    bool isDark,
    AsyncValue<DashboardMarketSummary> marketAsync,
    AppLocalizations? l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.travel_explore_rounded,
                  size: 18,
                  color: isDark
                      ? AppColors.darkPrimaryPurple
                      : AppColors.primaryPurple,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n?.marketIntelligenceTitle ??
                      'VyaparPulse Market Intelligence',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => (onOpenMarketSignals ??
                  () => onNavigateToRoute?.call('/market'))(),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  l10n?.search ?? 'Explore',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkPrimaryPurple
                        : AppColors.primaryPurple,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        marketAsync.maybeWhen(
          data: (market) {
            final categoryText = market.category ?? 'Retail & Wholesale';
            final cityText = market.city ?? 'Local Market';

            return Card(
              elevation: 0,
              color: isDark ? AppColors.darkCard : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkLavenderSurface
                                : AppColors.lightLavender,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            AppIcons.market,
                            size: 20,
                            color: isDark
                                ? AppColors.darkPrimaryPurple
                                : AppColors.primaryPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$categoryText · $cityText',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${market.shortlistedCount} ${l10n?.shortlistedSuppliers ?? "Saved Suppliers in Shortlist"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon:
                                const Icon(Icons.location_on_rounded, size: 14),
                            label: Text(
                              l10n?.localSuppliers ?? 'Local Suppliers',
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () =>
                                onNavigateToRoute?.call('/market/suppliers'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.bookmark_rounded, size: 14),
                            label: Text(
                              '${l10n?.supplierShortlist ?? "Shortlist"} (${market.shortlistedCount})',
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () =>
                                onNavigateToRoute?.call('/market/shortlist'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  // --- 7. Financial Services & Tools Grid ---
  Widget _buildQuickActionGrid(BuildContext context, bool isDark,
      [AppLocalizations? l10n]) {
    return Card(
      elevation: 0,
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MerchantActionTile(
                  label: l10n != null
                      ? l10n.insights.replaceAll(' ', '\n')
                      : 'Financial\nIntelligence',
                  icon: AppIcons.analytics,
                  onTap: () => (onOpenFinancialIntelligence ??
                      () => onNavigateToRoute?.call('/intelligence'))(),
                ),
                MerchantActionTile(
                  label: l10n != null
                      ? l10n.receivablesTracker.replaceAll(' ', '\n')
                      : 'Receivables\nTracker',
                  icon: AppIcons.receivables,
                  onTap: () => (onOpenReceivables ??
                      () => onNavigateToRoute?.call('/receivables'))(),
                ),
                MerchantActionTile(
                  label: l10n != null
                      ? l10n.passbookLedger.replaceAll(' ', '\n')
                      : 'Passbook\nLedger',
                  icon: AppIcons.transactions,
                  onTap: () => (onViewReconciledTransactions ??
                      () => onNavigateToRoute?.call('/transactions'))(),
                ),
                MerchantActionTile(
                  label: l10n != null
                      ? l10n.actionCenterTitle.replaceAll(' ', '\n')
                      : 'Action\nCenter',
                  icon: AppIcons.actions,
                  onTap: () => (onOpenActionCenter ??
                      () => onNavigateToRoute?.call('/actions'))(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MerchantActionTile(
                  label: l10n != null
                      ? l10n.procurementTitle.replaceAll(' ', '\n')
                      : 'KharidSaathi\nProcurement',
                  icon: Icons.shopping_cart_checkout_rounded,
                  onTap: () => onNavigateToRoute?.call('/procurement'),
                ),
                MerchantActionTile(
                  label: l10n != null
                      ? l10n.paymentPromises.replaceAll(' ', '\n')
                      : 'Payment\nPromises',
                  icon: AppIcons.promise,
                  onTap: () => (onOpenPromises ??
                      () => onNavigateToRoute?.call('/promises'))(),
                ),
                MerchantActionTile(
                  label: l10n != null
                      ? l10n.financialRelationships.replaceAll(' ', '\n')
                      : 'Financial\nRelationships',
                  icon: AppIcons.counterparties,
                  onTap: () => (onOpenRelationships ??
                      () => onNavigateToRoute?.call('/relationships'))(),
                ),
                MerchantActionTile(
                  label: l10n != null
                      ? l10n.intelligentReportsTitle
                          .replaceAll(' & ', '\n')
                          .replaceAll(' और ', '\n')
                          .replaceAll(' आणि ', '\n')
                      : 'Financial\nReports',
                  icon: Icons.summarize_rounded,
                  color: isDark
                      ? AppColors.darkPrimaryPurple
                      : AppColors.primaryPurple,
                  onTap: () => onNavigateToRoute?.call('/reports'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
