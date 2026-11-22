import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/merchant_market_relevance_model.dart';
import '../../onboarding/domain/merchant_business_profile.dart';

enum MarketSignalsState {
  initial,
  loading,
  loaded,
  empty,
  networkError,
  providerNotConfigured,
  error,
}

class RelevantMarketSignalsScreen extends StatefulWidget {
  final List<MerchantMarketRelevanceModel> initialSignals;
  final Function(MerchantMarketRelevanceModel signal) onSignalTap;
  final Future<List<MerchantMarketRelevanceModel>> Function({
    String? query,
    String? category,
    String? businessType,
    String? city,
    String? state,
    String? engine,
    String? mapsType,
    String? placeId,
  }) onFetchSignals;
  final MerchantBusinessProfile? merchantProfile;
  final VoidCallback? onBack;
  final VoidCallback? onOpenLocalSuppliers;

  const RelevantMarketSignalsScreen({
    super.key,
    required this.initialSignals,
    required this.onSignalTap,
    required this.onFetchSignals,
    this.merchantProfile,
    this.onBack,
    this.onOpenLocalSuppliers,
  });

  @override
  State<RelevantMarketSignalsScreen> createState() =>
      _RelevantMarketSignalsScreenState();
}

class _RelevantMarketSignalsScreenState
    extends State<RelevantMarketSignalsScreen> {
  late TextEditingController _searchController;
  List<MerchantMarketRelevanceModel> _signals = [];
  MarketSignalsState _state = MarketSignalsState.initial;
  String? _errorMessage;
  String _activeQuery = '';
  String _selectedEngine = 'google';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    if (widget.initialSignals.isNotEmpty) {
      _signals = widget.initialSignals;
      _state = MarketSignalsState.loaded;
    } else {
      _executeProfileResearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _sanitizeSearchInput(String input) {
    var cleaned = input;
    cleaned = cleaned.replaceAll(RegExp(r'\b\d{9,18}\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(\+?91[\-\s]?)?[6789]\d{9}\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b[\w\.\-]+@[\w\-]+\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[₹$€£]\s*[\d,]+(\.\d{1,2})?'), '');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _buildProfileDerivedQuery() {
    final profile = widget.merchantProfile;
    if (profile == null) {
      return 'wholesale commodity inflation retail kirana India';
    }

    final queryParts = <String>[];

    // Priority 1: Main procurement commodities
    if (profile.mainProcurementCategories.isNotEmpty &&
        profile.mainProcurementCategories != 'Grains, Spices, Packaged Goods') {
      queryParts
          .add(profile.mainProcurementCategories.split(',').take(2).join(' '));
    } else {
      queryParts.add('wholesale grocery commodities');
    }

    // Priority 2: Category or business model
    if (profile.businessCategory.isNotEmpty) {
      queryParts.add(profile.businessCategory.contains('Kirana')
          ? 'kirana retail'
          : profile.businessCategory);
    }

    // Priority 3: Geography
    if (profile.city.isNotEmpty && profile.city != 'Pune') {
      queryParts.add(profile.city);
    } else if (profile.state.isNotEmpty) {
      queryParts.add(profile.state);
    } else {
      queryParts.add('India');
    }

    return queryParts.join(' ').trim();
  }

  Future<void> _executeProfileResearch() async {
    final query = _buildProfileDerivedQuery();
    await _search(query);
  }

  Future<void> _search(String query) async {
    final sanitized = _sanitizeSearchInput(query);
    setState(() {
      _state = MarketSignalsState.loading;
      _errorMessage = null;
      _activeQuery = sanitized;
    });

    try {
      final profile = widget.merchantProfile;
      final results = await widget.onFetchSignals(
        query: sanitized.isNotEmpty ? sanitized : null,
        category: profile?.businessCategory,
        businessType: profile?.businessType,
        city: profile?.city,
        state: profile?.state,
        engine: _selectedEngine,
      );
      if (mounted) {
        setState(() {
          _signals = results;
          _state = results.isEmpty
              ? MarketSignalsState.empty
              : MarketSignalsState.loaded;
        });
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        MarketSignalsState errState = MarketSignalsState.error;
        if (errStr.contains('socket') ||
            errStr.contains('network') ||
            errStr.contains('connection') ||
            errStr.contains('unavailable') ||
            errStr.contains('timed out')) {
          errState = MarketSignalsState.networkError;
        } else if (errStr.contains('serpapi') ||
            errStr.contains('not configured') ||
            errStr.contains('key missing')) {
          errState = MarketSignalsState.providerNotConfigured;
        }

        setState(() {
          _state = errState;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.externalMarketSignals ?? 'External Market Signals'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          if (widget.onOpenLocalSuppliers != null)
            IconButton(
              icon: const Icon(Icons.location_on_outlined),
              tooltip: l10n?.localSuppliers ?? 'Local Suppliers Map',
              onPressed: widget.onOpenLocalSuppliers,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n?.runReconciliationPass ?? 'Refresh Signals',
            onPressed: () => _search(_activeQuery.isNotEmpty
                ? _activeQuery
                : _buildProfileDerivedQuery()),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (val) => _search(val),
                decoration: InputDecoration(
                  hintText: l10n?.searchMarketCommodities ??
                      'Search markets, commodities, suppliers or trends...',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.primaryPurple),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _executeProfileResearch();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primaryPurple, width: 1.5),
                  ),
                ),
              ),
            ),

            // Active Query / Profile Banner
            if (widget.merchantProfile != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.storefront,
                        size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Profile context: ${widget.merchantProfile!.businessCategory} • ${widget.merchantProfile!.city}, ${widget.merchantProfile!.state}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 6),
            _buildEngineFilterChips(),
            const SizedBox(height: 4),

            // Body Content based on explicit state
            Expanded(
              child: _buildBodyContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineFilterChips() {
    final engines = [
      {'label': 'All Markets', 'engine': 'google', 'icon': Icons.public},
      {'label': 'Wholesale Goods', 'engine': 'google_shopping', 'icon': Icons.shopping_bag_outlined},
      {'label': 'Commodity News', 'engine': 'google_news', 'icon': Icons.newspaper},
      {'label': 'Suppliers & Markets', 'engine': 'google_maps', 'icon': Icons.location_on_outlined},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: engines.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = engines[index];
          final engineKey = item['engine'] as String;
          final isSelected = _selectedEngine == engineKey;
          return ChoiceChip(
            avatar: Icon(
              item['icon'] as IconData,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            label: Text(
              item['label'] as String,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primaryPurple,
            backgroundColor: const Color(0xFFF1F5F9),
            onSelected: (selected) {
              if (selected && _selectedEngine != engineKey) {
                setState(() {
                  _selectedEngine = engineKey;
                });
                _search(_searchController.text.isNotEmpty
                    ? _searchController.text
                    : _buildProfileDerivedQuery());
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_state) {
      case MarketSignalsState.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Retrieving market signals via SerpApi...',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
        );

      case MarketSignalsState.providerNotConfigured:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.key_off, size: 56, color: Color(0xFF94A3B8)),
                const SizedBox(height: 16),
                const Text(
                  'Market Provider Key Missing',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'SERPAPI_API_KEY is not configured on the backend gateway. Set the provider credentials to enable live market intelligence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                  onPressed: () => _search(_activeQuery),
                ),
              ],
            ),
          ),
        );

      case MarketSignalsState.networkError:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 56, color: Color(0xFF94A3B8)),
                const SizedBox(height: 16),
                const Text(
                  'Network Unavailable',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unable to reach market intelligence server. Check internet connection and backend status.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  onPressed: () => _search(_activeQuery),
                ),
              ],
            ),
          ),
        );

      case MarketSignalsState.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.travel_explore,
                    size: 56, color: Color(0xFF64748B)),
                const SizedBox(height: 16),
                const Text(
                  'No Relevant Market Signals Found',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  _activeQuery.isNotEmpty
                      ? 'No verified results returned for query "$_activeQuery". Try searching specific commodities (e.g. "Wheat prices", "Turmeric market", "FMCG wholesale").'
                      : 'No external market events currently match your declared business profile.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset To Profile Query'),
                  onPressed: _executeProfileResearch,
                ),
              ],
            ),
          ),
        );

      case MarketSignalsState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Market Research Request Failed',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ??
                      'An error occurred while retrieving external market intelligence.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Request'),
                  onPressed: () => _search(_activeQuery),
                ),
              ],
            ),
          ),
        );

      case MarketSignalsState.loaded:
      case MarketSignalsState.initial:
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _signals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _signals[index];
            final ev = item.marketEvent;
            final src = ev?.source;

            String relevanceReason = item.explanation ??
                'Relevant to procurement costs and inventory planning.';
            if (widget.merchantProfile != null &&
                widget.merchantProfile!.mainProcurementCategories.isNotEmpty) {
              relevanceReason =
                  'Relevant because your business purchases ${widget.merchantProfile!.mainProcurementCategories.toLowerCase()}.';
            }

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: InkWell(
                onTap: () => widget.onSignalTap(item),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(builder: (context) {
                            IconData badgeIcon = Icons.search;
                            Color iconColor = const Color(0xFF2563EB);
                            Color bgColor = const Color(0xFFEFF6FF);

                            final eng = ev?.engine ?? src?.engine ?? '';
                            if (eng == 'google_shopping' || ev?.price != null) {
                              badgeIcon = Icons.shopping_bag_outlined;
                              iconColor = const Color(0xFF16A34A);
                              bgColor = const Color(0xFFDCFCE7);
                            } else if (eng == 'google_news') {
                              badgeIcon = Icons.newspaper;
                              iconColor = const Color(0xFFD97706);
                              bgColor = const Color(0xFFFEF3C7);
                            } else if (eng == 'google_maps') {
                              badgeIcon = Icons.location_on_outlined;
                              iconColor = const Color(0xFF9333EA);
                              bgColor = const Color(0xFFF3E8FF);
                            }

                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(badgeIcon, color: iconColor, size: 20),
                            );
                          }),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ev?.title ?? 'External Market Signal',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                if (src != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${src.sourceName} • ${src.providerName}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Builder(builder: (context) {
                                    final eng = ev?.engine ?? src.engine ?? '';
                                    String label = 'Discovered Business • Unverified Supplier';
                                    Color labelColor = const Color(0xFF1D4ED8);
                                    if (eng == 'google_shopping' || ev?.price != null) {
                                      label = 'Observed Listing Price • Not Trade Quote';
                                      labelColor = const Color(0xFF15803D);
                                    } else if (eng == 'google_news') {
                                      label = 'External News Report';
                                      labelColor = const Color(0xFFB45309);
                                    } else if (eng == 'google_maps') {
                                      label = 'Local Market Location';
                                      labelColor = const Color(0xFF7E22CE);
                                    }
                                    return Text(
                                      label,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: labelColor),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.relevanceStatus == 'POTENTIALLY_RELEVANT'
                                  ? 'POTENTIALLY RELEVANT'
                                  : 'MORE CONTEXT',
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0369A1)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ev?.summary ??
                            'Market signal observed from external sources.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            height: 1.4),
                      ),
                      if (ev?.price != null || ev?.rating != null || ev?.location != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (ev?.price != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ev!.price!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                              ),
                            if (ev?.rating != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 12, color: Color(0xFFD97706)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${ev!.rating}${ev.reviews != null ? ' (${ev.reviews})' : ''}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (ev?.location != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        ev!.location!,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: AppColors.primaryPurple),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                relevanceReason,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
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
}
