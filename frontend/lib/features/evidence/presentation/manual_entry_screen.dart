import 'package:flutter/material.dart';

class ManualEntryScreen extends StatefulWidget {
  final String initialDirection; // 'MONEY_IN' or 'MONEY_OUT'
  final Function(Map<String, String> data) onSubmit;
  final bool isLoading;

  const ManualEntryScreen({
    super.key,
    this.initialDirection = 'MONEY_OUT',
    required this.onSubmit,
    this.isLoading = false,
  });

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _direction;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _counterpartyController = TextEditingController();
  String _paymentMode = 'UPI';

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _counterpartyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit({
        'transaction_type': _direction,
        'amount': _amountController.text.trim(),
        'description': _descriptionController.text.trim(),
        'counterparty_name': _counterpartyController.text.trim(),
        'payment_mode': _paymentMode,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMoneyIn = _direction == 'MONEY_IN';
    return Scaffold(
      appBar: AppBar(
        title: Text(isMoneyIn ? 'Add Payment Received' : 'Add Expense / Payment Sent'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Money In (+)')),
                        selected: isMoneyIn,
                        selectedColor: const Color(0xFFDCFCE7),
                        onSelected: (selected) {
                          if (selected) setState(() => _direction = 'MONEY_IN');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Money Out (-)')),
                        selected: !isMoneyIn,
                        selectedColor: const Color(0xFFFEE2E2),
                        onSelected: (selected) {
                          if (selected) setState(() => _direction = 'MONEY_OUT');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹) *',
                    hintText: 'e.g. 5000.00',
                    prefixText: '₹ ',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Amount is required';
                    if (double.tryParse(val.trim()) == null) return 'Enter valid numeric amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description / Narration',
                    hintText: 'e.g. Payment for grocery stock',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _counterpartyController,
                  decoration: InputDecoration(
                    labelText: isMoneyIn ? 'Received From (Customer/Party)' : 'Paid To (Supplier/Vendor)',
                    hintText: 'e.g. Kirana Store / Supplier Name',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMode,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/IMPS)')),
                    DropdownMenuItem(value: 'CARD', child: Text('Card')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentMode = val);
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: widget.isLoading ? null : _submit,
                  child: widget.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Record Financial Evidence'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
