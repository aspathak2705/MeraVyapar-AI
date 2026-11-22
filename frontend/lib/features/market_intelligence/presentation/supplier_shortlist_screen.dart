import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/shortlisted_supplier_model.dart';
import '../data/local_supplier_shortlist_repository.dart';

class SupplierShortlistScreen extends ConsumerStatefulWidget {
  final String merchantId;
  final VoidCallback? onBack;
  final VoidCallback? onExploreSuppliers;

  const SupplierShortlistScreen({
    super.key,
    required this.merchantId,
    this.onBack,
    this.onExploreSuppliers,
  });

  @override
  ConsumerState<SupplierShortlistScreen> createState() =>
      _SupplierShortlistScreenState();
}

class _SupplierShortlistScreenState
    extends ConsumerState<SupplierShortlistScreen> {
  List<ShortlistedSupplierModel> _shortlist = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0: List, 1: Compare
  final Set<String> _selectedForComparison = {};

  @override
  void initState() {
    super.initState();
    _loadShortlist();
  }

  Future<void> _loadShortlist() async {
    setState(() => _isLoading = true);
    final repo = ref.read(localSupplierShortlistRepositoryProvider);
    final items = await repo.getShortlist(merchantId: widget.merchantId);
    if (mounted) {
      setState(() {
        _shortlist = items;
        _isLoading = false;
        // Default select all if <= 3, else first 2
        if (_selectedForComparison.isEmpty && items.isNotEmpty) {
          if (items.length <= 3) {
            _selectedForComparison.addAll(items.map((i) => i.id));
          } else {
            _selectedForComparison.addAll(items.take(2).map((i) => i.id));
          }
        }
      });
    }
  }

  Future<void> _removeSupplier(String id, String name) async {
    final repo = ref.read(localSupplierShortlistRepositoryProvider);
    await repo.removeFromShortlist(id);
    _selectedForComparison.remove(id);
    await _loadShortlist();
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.removedFromShortlist ?? 'Removed "$name" from shortlist.')),
      );
    }
  }

  Future<void> _editNotes(ShortlistedSupplierModel item) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: item.notes ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n?.tradeNotes ?? "Notes"} - ${item.businessName}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '${l10n?.tradeNotes ?? "Trade Notes"}...',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n?.saveNotes ?? 'Save Note'),
          ),
        ],
      ),
    );

    if (saved != null) {
      final repo = ref.read(localSupplierShortlistRepositoryProvider);
      await repo.updateNotes(item.id, saved);
      await _loadShortlist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.supplierShortlist ?? 'Supplier Shortlist'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          if (widget.onExploreSuppliers != null)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: l10n?.localSupplierDiscovery ?? 'Explore Map',
              onPressed: widget.onExploreSuppliers,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: isDark ? AppColors.darkCard : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTabIndex == 0
                                ? AppColors.primaryPurple
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${l10n?.savedSuppliers ?? "Saved Suppliers"} (${_shortlist.length})',
                        style: TextStyle(
                          fontWeight: _selectedTabIndex == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedTabIndex == 0
                              ? AppColors.primaryPurple
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTabIndex == 1
                                ? AppColors.primaryPurple
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${l10n?.compareSelected ?? "Compare Selected"} (${_selectedForComparison.length})',
                        style: TextStyle(
                          fontWeight: _selectedTabIndex == 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedTabIndex == 1
                              ? AppColors.primaryPurple
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shortlist.isEmpty
              ? _buildEmptyState(isDark)
              : _selectedTabIndex == 0
                  ? _buildShortlistTab(isDark)
                  : _buildComparisonTab(isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              l10n?.noSuppliersFound ?? 'No Saved Suppliers Yet',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover local wholesalers and suppliers on Google Maps and bookmark them to compare ratings, phone numbers, and locations offline.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            if (widget.onExploreSuppliers != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.explore),
                label: Text(l10n?.localSupplierDiscovery ?? 'Discover Local Suppliers'),
                onPressed: widget.onExploreSuppliers,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortlistTab(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _shortlist.length,
      itemBuilder: (context, index) {
        final item = _shortlist[index];
        final isSelectedForCompare = _selectedForComparison.contains(item.id);

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelectedForCompare
                  ? AppColors.primaryPurple.withValues(alpha: 0.6)
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
              width: isSelectedForCompare ? 1.5 : 1,
            ),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Checkbox & Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isSelectedForCompare,
                      activeColor: AppColors.primaryPurple,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedForComparison.add(item.id);
                          } else {
                            _selectedForComparison.remove(item.id);
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.businessName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          if (item.businessCategory != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.businessCategory!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                      tooltip: 'Remove from shortlist',
                      onPressed: () => _removeSupplier(item.id, item.businessName),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Rating & Reviews
                Row(
                  children: [
                    const SizedBox(width: 48), // align with title
                    if (item.rating != null) ...[
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        item.rating!.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (item.reviewCount != null)
                      Text(
                        '(${item.reviewCount} reviews)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Address & Phone
                if (item.address != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 48),
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.address!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],

                if (item.phone != null && item.phone!.isNotEmpty) ...[
                  Row(
                    children: [
                      const SizedBox(width: 48),
                      Icon(Icons.phone_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      SelectableText(
                        item.phone!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // Notes section
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.notes != null && item.notes!.isNotEmpty
                            ? 'Note: ${item.notes}'
                            : 'No notes added.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: item.notes != null && item.notes!.isNotEmpty
                              ? FontStyle.normal
                              : FontStyle.italic,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: Text(
                        item.notes != null && item.notes!.isNotEmpty ? 'Edit Note' : 'Add Note',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _editNotes(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComparisonTab(bool isDark) {
    final l10n = AppLocalizations.of(context);
    final selectedItems = _shortlist
        .where((item) => _selectedForComparison.contains(item.id))
        .toList();

    if (selectedItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.compare_arrows, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                l10n?.supplierComparison ?? 'No Suppliers Selected for Comparison',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                l10n?.selectAtLeastTwoToCompare ??
                    'Switch to the "Saved Suppliers" tab and select 2 or more businesses to compare them side-by-side.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() => _selectedTabIndex = 0),
                child: Text(l10n?.savedSuppliers ?? 'Go to Saved Suppliers'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n?.compareSelected ?? "Comparing"} (${selectedItems.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Horizontal scrollable multi-column table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(
                AppColors.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.08),
              ),
              columns: [
                const DataColumn(
                  label: Text(
                    'Metric',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...selectedItems.map(
                  (s) => DataColumn(
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        s.businessName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
              rows: [
                _buildComparisonRow(
                  'Category',
                  selectedItems.map((s) => s.businessCategory ?? '—').toList(),
                ),
                _buildComparisonRow(
                  'Rating',
                  selectedItems.map((s) => s.rating != null ? '★ ${s.rating!.toStringAsFixed(1)}' : '—').toList(),
                ),
                _buildComparisonRow(
                  'Reviews',
                  selectedItems.map((s) => s.reviewCount != null ? '${s.reviewCount} reviews' : '—').toList(),
                ),
                _buildComparisonRow(
                  'Phone',
                  selectedItems.map((s) => s.phone ?? '—').toList(),
                ),
                _buildComparisonRow(
                  'Address',
                  selectedItems.map((s) => s.address ?? '—').toList(),
                ),
                _buildComparisonRow(
                  'Website',
                  selectedItems.map((s) => s.website != null && s.website!.isNotEmpty ? 'Available' : '—').toList(),
                ),
                _buildComparisonRow(
                  'Hours',
                  selectedItems.map((s) => s.operatingHours != null && s.operatingHours!.isNotEmpty ? s.operatingHours! : '—').toList(),
                ),
                _buildComparisonRow(
                  'Saved Note',
                  selectedItems.map((s) => s.notes != null && s.notes!.isNotEmpty ? s.notes! : '—').toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  DataRow _buildComparisonRow(String metric, List<String> values) {
    return DataRow(
      cells: [
        DataCell(
          Text(metric, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
        ...values.map(
          (v) => DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: SelectableText(
                v,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
