import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/presentation/fintech_widgets.dart';
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
    this.onNavigateToRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final positionAsync = ref.watch(financialPositionMetricsProvider);
    final themeMode = ref.watch(themeModeProvider);

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
                  'MeraVyapar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  'Private Device Ledger',
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
          // Permissions / Privacy Settings Button
          IconButton(
            icon: const Icon(Icons.security_rounded, size: 20),
            tooltip: 'Device Permissions & Privacy',
            onPressed: () => onNavigateToRoute?.call('/settings/permissions'),
          ),
          // Theme Toggle Button
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 20,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                  );
            },
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
              _buildFinancialHeroCard(context, isDark, positionAsync),

              const SizedBox(height: 24),

              // 2. Quick Action Grid
              Text(
                'Financial Services',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _buildQuickActionGrid(context, isDark),

              const SizedBox(height: 24),

              // 3. Merchant Intelligence & Actions
              Text(
                'Intelligence & Insights',
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(AppIcons.homeOutlined),
            activeIcon: Icon(AppIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.analyticsOutlined),
            activeIcon: Icon(AppIcons.analytics),
            label: 'Intelligence',
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.transactionsOutlined),
            activeIcon: Icon(AppIcons.transactions),
            label: 'Passbook',
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.receivables),
            activeIcon: Icon(AppIcons.receivables),
            label: 'Receivables',
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.actionsOutlined),
            activeIcon: Icon(AppIcons.actions),
            label: 'Actions',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
        foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
        tooltip: 'Gnani Voice Autopilot',
        onPressed: onOpenVoiceAssistant,
        child: const Icon(AppIcons.voice, size: 28),
      ),
    );
  }

  Widget _buildFinancialHeroCard(
    BuildContext context,
    bool isDark,
    AsyncValue<FinancialPositionMetrics> positionAsync,
  ) {
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
                  color: AppColors.primaryPurple.withOpacity(0.2),
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
            const Text(
              'Net Cash Movement',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text(
              '₹0.00',
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
                  const Text(
                    'Net Cash Movement',
                    style: TextStyle(
                      color: Color(0xFFE9D8FD),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
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
                '₹${metrics.netCashMovementInr.toStringAsFixed(2)}',
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
                color: Colors.white.withOpacity(0.15),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Inflows', style: TextStyle(color: Color(0xFFE9D8FD), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${metrics.totalInflowsInr.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Outflows', style: TextStyle(color: Color(0xFFE9D8FD), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${metrics.totalOutflowsInr.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Receivables', style: TextStyle(color: Color(0xFFE9D8FD), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${metrics.totalReceivablesInr.toStringAsFixed(2)}',
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

  Widget _buildQuickActionGrid(BuildContext context, bool isDark) {
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
                MerchantActionTile(
                  label: 'AI Voice\nAutopilot',
                  icon: AppIcons.voice,
                  color: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
                  onTap: () => onOpenVoiceAssistant?.call(),
                ),
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
}
