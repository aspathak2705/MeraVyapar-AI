import 'package:flutter/material.dart';
import '../domain/tflite_extraction_engine.dart';
import '../domain/tflite_categorization_engine.dart';

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
  final _rawTextController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _counterpartyController = TextEditingController();
  String _paymentMode = 'UPI';
  String? _detectedCategory;
  bool _isAutoFilled = false;

  final _extractionEngine = TFLiteExtractionEngine();
  final _categorizationEngine = TFLiteCategorizationEngine();

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
  }

  void _parseAndPrefill() {
    final rawText = _rawTextController.text.trim();
    if (rawText.isEmpty) return;

    final extResult = _extractionEngine.extract(rawText);
    final catResult = _categorizationEngine.categorize(
      description: rawText,
      counterpartyName: extResult.counterpartyName,
      direction: _direction,
    );

    setState(() {
      if (extResult.amount != null) {
        _amountController.text = extResult.amount.toString();
      }
      if (extResult.paymentMode != null) {
        _paymentMode = extResult.paymentMode!;
      }
      if (extResult.counterpartyName != null) {
        _counterpartyController.text = extResult.counterpartyName!;
      }
      _descriptionController.text = rawText;
      _detectedCategory = catResult.category;
      _isAutoFilled = true;
    });
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
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 18, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Text(
                              'Paste SMS / Notification Text (Optional Assistant)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _rawTextController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Received Rs 5000 from Rajesh via UPI',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _parseAndPrefill,
                            icon: const Icon(Icons.flash_on, size: 16),
                            label: const Text('Auto-fill Form'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isAutoFilled) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text(
                          'Details detected (${_detectedCategory ?? "UNCATEGORIZED"})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
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
