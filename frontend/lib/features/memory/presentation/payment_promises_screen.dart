import 'package:flutter/material.dart';
import '../domain/payment_promise_model.dart';
import '../domain/counterparty_model.dart';

class PaymentPromisesScreen extends StatefulWidget {
  final List<PaymentPromiseModel> promises;
  final List<CounterpartyModel> counterparties;
  final Function(Map<String, String> data) onCreatePromise;
  final Function(String promiseId) onFulfillPromise;

  const PaymentPromisesScreen({
    super.key,
    required this.promises,
    required this.counterparties,
    required this.onCreatePromise,
    required this.onFulfillPromise,
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

  String _formatDate(DateTime dt) {
    return dt.toIso8601String().substring(0, 10);
  }

  void _showCreatePromiseModal() {
    final descController = TextEditingController();
    final amtController = TextEditingController();
    String direction = 'EXPECTED_INCOMING';
    String? selectedCounterpartyId;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
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
              Text('Record Explicit Payment Promise', style: Theme.of(modalCtx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Expected invoice payment'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amtController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Promised Amount (₹)', prefixText: '₹ '),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: direction,
                items: const [
                  DropdownMenuItem(value: 'EXPECTED_INCOMING', child: Text('Expected Payment Incoming (Receivable)')),
                  DropdownMenuItem(value: 'EXPECTED_OUTGOING', child: Text('Expected Payment Outgoing (Payable)')),
                ],
                onChanged: (val) => setModalState(() => direction = val!),
                decoration: const InputDecoration(labelText: 'Direction'),
              ),
              const SizedBox(height: 12),
              if (widget.counterparties.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedCounterpartyId,
                  items: widget.counterparties
                      .map((cp) => DropdownMenuItem(value: cp.id, child: Text(cp.displayName)))
                      .toList(),
                  onChanged: (val) => setModalState(() => selectedCounterpartyId = val),
                  decoration: const InputDecoration(labelText: 'Link Counterparty (Optional)'),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (descController.text.isEmpty || amtController.text.isEmpty) return;
                  widget.onCreatePromise({
                    if (selectedCounterpartyId != null) 'counterparty_id': selectedCounterpartyId!,
                    'description': descController.text,
                    'promised_amount': amtController.text,
                    'promise_direction': direction,
                    'due_at': selectedDate.toIso8601String(),
                  });
                  Navigator.of(modalCtx).pop();
                },
                child: const Text('Save Payment Promise'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openPromises = widget.promises.where((p) => p.status == 'OPEN').toList();
    final fulfilledPromises = widget.promises.where((p) => p.status == 'FULFILLED').toList();
    final overduePromises = widget.promises.where((p) => p.status == 'OVERDUE').toList();
    final cancelledPromises = widget.promises.where((p) => p.status == 'CANCELLED').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Promises Memory'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'Fulfilled'),
            Tab(text: 'Overdue'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePromiseModal,
        icon: const Icon(Icons.add),
        label: const Text('Record Promise'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPromiseList(openPromises, allowFulfill: true),
          _buildPromiseList(fulfilledPromises),
          _buildPromiseList(overduePromises),
          _buildPromiseList(cancelledPromises),
        ],
      ),
    );
  }

  Widget _buildPromiseList(List<PaymentPromiseModel> list, {bool allowFulfill = false}) {
    if (list.isEmpty) {
      return const Center(child: Text('No payment promises in this section.', style: TextStyle(color: Color(0xFF64748B))));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = list[index];
        final isIncoming = p.promiseDirection == 'EXPECTED_INCOMING';

        return Card(
          child: ListTile(
            leading: Icon(
              isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncoming ? const Color(0xFF166534) : const Color(0xFF991B1B),
            ),
            title: Text(p.description, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Due: ${_formatDate(p.dueAt)} • Source: ${p.source}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${p.promisedAmount}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isIncoming ? const Color(0xFF166534) : const Color(0xFF991B1B),
                  ),
                ),
                if (allowFulfill)
                  InkWell(
                    onTap: () => widget.onFulfillPromise(p.id),
                    child: const Text('Fulfill', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
