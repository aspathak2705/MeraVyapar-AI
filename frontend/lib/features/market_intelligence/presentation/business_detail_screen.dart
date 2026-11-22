import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/market_event_model.dart';
import '../domain/shortlisted_supplier_model.dart';
import '../data/local_supplier_shortlist_repository.dart';

class BusinessDetailScreen extends ConsumerStatefulWidget {
  final MarketEventModel business;
  final String merchantId;

  const BusinessDetailScreen({
    super.key,
    required this.business,
    required this.merchantId,
  });

  @override
  ConsumerState<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends ConsumerState<BusinessDetailScreen> {
  bool _isShortlisted = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkShortlistStatus();
  }

  Future<void> _checkShortlistStatus() async {
    final repo = ref.read(localSupplierShortlistRepositoryProvider);
    final exists = await repo.isShortlisted(
      merchantId: widget.merchantId,
      businessName: widget.business.title,
      sourceUrl: widget.business.source?.sourceUrl,
    );
    if (mounted) {
      setState(() {
        _isShortlisted = exists;
        _isChecking = false;
      });
    }
  }

  Future<void> _toggleShortlist() async {
    final repo = ref.read(localSupplierShortlistRepositoryProvider);
    if (_isShortlisted) {
      // Find and remove
      final list = await repo.getShortlist(merchantId: widget.merchantId);
      final item = list.firstWhere(
        (s) => s.businessName == widget.business.title || (widget.business.source?.sourceUrl != null && s.sourceUrl == widget.business.source?.sourceUrl),
        orElse: () => list.first,
      );
      await repo.removeFromShortlist(item.id);
      if (mounted) {
        setState(() => _isShortlisted = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed supplier from shortlist.')),
        );
      }
    } else {
      final supplier = ShortlistedSupplierModel.fromMarketEvent(
        widget.merchantId,
        widget.business,
      );
      await repo.addToShortlist(supplier);
      if (mounted) {
        setState(() => _isShortlisted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved supplier to shortlist.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = widget.business;

    return Scaffold(
      appBar: AppBar(
        title: Text(b.title.isNotEmpty ? b.title : 'Supplier Details'),
        actions: [
          IconButton(
            icon: Icon(
              _isShortlisted ? Icons.bookmark : Icons.bookmark_border,
              color: _isShortlisted ? AppColors.primaryPurple : null,
            ),
            tooltip: _isShortlisted ? 'In Shortlist' : 'Save to Shortlist',
            onPressed: _isChecking ? null : _toggleShortlist,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.amber.shade800, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unverified Online Supplier Discovery',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Discovered via Google Maps search. This listing does not constitute a verified wholesale quote, formal quotation, or endorsed merchant partnership.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Business Header Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    if (b.category != null || b.sector != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          b.category ?? b.sector ?? 'Wholesale & Supplier',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (b.rating != null) ...[
                          const Icon(Icons.star, size: 18, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            b.rating!.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (b.reviews != null)
                          Text(
                            '(${b.reviews} reviews)',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contact & Location Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact & Location',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    if (b.location != null)
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        title: 'Address',
                        value: b.location!,
                      ),
                    if (b.latitude != null && b.longitude != null)
                      _buildInfoRow(
                        icon: Icons.my_location,
                        title: 'Coordinates',
                        value: '${b.latitude!.toStringAsFixed(4)}, ${b.longitude!.toStringAsFixed(4)}',
                      ),
                    if (b.phone != null && b.phone!.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.phone_outlined,
                        title: 'Phone',
                        value: b.phone!,
                      ),
                    if (b.website != null && b.website!.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.language_outlined,
                        title: 'Website',
                        value: b.website!,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Operating Hours Card
            if (b.operatingHours != null) ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operating Hours',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 20),
                      Text(
                        b.operatingHours is Map
                            ? (b.operatingHours as Map).entries.map((e) => '${e.key}: ${e.value}').join('\n')
                            : b.operatingHours.toString(),
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isShortlisted ? Colors.grey.shade700 : AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_isShortlisted ? Icons.bookmark_remove : Icons.bookmark_add),
                label: Text(
                  _isShortlisted ? 'Remove from Shortlist' : 'Save to Supplier Shortlist',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isChecking ? null : _toggleShortlist,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
