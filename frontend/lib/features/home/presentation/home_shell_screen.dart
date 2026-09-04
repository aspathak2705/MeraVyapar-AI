import 'package:flutter/material.dart';

class HomeShellScreen extends StatelessWidget {
  final VoidCallback onSignOut;
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

  const HomeShellScreen({
    super.key,
    required this.onSignOut,
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
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MeraVyapar AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI Assistant',
            onPressed: onOpenAssistant,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Attention Events',
            onPressed: onOpenEvents,
          ),
          IconButton(
            icon: const Icon(Icons.monetization_on_outlined),
            tooltip: 'Receivables',
            onPressed: onOpenReceivables,
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Relationships',
            onPressed: onOpenRelationships,
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Capture Center',
            onPressed: onOpenCaptureCenter,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: onSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 36,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Financial Evidence Workspace',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Record payments, expenses, or share payment proofs to build your merchant financial context.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Merchant AI Assistant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                ),
                onPressed: onOpenAssistant,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.notifications_active),
                label: const Text('Things Needing Attention'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF991B1B),
                ),
                onPressed: onOpenEvents,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.monetization_on),
                label: const Text('Prioritized Receivables'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF166534),
                ),
                onPressed: onOpenReceivables,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Evidence Capture Center'),
                onPressed: onOpenCaptureCenter,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Reconciled Transactions'),
                onPressed: onViewReconciledTransactions,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.people_outline),
                label: const Text('Financial Relationships'),
                onPressed: onOpenRelationships,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_available),
                label: const Text('Payment Promises Memory'),
                onPressed: onOpenPromises,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.list_alt),
                label: const Text('View Financial Evidence Activity'),
                onPressed: onViewHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
