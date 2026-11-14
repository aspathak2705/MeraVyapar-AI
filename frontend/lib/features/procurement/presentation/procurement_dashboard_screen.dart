import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../data/local_procurement_repository.dart';
import '../domain/procurement_models.dart';
import '../domain/quotation_comparison_engine.dart';

final localProcurementRepositoryProvider = Provider((ref) => LocalProcurementRepository());

class ProcurementDashboardScreen extends ConsumerStatefulWidget {
  final String merchantId;
  final VoidCallback? onBack;

  const ProcurementDashboardScreen({
    super.key,
    required this.merchantId,
    this.onBack,
  });

  @override
  ConsumerState<ProcurementDashboardScreen> createState() => _ProcurementDashboardScreenState();
}

class _ProcurementDashboardScreenState extends ConsumerState<ProcurementDashboardScreen>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.watch(localProcurementRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Procurement & KharidSaathi'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
          indicatorColor: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
          tabs: const [
            Tab(text: 'Purchase Requests'),
            Tab(text: 'Suppliers'),
            Tab(text: 'Quotations & Comparison'),
            Tab(text: 'Supplier Obligations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPurchaseRequestsTab(repo, isDark),
          _buildSuppliersTab(repo, isDark),
          _buildQuotationsTab(repo, isDark),
          _buildObligationsTab(repo, isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Entry',
        backgroundColor: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
        onPressed: () => _handleFabAction(context, repo),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildPurchaseRequestsTab(LocalProcurementRepository repo, bool isDark) {
    return FutureBuilder<List<PurchaseRequestModel>>(
      future: repo.getPurchaseRequests(merchantId: widget.merchantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('No purchase requests yet', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Use voice: "चाहिए 10 बोरी सीमेंट" or tap + to create one.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = requests[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: ListTile(
                title: Text(req.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Item: ${req.itemName} • Qty: ${req.quantity} ${req.unit}'),
                trailing: Chip(
                  label: Text(req.status, style: const TextStyle(fontSize: 11)),
                  backgroundColor: req.status == 'OPEN' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSuppliersTab(LocalProcurementRepository repo, bool isDark) {
    return FutureBuilder<List<SupplierModel>>(
      future: repo.getSuppliers(merchantId: widget.merchantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final suppliers = snapshot.data ?? [];
        if (suppliers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('No verified suppliers recorded', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Add suppliers to compare quotations and manage trade credit.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: suppliers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final sup = suppliers[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark ? AppColors.darkPrimaryPurple.withOpacity(0.2) : AppColors.primaryPurple.withOpacity(0.1),
                  child: Text(sup.name.isNotEmpty ? sup.name[0].toUpperCase() : 'S'),
                ),
                title: Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${sup.phoneNumber ?? "No phone"} • ${sup.category ?? "General"}'),
                trailing: Text(sup.contactPerson ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuotationsTab(LocalProcurementRepository repo, bool isDark) {
    return FutureBuilder<List<PurchaseRequestModel>>(
      future: repo.getPurchaseRequests(merchantId: widget.merchantId),
      builder: (context, reqSnapshot) {
        if (reqSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = reqSnapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(child: Text('Create a purchase request first to evaluate quotes.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            return FutureBuilder<List<SupplierQuotationModel>>(
              future: repo.getQuotations(merchantId: widget.merchantId, purchaseRequestId: req.id),
              builder: (context, quoteSnapshot) {
                final quotes = quoteSnapshot.data ?? [];
                final comparison = QuotationComparisonEngine.compare(quotes);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(req.itemName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${quotes.length} quotes', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (quotes.isEmpty)
                          const Text('No supplier quotations captured for this item yet.', style: TextStyle(color: Colors.grey, fontSize: 13))
                        else ...[
                          if (comparison.recommendedQuotationId != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      comparison.recommendationReason,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ...quotes.map((q) => Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(q.supplierName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text('Lead: ${q.deliveryDays}d • Unit: ₹${q.unitPriceInr.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₹${q.totalLandedCostInr.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        if (q.isAccepted)
                                          const Text('ACCEPTED', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))
                                        else
                                          TextButton(
                                            onPressed: () async {
                                              await repo.approveQuotationAndCreateObligation(
                                                quotationId: q.id,
                                                merchantId: widget.merchantId,
                                                paymentDueDate: DateTime.now().add(const Duration(days: 15)),
                                              );
                                              setState(() {});
                                            },
                                            child: const Text('Approve', style: TextStyle(fontSize: 12)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildObligationsTab(LocalProcurementRepository repo, bool isDark) {
    return FutureBuilder<List<SupplierObligationModel>>(
      future: repo.getSupplierObligations(merchantId: widget.merchantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final obligations = snapshot.data ?? [];
        if (obligations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handshake_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('No upcoming supplier obligations', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Approved purchase quotations automatically generate obligations.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final totalDuePaise = obligations.where((o) => o.status == 'PENDING').fold<int>(0, (sum, o) => sum + o.outstandingMinorUnits);

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Supplier Payables', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '₹${(totalDuePaise / 100.0).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: obligations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final ob = obligations[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: ListTile(
                      title: Text(ob.supplierName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Due: ${ob.dueDate.toIso8601String().split('T').first} • Status: ${ob.status}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${ob.outstandingInr.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (ob.status == 'PENDING') ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                              tooltip: 'Settle Obligation',
                              onPressed: () async {
                                await repo.settleSupplierObligation(
                                  merchantId: widget.merchantId,
                                  obligationId: ob.id,
                                  settleAmountPaise: ob.outstandingMinorUnits,
                                );
                                setState(() {});
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleFabAction(BuildContext context, LocalProcurementRepository repo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Add Purchase Request'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateRequestDialog(context, repo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Add Verified Supplier'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateSupplierDialog(context, repo);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateRequestDialog(BuildContext context, LocalProcurementRepository repo) {
    final itemCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'units');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Purchase Request'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
              const SizedBox(height: 8),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
              const SizedBox(height: 8),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit (e.g. kg, bags, pcs)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (itemCtrl.text.trim().isNotEmpty) {
                final navigator = Navigator.of(context);
                await repo.createPurchaseRequest(
                  merchantId: widget.merchantId,
                  title: itemCtrl.text.trim(),
                  itemName: itemCtrl.text.trim(),
                  quantity: double.tryParse(qtyCtrl.text.trim()) ?? 1.0,
                  unit: unitCtrl.text.trim(),
                );
                if (mounted) {
                  navigator.pop();
                  setState(() {});
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCreateSupplierDialog(BuildContext context, LocalProcurementRepository repo) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'General');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Verified Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Supplier Name')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
              const SizedBox(height: 8),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                final navigator = Navigator.of(context);
                await repo.createSupplier(
                  merchantId: widget.merchantId,
                  name: nameCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  category: categoryCtrl.text.trim(),
                );
                if (mounted) {
                  navigator.pop();
                  setState(() {});
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
