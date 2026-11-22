import 'package:flutter/material.dart';
import '../../../../core/money/money.dart';
import '../../../../core/localization/app_date_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../domain/payment_promise_model.dart';
import '../domain/counterparty_model.dart';

class PaymentPromisesScreen extends StatefulWidget {
  final List<PaymentPromiseModel> promises;
  final List<CounterpartyModel> counterparties;
  final Function(Map<String, String> data) onCreatePromise;
  final Function(String promiseId) onFulfillPromise;
  final VoidCallback? onBack;

  const PaymentPromisesScreen({
    super.key,
    required this.promises,
    required this.counterparties,
    required this.onCreatePromise,
    required this.onFulfillPromise,
    this.onBack,
  });

  @override
  State<PaymentPromisesScreen> createState() => _PaymentPromisesScreenState();
}

class _PaymentPromisesScreenState extends State<PaymentPromisesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePromiseModal() {
    final l10n = AppLocalizations.of(context);
    final descController = TextEditingController();
    final amtController = TextEditingController();
    String direction = 'EXPECTED_INCOMING';
    String? selectedCounterpartyId;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
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
                    l10n?.recordPaymentPromise ?? 'Record Explicit Payment Promise',
                    style: Theme.of(modalCtx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: l10n?.description ?? 'Description',
                      hintText: 'e.g. Expected invoice payment',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amtController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n?.promisedAmount ?? 'Promised Amount (₹)',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: direction,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: 'EXPECTED_INCOMING',
                        child: Text(
                          l10n?.expectedIncoming ?? 'Expected Payment Incoming (Receivable)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'EXPECTED_OUTGOING',
                        child: Text(
                          l10n?.expectedOutgoing ?? 'Expected Payment Outgoing (Payable)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => direction = val!),
                    decoration: InputDecoration(labelText: l10n?.direction ?? 'Direction'),
                  ),
                  const SizedBox(height: 12),
                  if (widget.counterparties.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedCounterpartyId,
                      isExpanded: true,
                      items: widget.counterparties
                          .map((cp) => DropdownMenuItem(
                                value: cp.id,
                                child: Text(cp.displayName, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedCounterpartyId = val),
                      decoration: InputDecoration(labelText: l10n?.linkCounterparty ?? 'Link Counterparty (Optional)'),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (descController.text.isEmpty || amtController.text.isEmpty) return;
                      String cpName = l10n?.counterparty ?? 'Declared Counterparty';
                      if (selectedCounterpartyId != null) {
                        final matched = widget.counterparties.where((c) => c.id == selectedCounterpartyId);
                        if (matched.isNotEmpty) {
                          cpName = matched.first.displayName;
                        }
                      }
                      widget.onCreatePromise({
                        if (selectedCounterpartyId != null) 'counterparty_id': selectedCounterpartyId!,
                        'counterparty_name': cpName,
                        'description': descController.text,
                        'notes': descController.text,
                        'promised_amount': amtController.text,
                        'amount': amtController.text,
                        'promise_direction': direction,
                        'direction': direction,
                        'due_at': selectedDate.toIso8601String(),
                        'due_date': selectedDate.toIso8601String(),
                      });
                      Navigator.of(modalCtx).pop();
                    },
                    child: Text(l10n?.savePromise ?? 'Save Payment Promise'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final openPromises = widget.promises.where((p) => p.status == 'OPEN').toList();
    final fulfilledPromises = widget.promises.where((p) => p.status == 'FULFILLED').toList();
    final overduePromises = widget.promises.where((p) => p.status == 'OVERDUE').toList();
    final cancelledPromises = widget.promises.where((p) => p.status == 'CANCELLED').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.paymentPromisesTitle ?? 'Payment Promises Memory'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: widget.onBack,
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n?.openStatus ?? 'Open'),
            Tab(text: l10n?.fulfilledStatus ?? 'Fulfilled'),
            Tab(text: l10n?.overdueStatus ?? 'Overdue'),
            Tab(text: l10n?.cancelledStatus ?? 'Cancelled'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePromiseModal,
        icon: const Icon(Icons.add),
        label: Text(l10n?.recordPromise ?? 'Record Promise'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPromiseList(openPromises, l10n, allowFulfill: true),
          _buildPromiseList(fulfilledPromises, l10n),
          _buildPromiseList(overduePromises, l10n),
          _buildPromiseList(cancelledPromises, l10n),
        ],
      ),
    );
  }

  Widget _buildPromiseList(List<PaymentPromiseModel> list, AppLocalizations? l10n, {bool allowFulfill = false}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          l10n?.noPromisesInSection ?? 'No payment promises in this section.',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = list[index];
        final isIncoming = p.promiseDirection == 'EXPECTED_INCOMING';
        final formattedAmt = Money.formatInr(Money.parseInrToPaise(p.promisedAmount));
        final formattedDate = AppDateFormatter.formatDateWithContext(context, p.dueAt);

        return Card(
          child: ListTile(
            leading: Icon(
              isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncoming ? const Color(0xFF166534) : const Color(0xFF991B1B),
            ),
            title: Text(p.description, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${l10n?.due ?? 'Due'}: $formattedDate • ${l10n?.source ?? 'Source'}: ${p.source}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formattedAmt,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isIncoming ? const Color(0xFF166534) : const Color(0xFF991B1B),
                  ),
                ),
                if (allowFulfill)
                  InkWell(
                    onTap: () => widget.onFulfillPromise(p.id),
                    child: Text(
                      l10n?.fulfill ?? 'Fulfill',
                      style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
