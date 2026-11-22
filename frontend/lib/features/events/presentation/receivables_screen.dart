import 'package:flutter/material.dart';
import '../../../../core/money/money.dart';
import '../../../../core/localization/app_date_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../domain/receivable_model.dart';

class ReceivablesScreen extends StatelessWidget {
  final List<ReceivableModel> receivables;
  final Function(ReceivableModel item) onReceivableTap;
  final VoidCallback? onBack;

  const ReceivablesScreen({
    super.key,
    required this.receivables,
    required this.onReceivableTap,
    this.onBack,
  });

  String _formatDate(BuildContext context, DateTime dt) {
    return AppDateFormatter.formatDateWithContext(context, dt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final highPriority = receivables.where((r) => r.priority == 'HIGH').toList();
    final mediumPriority = receivables.where((r) => r.priority == 'MEDIUM').toList();
    final lowPriority = receivables.where((r) => r.priority == 'LOW').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.receivablesTracker ?? 'Prioritized Receivables'),
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: receivables.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.monetization_on_outlined, size: 64, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 16),
                      Text(
                        l10n?.noReceivablesPending ?? 'No Outstanding Receivables',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n?.noReceivablesDesc ?? 'Receivables originate strictly from explicit incoming payment promises. None are currently pending.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (highPriority.isNotEmpty) ...[
                      _buildSectionHeader(l10n?.highPriority ?? 'HIGH PRIORITY', const Color(0xFF991B1B)),
                      ...highPriority.map((r) => _buildReceivableCard(context, r, l10n)),
                      const SizedBox(height: 16),
                    ],
                    if (mediumPriority.isNotEmpty) ...[
                      _buildSectionHeader(l10n?.mediumPriority ?? 'MEDIUM PRIORITY', const Color(0xFFD97706)),
                      ...mediumPriority.map((r) => _buildReceivableCard(context, r, l10n)),
                      const SizedBox(height: 16),
                    ],
                    if (lowPriority.isNotEmpty) ...[
                      _buildSectionHeader(l10n?.lowPriority ?? 'LOW PRIORITY', const Color(0xFF1E40AF)),
                      ...lowPriority.map((r) => _buildReceivableCard(context, r, l10n)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildReceivableCard(BuildContext context, ReceivableModel r, AppLocalizations? l10n) {
    final cpName = r.counterpartyName ?? (l10n?.counterparty ?? 'Counterparty');
    final isOverdue = r.state == 'OVERDUE';
    final formattedAmt = Money.formatInr(Money.parseInrToPaise(r.amount));

    return Card(
      child: ListTile(
        onTap: () => onReceivableTap(r),
        leading: Icon(
          Icons.arrow_downward,
          color: isOverdue ? const Color(0xFF991B1B) : const Color(0xFF166534),
        ),
        title: Text(cpName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${l10n?.due ?? 'Due'}: ${_formatDate(context, r.dueAt)} • ${l10n?.state ?? 'State'}: ${r.state}'),
        trailing: Text(
          formattedAmt,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isOverdue ? const Color(0xFF991B1B) : const Color(0xFF166534),
          ),
        ),
      ),
    );
  }
}
