import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  final Function(Map<String, String> profileData) onSubmit;
  final bool isLoading;

  const OnboardingScreen({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit({
        'business_name': _nameController.text.trim(),
        'business_type': _typeController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.setupBusinessTitle ?? 'Setup Business Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n?.businessName ?? 'Merchant Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Provide your basic business setup information to enter your workspace.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '${l10n?.businessName ?? 'Business Name'} *',
                    hintText: 'e.g. Ramesh Kirana Store',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? (l10n?.businessName ?? 'Required') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _typeController,
                  decoration: InputDecoration(
                    labelText: l10n?.businessType ?? 'Business Type',
                    hintText: 'e.g. Grocery / Retail / Wholesale',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n?.phoneNumber ?? 'Phone Number',
                    hintText: 'e.g. +91 9876543210',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: InputDecoration(
                          labelText: l10n?.city ?? 'City',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: InputDecoration(
                          labelText: l10n?.state ?? 'State',
                        ),
                      ),
                    ),
                  ],
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
                      : Text(l10n?.verifyAndProceed ?? 'Complete Profile & Proceed'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
