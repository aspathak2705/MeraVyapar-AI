import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/presentation/fintech_widgets.dart';
import '../../../core/localization/language_selector_button.dart';
import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../intelligence/domain/local_financial_intelligence_engine.dart';
import '../../intelligence/presentation/unified_financial_intelligence_screen.dart';

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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSecondaryBackground : AppColors.lightSecondaryBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkLavenderSurface : AppColors.lightLavender,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                AppIcons.business,
                color: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
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
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  l10n?.privateDeviceLedger ?? 'Private Device Ledger',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
            tooltip: 'Business Profile',
            onPressed: () => onNavigateToRoute?.call('/settings/profile'),
          ),
          // Permissions / Privacy Settings Button
          IconButton(
            icon: const Icon(Icons.security_rounded, size: 20),
            tooltip: 'Device Permissions & Privacy',
            onPressed: () => onNavigateToRoute?.call('/settings/permissions'),
          ),
          IconButton(
            icon: const Icon(AppIcons.lock, size: 20),
            tooltip: 'Lock Workspace',
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
              // 1. Primary Financial Overview Card (PhonePe-inspired Purple Hero Surface)
              _buildFinancialHeroCard(context, isDark, positionAsync, l10n),

              const SizedBox(height: 16),

              // Prominent Direct Quick Actions (Statement Import & Direct Manual Entry)
              _buildProminentQuickActions(context, isDark, l10n),

              const SizedBox(height: 24),

              // 2. Quick Action Grid
              Text(
                l10n?.financialServices ?? 'Financial Services',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _buildQuickActionGrid(context, isDark, l10n),

              const SizedBox(height: 24),

              // 3. Merchant Intelligence & Actions
              Text(
                l10n?.intelligenceAndInsights ?? 'Intelligence & Insights',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildIntelligenceHighlightCard(context, isDark),

              const SizedBox(height: 20),
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
              (onOpenFinancialIntelligence ?? () => onNavigateToRoute?.call('/intelligence'))();
              break;
            case 2:
              (onViewReconciledTransactions ?? () => onNavigateToRoute?.call('/transactions'))();
              break;
            case 3:
              (onOpenReceivables ?? () => onNavigateToRoute?.call('/receivables'))();
              break;
            case 4:
              (onOpenActionCenter ?? () => onNavigateToRoute?.call('/actions'))();
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
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text(
              '₹0',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Ready to record transactions ($err)', style: const TextStyle(color: Colors.white60, fontSize: 12)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${metrics.transactionCount} txs',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                Money.formatRupees(metrics.netCashMovementInr, showDecimals: false),
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
                        Text(l10n?.totalMoneyIn ?? 'Inflows', style: const TextStyle(color: Color(0xFFE9D8FD), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          Money.formatRupees(metrics.totalInflowsInr, showDecimals: false),
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n?.totalMoneyOut ?? 'Outflows', style: const TextStyle(color: Color(0xFFE9D8FD), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          Money.formatRupees(metrics.totalOutflowsInr, showDecimals: false),
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n?.receivables ?? 'Receivables', style: const TextStyle(color: Color(0xFFE9D8FD), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          Money.formatRupees(metrics.totalReceivablesInr, showDecimals: false),
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

  Widget _buildQuickActionGrid(BuildContext context, bool isDark, [AppLocalizations? l10n]) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MerchantActionTile(
                  label: 'Financial\nIntelligence',
                  icon: AppIcons.analytics,
                  onTap: () => (onOpenFinancialIntelligence ?? () => onNavigateToRoute?.call('/intelligence'))(),
                ),
                MerchantActionTile(
                  label: 'Receivables\nTracker',
                  icon: AppIcons.receivables,
                  onTap: () => (onOpenReceivables ?? () => onNavigateToRoute?.call('/receivables'))(),
                ),
                MerchantActionTile(
                  label: 'Passbook\nLedger',
                  icon: AppIcons.transactions,
                  onTap: () => (onViewReconciledTransactions ?? () => onNavigateToRoute?.call('/transactions'))(),
                ),
                MerchantActionTile(
                  label: 'Action\nCenter',
                  icon: AppIcons.actions,
                  onTap: () => (onOpenActionCenter ?? () => onNavigateToRoute?.call('/actions'))(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MerchantActionTile(
                  label: 'KharidSaathi\nProcurement',
                  icon: Icons.shopping_cart_checkout_rounded,
                  onTap: () => onNavigateToRoute?.call('/procurement'),
                ),
                MerchantActionTile(
                  label: 'Payment\nPromises',
                  icon: AppIcons.promise,
                  onTap: () => (onOpenPromises ?? () => onNavigateToRoute?.call('/promises'))(),
                ),
                MerchantActionTile(
                  label: 'Financial\nRelationships',
                  icon: AppIcons.counterparties,
                  onTap: () => (onOpenRelationships ?? () => onNavigateToRoute?.call('/relationships'))(),
                ),
                MerchantActionTile(
                  label: 'Market\nSignals',
                  icon: AppIcons.market,
                  onTap: () => (onOpenMarketSignals ?? () => onNavigateToRoute?.call('/market'))(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MerchantActionTile(
                  label: l10n != null ? l10n.localSuppliers.replaceAll(' ', '\n') : 'Local\nSuppliers',
                  icon: Icons.location_on_rounded,
                  color: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
                  onTap: () => onNavigateToRoute?.call('/market/suppliers'),
                ),
                MerchantActionTile(
                  label: l10n != null ? l10n.supplierShortlist.replaceAll(' ', '\n') : 'Supplier\nShortlist',
                  icon: Icons.bookmark_rounded,
                  color: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
                  onTap: () => onNavigateToRoute?.call('/market/shortlist'),
                ),
                const SizedBox(width: 68),
                const SizedBox(width: 68),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntelligenceHighlightCard(BuildContext context, bool isDark) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkLavenderSurface : AppColors.lightLavender,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            AppIcons.assistant,
            color: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
            size: 24,
          ),
        ),
        title: const Text(
          'Grounded Financial Autopilot',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text(
            'Understand cash trends, overdue counterparty promises, and forecast 14-day cash movements on device.',
            style: TextStyle(fontSize: 12, height: 1.3),
          ),
        ),
        trailing: const Icon(AppIcons.chevronRight),
        onTap: () => (onOpenFinancialIntelligence ?? () => onNavigateToRoute?.call('/intelligence'))(),
      ),
    );
  }

  Widget _buildProminentQuickActions(BuildContext context, bool isDark, [AppLocalizations? l10n]) {
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
                color: isDark ? const Color(0xFF2E2440) : const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF583B8B) : const Color(0xFFD8B4FE),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF6B21A8),
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
                      color: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
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
                color: isDark ? const Color(0xFF132F23) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
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
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF059669),
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
                color: isDark ? const Color(0xFF3B1F20) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFFB91C1C) : const Color(0xFFFECACA),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_upward_rounded,
                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
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
                      color: isDark ? const Color(0xFFFECACA) : const Color(0xFFDC2626),
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
}
