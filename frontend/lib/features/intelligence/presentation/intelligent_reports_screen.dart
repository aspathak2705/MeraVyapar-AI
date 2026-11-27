import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/money/money.dart';
import '../../../core/localization/app_date_formatter.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/local_report_repository.dart';
import '../domain/generated_report_model.dart';
import '../domain/local_report_generator_service.dart';

class IntelligentReportsScreen extends ConsumerStatefulWidget {
  final String merchantId;
  final VoidCallback? onBack;

  const IntelligentReportsScreen({
    super.key,
    required this.merchantId,
    this.onBack,
  });

  @override
  ConsumerState<IntelligentReportsScreen> createState() => _IntelligentReportsScreenState();
}

class _IntelligentReportsScreenState extends ConsumerState<IntelligentReportsScreen> {
  List<GeneratedReportModel> _reports = [];
  bool _isLoading = true;
  String? _selectedLanguageFilter; // null = all, 'en', 'hi', 'mr'

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final repo = ref.read(localReportRepositoryProvider);
    final list = await repo.getReports(
      merchantId: widget.merchantId,
      language: _selectedLanguageFilter,
    );
    if (mounted) {
      setState(() {
        _reports = list;
        _isLoading = false;
      });
    }
  }

  void _showGenerateModal() {
    final l10n = AppLocalizations.of(context);
    final currentAppLanguage = ref.read(localeProvider).languageCode;
    String selectedReportLang = currentAppLanguage;
    String selectedType = 'DAILY_FINANCIAL_DIGEST';
    bool isGenerating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: 24,
              left: 24,
              right: 24,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n?.generateReport ?? 'Generate Financial Report',
                  style: Theme.of(modalCtx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: l10n?.reportType ?? 'Report Type',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'DAILY_FINANCIAL_DIGEST',
                      child: Text(l10n?.dailyFinancialDigest ?? 'Daily Financial Digest'),
                    ),
                    DropdownMenuItem(
                      value: 'CASH_FLOW_HEALTH',
                      child: Text(l10n?.cashFlowHealthReport ?? 'Cash Flow Health Report'),
                    ),
                    DropdownMenuItem(
                      value: 'CREDIT_RECOVERY',
                      child: Text(l10n?.creditRecoveryReport ?? 'Credit Recovery & Receivables'),
                    ),
                  ],
                  onChanged: isGenerating ? null : (v) => setModalState(() => selectedType = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedReportLang,
                  decoration: InputDecoration(
                    labelText: l10n?.reportLanguage ?? 'Report Language (Independent)',
                    helperText: 'Select report language without changing app interface language',
                    border: const OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English (EN)')),
                    DropdownMenuItem(value: 'hi', child: Text('हिंदी - Hindi (HI)')),
                    DropdownMenuItem(value: 'mr', child: Text('मराठी - Marathi (MR)')),
                  ],
                  onChanged: isGenerating ? null : (v) => setModalState(() => selectedReportLang = v!),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: isGenerating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: Text(isGenerating
                      ? 'Generating Financial Report...'
                      : (l10n?.generateReport ?? 'Generate Report')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isGenerating
                      ? null
                      : () async {
                          setModalState(() => isGenerating = true);
                          try {
                            final generator = ref.read(localReportGeneratorServiceProvider);
                            await generator.generateReport(
                              merchantId: widget.merchantId,
                              reportType: selectedType,
                              reportLanguage: selectedReportLang,
                            );
                            if (mounted && modalCtx.mounted) {
                              Navigator.of(modalCtx).pop();
                              await _loadReports();
                            }
                          } catch (e) {
                            if (mounted) {
                              setModalState(() => isGenerating = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to generate report: $e')),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReportDetails(GeneratedReportModel report) {
    final l10n = AppLocalizations.of(context);
    final metrics = report.payload['metrics'] as Map<String, dynamic>? ?? {};
    final keyFacts = report.payload['key_facts'] as List? ?? [];
    final actions = report.payload['suggested_actions'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      report.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      report.language.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                AppDateFormatter.formatDateWithContext(context, report.createdAt, includeTime: true),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                report.summary,
                style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 20),
              if (metrics.isNotEmpty) ...[
                Text(
                  l10n?.cashFlowSummary ?? 'Financial Snapshot',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (metrics['total_inflows_paise'] != null)
                          _buildMetricRow(
                            l10n?.totalMoneyIn ?? 'Total Inflows',
                            Money.formatInr((metrics['total_inflows_paise'] as num).toInt()),
                            Colors.green.shade800,
                          ),
                        if (metrics['total_outflows_paise'] != null)
                          _buildMetricRow(
                            l10n?.totalMoneyOut ?? 'Total Outflows',
                            Money.formatInr((metrics['total_outflows_paise'] as num).toInt()),
                            Colors.red.shade800,
                          ),
                        if (metrics['net_cash_movement_paise'] != null)
                          _buildMetricRow(
                            l10n?.netCashMovement ?? 'Net Cash Movement',
                            Money.formatInr((metrics['net_cash_movement_paise'] as num).toInt()),
                            (metrics['net_cash_movement_paise'] as num) >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        if (metrics['total_receivables_paise'] != null)
                          _buildMetricRow(
                            l10n?.receivables ?? 'Total Receivables',
                            Money.formatInr((metrics['total_receivables_paise'] as num).toInt()),
                            Colors.amber.shade900,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (keyFacts.isNotEmpty) ...[
                Text(
                  l10n?.keyObservations ?? 'Key Facts',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...keyFacts.map((kf) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(kf['label']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Text(kf['value']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )),
                const SizedBox(height: 16),
              ],
              if (actions.isNotEmpty) ...[
                Text(
                  l10n?.suggestedActions ?? 'Suggested Actions',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...actions.map((act) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.primaryPurple),
                          const SizedBox(width: 8),
                          Expanded(child: Text(act.toString(), style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(l10n?.deleteReport ?? 'Delete Report', style: const TextStyle(color: Colors.red)),
                onPressed: () async {
                  final repo = ref.read(localReportRepositoryProvider);
                  await repo.deleteReport(report.id);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    await _loadReports();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.intelligentReportsTitle ?? 'Financial Reports & History'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n?.runReconciliationPass ?? 'Refresh',
            onPressed: _loadReports,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateModal,
        icon: const Icon(Icons.auto_awesome),
        label: Text(l10n?.generateReport ?? 'Generate Report'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter by language
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Languages'),
                    selected: _selectedLanguageFilter == null,
                    onSelected: (val) {
                      setState(() => _selectedLanguageFilter = null);
                      _loadReports();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('English (EN)'),
                    selected: _selectedLanguageFilter == 'en',
                    onSelected: (val) {
                      setState(() => _selectedLanguageFilter = val ? 'en' : null);
                      _loadReports();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('हिंदी (HI)'),
                    selected: _selectedLanguageFilter == 'hi',
                    onSelected: (val) {
                      setState(() => _selectedLanguageFilter = val ? 'hi' : null);
                      _loadReports();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('मराठी (MR)'),
                    selected: _selectedLanguageFilter == 'mr',
                    onSelected: (val) {
                      setState(() => _selectedLanguageFilter = val ? 'mr' : null);
                      _loadReports();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _reports.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.summarize_outlined, size: 64, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 16),
                                Text(
                                  l10n?.noReportsYet ?? 'No Reports Generated Yet',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n?.noReportsDesc ?? 'Generate localized intelligence reports from your private device records.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reports.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final report = _reports[index];
                            final formattedDate = AppDateFormatter.formatDateWithContext(
                              context,
                              report.createdAt,
                              includeTime: true,
                            );

                            return Card(
                              child: ListTile(
                                onTap: () => _showReportDetails(report),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPurple.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.description_outlined, color: AppColors.primaryPurple),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        report.language.toUpperCase(),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      report.summary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
