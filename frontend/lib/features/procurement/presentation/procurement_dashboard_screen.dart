import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/local_procurement_repository.dart';
import '../domain/procurement_models.dart';
import '../domain/quotation_comparison_engine.dart';
import '../domain/negotiation_intelligence_engine.dart';
import '../domain/procurement_voice_assistant.dart';

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
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.watch(localProcurementRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.procurementAndKharidSaathi ?? 'KharidSaathi — AI Procurement Copilot'),
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
            Tab(text: 'Quotations & Comparison'),
            Tab(text: 'Suppliers & Memory'),
            Tab(text: 'Orders & Outcomes'),
            Tab(text: 'Supplier Obligations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPurchaseRequestsTab(repo, isDark, l10n),
          _buildQuotationsTab(repo, isDark),
          _buildSuppliersTab(repo, isDark),
          _buildOrdersTab(repo, isDark),
          _buildObligationsTab(repo, isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Procurement Actions',
        backgroundColor: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
        icon: const Icon(Icons.bolt_rounded, color: Colors.white),
        label: const Text('New Action', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _handleFabAction(context, repo),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: Purchase Requests
  // -------------------------------------------------------------
  Widget _buildPurchaseRequestsTab(LocalProcurementRepository repo, bool isDark, AppLocalizations? l10n) {
    return FutureBuilder<List<PurchaseRequestModel>>(
      future: repo.getPurchaseRequests(merchantId: widget.merchantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No purchase requests recorded yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Tap "New Action" or speak your requirement (e.g., "500 kg SS304 sheets").', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.mic_rounded),
                    label: const Text('Voice / Natural Requirement'),
                    onPressed: () => _showVoiceRequirementDialog(context, repo),
                  ),
                ],
              ),
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(req.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        Chip(
                          label: Text(req.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: req.status == 'OPEN' ? Colors.blue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Item: ${req.itemName} • Quantity: ${req.quantity} ${req.unit}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (req.gradeSpec != null || req.dimensions != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Specs: ${[req.gradeSpec, req.dimensions].where((s) => s != null && s.isNotEmpty).join(' • ')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                    if (req.deliveryTimeline != null) ...[
                      const SizedBox(height: 2),
                      Text('Timeline: ${req.deliveryTimeline}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 2: Quotations & Multi-Attribute Comparison
  // -------------------------------------------------------------
  Widget _buildQuotationsTab(LocalProcurementRepository repo, bool isDark) {
    return FutureBuilder<List<PurchaseRequestModel>>(
      future: repo.getPurchaseRequests(merchantId: widget.merchantId),
      builder: (context, reqSnapshot) {
        if (reqSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = reqSnapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.request_quote_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('No purchase requests found', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Create a purchase request first to record and compare quotations.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
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

                return FutureBuilder<Map<String, SupplierMemoryModel>>(
                  future: repo.getSupplierMemoriesForQuotes(merchantId: widget.merchantId, quotes: quotes),
                  builder: (context, memorySnapshot) {
                    final memories = memorySnapshot.data ?? {};
                    final comparison = QuotationComparisonEngine.compare(
                      quotes,
                      requiredSpecification: req.gradeSpec,
                      requiredUnit: req.unit,
                      supplierMemories: memories,
                    );

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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(req.itemName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      Text('Target: ${req.quantity} ${req.unit}${req.gradeSpec != null ? ' (${req.gradeSpec})' : ''}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Quote', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _showCreateQuotationDialog(context, repo, presetRequestId: req.id, presetItem: req.itemName, presetUnit: req.unit),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (quotes.isEmpty)
                              const Text('No supplier quotations captured for this item yet.', style: TextStyle(color: Colors.grey, fontSize: 13))
                            else ...[
                              // Explainable Recommendation Card
                              if (comparison.recommendedQuotationId != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('KharidSaathi Copilot Recommendation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                                            const SizedBox(height: 2),
                                            Text(
                                              comparison.recommendationReason,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Quotation Items List
                              ...quotes.map((q) {
                                final memory = memories[q.supplierId];
                                final isRecommended = q.id == comparison.recommendedQuotationId;

                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isRecommended ? Colors.green.withValues(alpha: 0.5) : (isDark ? Colors.white12 : Colors.black12),
                                      width: isRecommended ? 1.5 : 1.0,
                                    ),
                                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.01),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(q.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                  if (isRecommended) ...[
                                                    const SizedBox(width: 6),
                                                    const Chip(
                                                      label: Text('BEST VALUE', style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                                                      backgroundColor: Colors.transparent,
                                                      visualDensity: VisualDensity.compact,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              Text('Unit: ₹${q.unitPriceInr.toStringAsFixed(2)}/${q.unit} • ${q.isGstInclusive ? "GST Inc." : "+${q.gstRatePercent}% GST"} • Lead: ${q.deliveryDays}d',
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('₹${q.totalLandedCostInr.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              const Text('Landed Cost', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Supplier Memory & Freight notes
                                      Row(
                                        children: [
                                          Icon(memory != null && memory.hasHistory ? Icons.history_rounded : Icons.info_outline_rounded, size: 14, color: Colors.blueGrey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              memory != null && memory.hasHistory
                                                  ? 'Supplier Memory: ${memory.totalOrdersCompleted} past orders (${memory.onTimeRatePercent.toInt()}% on-time)'
                                                  : 'Supplier Memory: No purchase history available',
                                              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      // Action Buttons
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.handshake_outlined, size: 14),
                                            label: const Text('Negotiate', style: TextStyle(fontSize: 11)),
                                            onPressed: () => _showNegotiationDialog(context, currentQuote: q, allQuotes: quotes, supplierMemory: memory),
                                          ),
                                          const SizedBox(width: 8),
                                          if (q.isAccepted)
                                            const Chip(label: Text('APPROVED', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)))
                                          else
                                            FilledButton(
                                              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                              onPressed: () => _showReviewApprovePODialog(context, repo, q),
                                              child: const Text('Review & Approve PO', style: TextStyle(fontSize: 11)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
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
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 3: Verified Suppliers & Supplier Memory
  // -------------------------------------------------------------
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
                const Text('Add suppliers to track purchasing history, quality, and delivery performance.', style: TextStyle(color: Colors.grey)),
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
            return FutureBuilder<SupplierMemoryModel>(
              future: repo.getSupplierMemory(merchantId: widget.merchantId, supplierId: sup.id),
              builder: (context, memSnapshot) {
                final mem = memSnapshot.data;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: isDark ? AppColors.darkPrimaryPurple.withValues(alpha: 0.2) : AppColors.primaryPurple.withValues(alpha: 0.1),
                      child: Text(sup.name.isNotEmpty ? sup.name[0].toUpperCase() : 'S'),
                    ),
                    title: Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${sup.phoneNumber ?? "No phone"} • ${sup.category ?? "General"}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            const Text('Verified Supplier Memory (Engine 2):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            if (mem != null && mem.hasHistory) ...[
                              Text('• Total Completed Purchases: ${mem.totalOrdersCompleted}', style: const TextStyle(fontSize: 12)),
                              Text('• On-Time Delivery Rate: ${mem.onTimeRatePercent.toStringAsFixed(0)}% (${mem.onTimeDeliveries} on-time, ${mem.delayedDeliveries} late)', style: const TextStyle(fontSize: 12)),
                              Text('• Quality Incidents / Rejections: ${mem.defectIncidents}', style: TextStyle(fontSize: 12, color: mem.hasQualityIssues ? Colors.red : Colors.green)),
                              if (mem.recentPurchases.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                const Text('Recent Purchase Prices:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                                ...mem.recentPurchases.take(3).map((p) => Text(
                                      '  - ${p.itemName}: ₹${p.unitPriceInr.toStringAsFixed(2)}/${p.unit} on ${p.purchaseDate.toIso8601String().split('T').first}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    )),
                              ],
                            ] else ...[
                              const Text('No purchase history available. New supplier.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 4: Purchase Orders & Outcome Recording
  // -------------------------------------------------------------
  Widget _buildOrdersTab(LocalProcurementRepository repo, bool isDark) {
    return FutureBuilder<List<PurchaseOrderModel>>(
      future: repo.getPurchaseOrders(merchantId: widget.merchantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('No purchase orders placed yet', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Approving a quotation generates a Purchase Order.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final po = orders[index];
            final isDelivered = po.deliveryStatus != 'PENDING';

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PO: ${po.itemName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('₹${po.totalAmountInr.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Supplier: ${po.supplierName} • ${po.quantity} ${po.unit}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(
                          label: Text(po.deliveryStatus, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: po.deliveryStatus == 'DELIVERED_ON_TIME'
                              ? Colors.green.withValues(alpha: 0.1)
                              : (po.deliveryStatus == 'PENDING' ? Colors.orange.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1)),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text('Quality: ${po.qualityStatus}', style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    if (!isDelivered) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.rate_review_rounded, size: 14),
                          label: const Text('Record Outcome & Learning', style: TextStyle(fontSize: 11)),
                          onPressed: () => _showRecordOutcomeDialog(context, repo, po),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 5: Supplier Obligations & Cashflow Integration
  // -------------------------------------------------------------
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
                const Text('Approved purchase orders automatically generate cashflow obligations.', style: TextStyle(color: Colors.grey)),
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

  // -------------------------------------------------------------
  // DIALOGS & WORKFLOW ACTIONS
  // -------------------------------------------------------------

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
                leading: const Icon(Icons.mic_rounded, color: Colors.purple),
                title: const Text('Voice / Natural Requirement', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Speak requirement with interactive specification clarification'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showVoiceRequirementDialog(context, repo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Add Purchase Request (Manual)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateRequestDialog(context, repo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Add Supplier Quotation'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateQuotationDialog(context, repo);
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

  // 1. Voice-Based Purchase Requirement with Specification Clarification
  void _showVoiceRequirementDialog(BuildContext context, LocalProcurementRepository repo) {
    final speechCtrl = TextEditingController(text: 'Mujhe 500 kg stainless steel 304 sheets chahiye, next week tak delivery chahiye');
    ParsedRequirementDraft draft = ProcurementVoiceAssistant.parseRequirement(speechCtrl.text);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mic_rounded, color: Colors.purple),
                SizedBox(width: 8),
                Text('Voice Purchase Requirement'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spoken / Natural Input:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: speechCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    onChanged: (val) {
                      setDialogState(() {
                        draft = ProcurementVoiceAssistant.parseRequirement(val);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Extracted Procurement Specifications:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('• Item: ${draft.itemName}'),
                  Text('• Quantity: ${draft.quantity} ${draft.unit}'),
                  if (draft.gradeSpec != null) Text('• Grade: ${draft.gradeSpec}'),
                  if (draft.dimensions != null) Text('• Dimensions: ${draft.dimensions}'),
                  if (draft.thickness != null) Text('• Thickness: ${draft.thickness}'),
                  if (draft.deliveryTimeline != null) Text('• Timeline: ${draft.deliveryTimeline}'),
                  const SizedBox(height: 12),

                  // Specification Clarification Step (4.2 Acceptance Criteria)
                  if (!draft.isReadyForConfirmation && draft.clarificationQuestion != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.help_outline_rounded, color: Colors.amber, size: 18),
                              SizedBox(width: 6),
                              Text('Clarification Needed:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(draft.clarificationQuestion!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Add 2mm (8x4 ft)', style: TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    setDialogState(() {
                                      speechCtrl.text += ' 2mm 8x4 ft';
                                      draft = ProcurementVoiceAssistant.parseRequirement(speechCtrl.text);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  await repo.createPurchaseRequest(
                    merchantId: widget.merchantId,
                    title: draft.itemName,
                    itemName: draft.itemName,
                    quantity: draft.quantity,
                    unit: draft.unit,
                    gradeSpec: draft.gradeSpec,
                    dimensions: draft.dimensions ?? (draft.thickness != null ? 'Thk: ${draft.thickness}' : null),
                    deliveryTimeline: draft.deliveryTimeline,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('Confirm Requirement'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 2. Add Supplier Quotation Dialog
  void _showCreateQuotationDialog(
    BuildContext context,
    LocalProcurementRepository repo, {
    String? presetRequestId,
    String? presetItem,
    String? presetUnit,
  }) async {
    final suppliers = await repo.getSuppliers(merchantId: widget.merchantId);
    final requests = await repo.getPurchaseRequests(merchantId: widget.merchantId);

    if (suppliers.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one verified supplier first.')),
      );
      return;
    }

    String selectedSupplierId = suppliers.first.id;
    String selectedSupplierName = suppliers.first.name;
    String? selectedRequestId = presetRequestId ?? (requests.isNotEmpty ? requests.first.id : null);

    final itemCtrl = TextEditingController(text: presetItem ?? (requests.isNotEmpty ? requests.first.itemName : ''));
    final specCtrl = TextEditingController(text: 'SS 304 2mm 8x4 ft');
    final qtyCtrl = TextEditingController(text: requests.isNotEmpty ? requests.first.quantity.toString() : '500');
    final unitCtrl = TextEditingController(text: presetUnit ?? (requests.isNotEmpty ? requests.first.unit : 'kg'));
    final unitPriceCtrl = TextEditingController(text: '210.00');
    final freightCtrl = TextEditingController(text: '1500.00');
    final leadDaysCtrl = TextEditingController(text: '7');
    bool isGstInclusive = false;
    double gstPercent = 18.0;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Supplier Quotation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSupplierId,
                    decoration: const InputDecoration(labelText: 'Supplier'),
                    items: suppliers
                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedSupplierId = val;
                          selectedSupplierName = suppliers.firstWhere((s) => s.id == val).name;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
                  const SizedBox(height: 8),
                  TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Specification / Grade')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: unitPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit Price (₹)'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: freightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Freight (₹)'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: leadDaysCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Lead Time (Days)'))),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: isGstInclusive,
                            onChanged: (val) => setDialogState(() => isGstInclusive = val ?? false),
                          ),
                          const Text('GST Inc.', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                  final unitPriceInr = double.tryParse(unitPriceCtrl.text.trim()) ?? 0.0;
                  final freightInr = double.tryParse(freightCtrl.text.trim()) ?? 0.0;
                  final unitPricePaise = (unitPriceInr * 100).round();
                  final freightPaise = (freightInr * 100).round();

                  await repo.createQuotation(
                    merchantId: widget.merchantId,
                    purchaseRequestId: selectedRequestId,
                    supplierId: selectedSupplierId,
                    supplierName: selectedSupplierName,
                    itemName: itemCtrl.text.trim(),
                    specification: specCtrl.text.trim().isEmpty ? null : specCtrl.text.trim(),
                    quantity: qty,
                    unit: unitCtrl.text.trim(),
                    unitPriceMinorUnits: unitPricePaise,
                    freightMinorUnits: freightPaise,
                    gstRatePercent: gstPercent,
                    deliveryDays: int.tryParse(leadDaysCtrl.text.trim()) ?? 7,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('Save Quotation'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 3. Negotiation Intelligence Assistant Dialog
  void _showNegotiationDialog(
    BuildContext context, {
    required SupplierQuotationModel currentQuote,
    required List<SupplierQuotationModel> allQuotes,
    SupplierMemoryModel? supplierMemory,
  }) {
    final insights = NegotiationIntelligenceEngine.generateInsights(
      currentQuote: currentQuote,
      alternativeQuotes: allQuotes,
      supplierMemory: supplierMemory,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.handshake_rounded, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(child: Text('Negotiation Intelligence: ${currentQuote.supplierName}', style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Identified Negotiation Opportunities:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              if (insights.opportunities.isEmpty)
                const Text('No direct price discrepancies detected. Standard commercial terms apply.', style: TextStyle(fontSize: 12, color: Colors.grey))
              else
                ...insights.opportunities.map((op) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ${op.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(op.description, style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
                        ],
                      ),
                    )),
              const SizedBox(height: 12),
              if (insights.suggestedCounterofferInr != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recommended Counteroffer: ₹${insights.suggestedCounterofferInr!.toStringAsFixed(2)}/${currentQuote.unit}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                      const SizedBox(height: 2),
                      Text(insights.counterofferRationale, style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Prepared WhatsApp / Message Draft:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(insights.draftMessageEnglish, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('Copy Draft Message'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: insights.draftMessageEnglish));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Negotiation message copied to clipboard!')),
              );
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // 4. Purchase Order Review & Approval Dialog
  void _showReviewApprovePODialog(BuildContext context, LocalProcurementRepository repo, SupplierQuotationModel quote) {
    DateTime dueDate = DateTime.now().add(const Duration(days: 15));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Review Purchase Order Draft'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Supplier: ${quote.supplierName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Item: ${quote.itemName} ${quote.specification != null ? "(${quote.specification})" : ""}'),
                  Text('Quantity: ${quote.quantity} ${quote.unit}'),
                  const Divider(height: 20),
                  Text('Unit Price: ₹${quote.unitPriceInr.toStringAsFixed(2)}/${quote.unit}'),
                  Text('Freight: ₹${quote.freightInr.toStringAsFixed(2)}'),
                  Text('GST: ${quote.isGstInclusive ? "Inclusive" : "${quote.gstRatePercent}%"}'),
                  const SizedBox(height: 6),
                  Text('Total Landed Amount: ₹${quote.totalLandedCostInr.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Due Date:'),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => dueDate = picked);
                          }
                        },
                        child: Text(dueDate.toIso8601String().split('T').first),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  await repo.approveQuotationAndCreateObligation(
                    quotationId: quote.id,
                    merchantId: widget.merchantId,
                    paymentDueDate: dueDate,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('Confirm & Approve PO'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 5. Record Purchase Outcome & Update Supplier Memory
  void _showRecordOutcomeDialog(BuildContext context, LocalProcurementRepository repo, PurchaseOrderModel po) {
    String deliveryStatus = 'DELIVERED_ON_TIME';
    String qualityStatus = 'ACCEPTED_GOOD';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Record Purchase Outcome'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order: ${po.itemName} (${po.quantity} ${po.unit})'),
                  Text('Supplier: ${po.supplierName}'),
                  const SizedBox(height: 12),
                  const Text('Delivery Performance:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: deliveryStatus,
                    items: const [
                      DropdownMenuItem(value: 'DELIVERED_ON_TIME', child: Text('Delivered On Time')),
                      DropdownMenuItem(value: 'DELIVERED_LATE', child: Text('Delivered Late / Delayed')),
                      DropdownMenuItem(value: 'FAILED', child: Text('Delivery Failed / Cancelled')),
                    ],
                    onChanged: (val) => setDialogState(() => deliveryStatus = val ?? deliveryStatus),
                  ),
                  const SizedBox(height: 12),
                  const Text('Quality Outcome:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: qualityStatus,
                    items: const [
                      DropdownMenuItem(value: 'ACCEPTED_GOOD', child: Text('Accepted — Quality Good')),
                      DropdownMenuItem(value: 'PARTIAL_REJECT', child: Text('Partial Rejection / Damage')),
                      DropdownMenuItem(value: 'DEFECT_REPORTED', child: Text('Defect Reported / Rejected')),
                    ],
                    onChanged: (val) => setDialogState(() => qualityStatus = val ?? qualityStatus),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  await repo.recordPurchaseOutcome(
                    merchantId: widget.merchantId,
                    purchaseOrderId: po.id,
                    deliveryStatus: deliveryStatus,
                    qualityStatus: qualityStatus,
                    deliveredAt: DateTime.now(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('Save & Update Memory'),
              ),
            ],
          );
        },
      ),
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
                await repo.createPurchaseRequest(
                  merchantId: widget.merchantId,
                  title: itemCtrl.text.trim(),
                  itemName: itemCtrl.text.trim(),
                  quantity: double.tryParse(qtyCtrl.text.trim()) ?? 1.0,
                  unit: unitCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
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
                await repo.createSupplier(
                  merchantId: widget.merchantId,
                  name: nameCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  category: categoryCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
