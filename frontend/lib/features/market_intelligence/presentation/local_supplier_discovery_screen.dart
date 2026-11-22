import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/market_event_model.dart';
import '../domain/shortlisted_supplier_model.dart';
import '../data/market_intelligence_repository.dart';
import '../data/local_supplier_shortlist_repository.dart';
import '../../onboarding/domain/merchant_business_profile.dart';
import 'interactive_local_map_widget.dart';
import 'business_detail_screen.dart';

enum DiscoveryViewMode { split, mapOnly, listOnly }

class LocalSupplierDiscoveryScreen extends ConsumerStatefulWidget {
  final String merchantId;
  final MerchantBusinessProfile? merchantProfile;
  final MarketIntelligenceRepository? repository;
  final VoidCallback? onBack;
  final VoidCallback? onOpenShortlist;

  const LocalSupplierDiscoveryScreen({
    super.key,
    required this.merchantId,
    this.merchantProfile,
    this.repository,
    this.onBack,
    this.onOpenShortlist,
  });

  @override
  ConsumerState<LocalSupplierDiscoveryScreen> createState() =>
      _LocalSupplierDiscoveryScreenState();
}

class _LocalSupplierDiscoveryScreenState
    extends ConsumerState<LocalSupplierDiscoveryScreen> {
  late final TextEditingController _queryController;
  late final TextEditingController _locationController;
  late final MarketIntelligenceRepository _repo;

  List<MarketEventModel> _discoveredBusinesses = [];
  MarketEventModel? _selectedBusiness;
  DiscoveryViewMode _viewMode = DiscoveryViewMode.split;
  bool _isLoading = false;
  String? _errorMessage;
  Set<String> _shortlistedNames = {};

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MarketIntelligenceRepository();

    final profile = widget.merchantProfile;
    final defaultQuery = (profile != null && profile.mainProcurementCategories.isNotEmpty)
        ? '${profile.mainProcurementCategories.split(",").first.trim()} wholesale supplier'
        : (profile != null && profile.businessCategory.isNotEmpty)
            ? '${profile.businessCategory} distributor supplier'
            : 'wholesale suppliers distributors';

    final defaultLocation = profile?.city.isNotEmpty == true
        ? profile!.city
        : (profile?.state.isNotEmpty == true ? profile!.state : 'India');

    _queryController = TextEditingController(text: defaultQuery);
    _locationController = TextEditingController(text: defaultLocation);

    _loadShortlistCache();
    _searchSuppliers();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadShortlistCache() async {
    final shortlistRepo = ref.read(localSupplierShortlistRepositoryProvider);
    final items = await shortlistRepo.getShortlist(merchantId: widget.merchantId);
    if (mounted) {
      setState(() {
        _shortlistedNames = items.map((i) => i.businessName).toSet();
      });
    }
  }

  Future<void> _searchSuppliers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _repo.getRelevantSignals(
        query: _queryController.text.trim(),
        city: _locationController.text.trim(),
        engine: 'google_maps',
        mapsType: 'search',
      );

      final businesses = results
          .map((r) => r.marketEvent)
          .whereType<MarketEventModel>()
          .toList();

      if (mounted) {
        setState(() {
          _discoveredBusinesses = businesses;
          _selectedBusiness = businesses.isNotEmpty ? businesses.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _toggleShortlist(MarketEventModel business) async {
    final shortlistRepo = ref.read(localSupplierShortlistRepositoryProvider);
    final isSaved = _shortlistedNames.contains(business.title);

    if (isSaved) {
      final items = await shortlistRepo.getShortlist(merchantId: widget.merchantId);
      final found = items.firstWhere(
        (i) => i.businessName == business.title,
        orElse: () => items.first,
      );
      await shortlistRepo.removeFromShortlist(found.id);
      _shortlistedNames.remove(business.title);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "${business.title}" from shortlist.')),
        );
      }
    } else {
      final supplier = ShortlistedSupplierModel.fromMarketEvent(
        widget.merchantId,
        business,
      );
      await shortlistRepo.addToShortlist(supplier);
      _shortlistedNames.add(business.title);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "${business.title}" to shortlist.')),
        );
      }
    }
  }

  void _openDetail(MarketEventModel business) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(
          business: business,
          merchantId: widget.merchantId,
        ),
      ),
    ).then((_) => _loadShortlistCache());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Supplier Discovery'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.bookmarks_outlined),
                if (_shortlistedNames.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_shortlistedNames.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Saved Shortlist',
            onPressed: widget.onOpenShortlist,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _queryController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText: 'Search suppliers, wholesalers...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onSubmitted: (_) => _searchSuppliers(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.location_on, size: 18, color: AppColors.primaryPurple),
                          hintText: 'City / State',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onSubmitted: (_) => _searchSuppliers(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 20),
                      onPressed: _searchSuppliers,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // View Toggle & Result Count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isLoading
                          ? 'Searching nearby...'
                          : '${_discoveredBusinesses.length} suppliers found',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                    SegmentedButton<DiscoveryViewMode>(
                      segments: const [
                        ButtonSegment(
                          value: DiscoveryViewMode.split,
                          icon: Icon(Icons.dashboard_outlined, size: 16),
                          label: Text('Split', style: TextStyle(fontSize: 11)),
                        ),
                        ButtonSegment(
                          value: DiscoveryViewMode.mapOnly,
                          icon: Icon(Icons.map_outlined, size: 16),
                          label: Text('Map', style: TextStyle(fontSize: 11)),
                        ),
                        ButtonSegment(
                          value: DiscoveryViewMode.listOnly,
                          icon: Icon(Icons.view_list, size: 16),
                          label: Text('List', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (val) {
                        setState(() => _viewMode = val.first);
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main View Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 16),
                        Text('Querying local supplier intelligence...'),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _searchSuppliers,
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _discoveredBusinesses.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.store_outlined, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No local suppliers found for this search.',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Try widening your keyword or changing the location.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildViewContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildViewContent(bool isDark) {
    switch (_viewMode) {
      case DiscoveryViewMode.mapOnly:
        return InteractiveLocalMapWidget(
          businesses: _discoveredBusinesses,
          selectedBusiness: _selectedBusiness,
          onBusinessSelected: (b) {
            setState(() => _selectedBusiness = b);
            _openDetail(b);
          },
          height: double.infinity,
        );

      case DiscoveryViewMode.listOnly:
        return _buildBusinessList(isDark);

      case DiscoveryViewMode.split:
        return Column(
          children: [
            InteractiveLocalMapWidget(
              businesses: _discoveredBusinesses,
              selectedBusiness: _selectedBusiness,
              onBusinessSelected: (b) {
                setState(() => _selectedBusiness = b);
              },
              height: 240,
            ),
            Expanded(child: _buildBusinessList(isDark)),
          ],
        );
    }
  }

  Widget _buildBusinessList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _discoveredBusinesses.length,
      itemBuilder: (context, index) {
        final b = _discoveredBusinesses[index];
        final isSelected = b.id == _selectedBusiness?.id;
        final isShortlisted = _shortlistedNames.contains(b.title);

        return Card(
          elevation: isSelected ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primaryPurple
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
              width: isSelected ? 2 : 1,
            ),
          ),
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              setState(() => _selectedBusiness = b);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Shortlist Action
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (b.category != null || b.sector != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  b.category ?? b.sector ?? 'Wholesale',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primaryPurple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isShortlisted ? Icons.bookmark : Icons.bookmark_border,
                          color: isShortlisted ? AppColors.primaryPurple : Colors.grey,
                        ),
                        tooltip: isShortlisted ? 'In Shortlist' : 'Add to Shortlist',
                        onPressed: () => _toggleShortlist(b),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rating and reviews
                  Row(
                    children: [
                      if (b.rating != null) ...[
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          b.rating!.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (b.reviews != null)
                        Text(
                          '(${b.reviews} reviews)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      const Spacer(),
                      // Unverified local discovery pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
                        ),
                        child: Text(
                          'Unverified Discovery',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Address
                  if (b.location != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            b.location!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 10),
                  // Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (b.phone != null && b.phone!.isNotEmpty) ...[
                        Text(
                          b.phone!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                      ],
                      TextButton.icon(
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('View Details', style: TextStyle(fontSize: 12)),
                        onPressed: () => _openDetail(b),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
