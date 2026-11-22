import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/local_business_profile_repository.dart';
import '../domain/merchant_business_profile.dart';
import '../../auth/data/local_auth_repository.dart';

class BusinessProfileScreen extends ConsumerStatefulWidget {
  final String merchantId;
  final VoidCallback? onBack;

  const BusinessProfileScreen({
    super.key,
    required this.merchantId,
    this.onBack,
  });

  @override
  ConsumerState<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _productsController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _procurementController;
  late TextEditingController _goalsController;

  String _businessType = 'RETAIL';
  String _customerType = 'B2C';
  String _salesChannels = 'OFFLINE_STORE';
  String _turnoverRange = '10L - 40L';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _categoryController = TextEditingController();
    _productsController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _procurementController = TextEditingController();
    _goalsController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _productsController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _procurementController.dispose();
    _goalsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final repo = ref.read(localBusinessProfileRepositoryProvider);
    final authRepo = ref.read(localAuthRepositoryProvider);
    final fallbackName = authRepo.currentSession?.displayName;
    final profile = await repo.getProfile(merchantId: widget.merchantId, fallbackName: fallbackName);
    if (mounted) {
      setState(() {
        _nameController.text = profile.businessName;
        _categoryController.text = profile.businessCategory;
        _productsController.text = profile.productsAndServices;
        _cityController.text = profile.city;
        _stateController.text = profile.state;
        _procurementController.text = profile.mainProcurementCategories;
        _goalsController.text = profile.businessGoals;
        _businessType = profile.businessType;
        _customerType = profile.customerType;
        _salesChannels = profile.salesChannels;
        _turnoverRange = profile.turnoverRange;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final profile = MerchantBusinessProfile(
      merchantId: widget.merchantId,
      businessName: _nameController.text.trim(),
      businessCategory: _categoryController.text.trim(),
      businessType: _businessType,
      productsAndServices: _productsController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      customerType: _customerType,
      salesChannels: _salesChannels,
      mainProcurementCategories: _procurementController.text.trim(),
      turnoverRange: _turnoverRange,
      businessGoals: _goalsController.text.trim(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    final repo = ref.read(localBusinessProfileRepositoryProvider);
    await repo.saveProfile(profile);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business Profile saved to device ledger')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.setupBusinessTitle ?? 'Merchant Business Profile'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Core Business Identity',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(labelText: l10n?.businessName ?? 'Trade / Business Name'),
                              validator: (v) => v == null || v.trim().isEmpty ? (l10n?.businessCategory ?? 'Required') : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                labelText: l10n?.businessCategory ?? 'Primary Business Category',
                                hintText: 'e.g. Kirana, Hardware, Textiles',
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _businessType,
                              decoration: InputDecoration(labelText: l10n?.businessType ?? 'Business Model'),
                              items: const [
                                DropdownMenuItem(value: 'RETAIL', child: Text('Retailer / Storefront')),
                                DropdownMenuItem(value: 'WHOLESALE', child: Text('Wholesaler / Trader')),
                                DropdownMenuItem(value: 'SERVICES', child: Text('Services Provider')),
                                DropdownMenuItem(value: 'MANUFACTURING', child: Text('Small Manufacturer / Processor')),
                              ],
                              onChanged: (v) => setState(() => _businessType = v ?? 'RETAIL'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location & Operations',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cityController,
                                    decoration: InputDecoration(labelText: l10n?.city ?? 'City / District'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _stateController,
                                    decoration: InputDecoration(labelText: l10n?.state ?? 'State'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _productsController,
                              decoration: InputDecoration(
                                labelText: l10n?.productsAndServices ?? 'Major Products & Items Sold',
                                hintText: 'e.g. Rice, edible oil, spices',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _procurementController,
                              decoration: InputDecoration(
                                labelText: l10n?.mainProcurementCategories ?? 'Main Procurement Commodities',
                                hintText: 'e.g. Grains, Cement, Steel, Fabrics',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Market & Intelligence Personalization',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _customerType,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: l10n?.customerType ?? 'Target Customers'),
                              items: const [
                                DropdownMenuItem(value: 'B2C', child: Text('Consumer Walk-ins (B2C)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'B2B', child: Text('Business Clients / Contractors (B2B)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'HYBRID', child: Text('Both B2B and B2C', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) => setState(() => _customerType = v ?? 'B2C'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _turnoverRange,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: l10n?.turnoverRange ?? 'Annual Turnover Range'),
                              items: const [
                                DropdownMenuItem(value: '< 10L', child: Text('Under ₹10 Lakhs', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: '10L - 40L', child: Text('₹10 Lakhs to ₹40 Lakhs', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: '40L - 1.5Cr', child: Text('₹40 Lakhs to ₹1.5 Crores', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: '> 1.5Cr', child: Text('Above ₹1.5 Crores', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) => setState(() => _turnoverRange = v ?? '10L - 40L'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _goalsController,
                              decoration: InputDecoration(
                                labelText: l10n?.businessGoals ?? 'Key Business Focus / Goal',
                                hintText: 'e.g. Reduce wholesale cost, track customer udhaar',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline),
                        label: Text(l10n?.saveProfile ?? 'Save Business Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isSaving ? null : _handleSave,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
