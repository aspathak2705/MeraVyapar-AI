import 'package:flutter/material.dart';
import '../domain/evidence_model.dart';
import '../domain/transaction_candidate_model.dart';

class EvidenceHistoryScreen extends StatelessWidget {
  final List<EvidenceModel> evidenceList;
  final List<TransactionCandidateModel> candidateList;
  final bool isLoading;

  const EvidenceHistoryScreen({
    super.key,
    required this.evidenceList,
    required this.candidateList,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Evidence Activity'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : evidenceList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.history_toggle_off, size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 16),
                        Text(
                          'No financial activity recorded yet.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add your first financial activity or share payment evidence to begin building your business financial context.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: evidenceList.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = evidenceList[index];
                    final isManual = item.evidenceType == 'MANUAL_ENTRY';
                    final isMoneyIn = item.metadataInfo['transaction_type'] == 'MONEY_IN';
                    final amount = item.metadataInfo['amount'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isMoneyIn ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        child: Icon(
                          isMoneyIn ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isMoneyIn ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        ),
                      ),
                      title: Text(
                        item.rawText ?? (isManual ? 'Manual Entry' : item.evidenceType),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Source: ${item.evidenceSource} • Strength: ${item.evidenceStrength}\nStatus: ${item.processingStatus}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      trailing: amount != null
                          ? Text(
                              '${isMoneyIn ? "+" : "-"} ₹$amount',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isMoneyIn ? const Color(0xFF166534) : const Color(0xFF991B1B),
                              ),
                            )
                          : null,
                    );
                  },
                ),
    );
  }
}
