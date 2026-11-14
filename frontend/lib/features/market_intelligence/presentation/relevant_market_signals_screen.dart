import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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
  final Future<List<MerchantMarketRelevanceModel>> Function({String? query}) onFetchSignals;
  final MerchantBusinessProfile? merchantProfile;
  final VoidCallback? onBack;

  const RelevantMarketSignalsScreen({
    super.key,
    required this.initialSignals,
    required this.onSignalTap,
    required this.onFetchSignals,
    this.merchantProfile,
    this.onBack,
  });

  @override
  State<RelevantMarketSignalsScreen> createState() => _RelevantMarketSignalsScreenState();
}

class _RelevantMarketSignalsScreenState extends State<RelevantMarketSignalsScreen> {
  late TextEditingController _searchController;
  List<MerchantMarketRelevanceModel> _signals = [];
  MarketSignalsState _state = MarketSignalsState.initial;
  String? _errorMessage;
  String _activeQuery = '';

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

  String _buildProfileDerivedQuery() {
    final profile = widget.merchantProfile;
    if (profile == null) {
      return 'wholesale commodity inflation retail kirana India';
    }

    final queryParts = <String>[];

    // Priority 1: Main procurement commodities
    if (profile.mainProcurementCategories.isNotEmpty &&
        profile.mainProcurementCategories != 'Grains, Spices, Packaged Goods') {
      queryParts.add(profile.mainProcurementCategories.split(',').take(2).join(' '));
    } else {
      queryParts.add('wholesale grocery commodities');
    }

    // Priority 2: Category or business model
    if (profile.businessCategory.isNotEmpty) {
      queryParts.add(profile.businessCategory.contains('Kirana') ? 'kirana retail' : profile.businessCategory);
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
    final trimmed = query.trim();
    setState(() {
      _state = MarketSignalsState.loading;
      _errorMessage = null;
      _activeQuery = trimmed;
    });

    try {
      final results = await widget.onFetchSignals(query: trimmed.isNotEmpty ? trimmed : null);
      if (mounted) {
        setState(() {
          _signals = results;
          _state = results.isEmpty ? MarketSignalsState.empty : MarketSignalsState.loaded;
        });
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        MarketSignalsState errState = MarketSignalsState.error;
        if (errStr.contains('socket') || errStr.contains('network') || errStr.contains('connection')) {
          errState = MarketSignalsState.networkError;
        } else if (errStr.contains('serpapi') || errStr.contains('not configured') || errStr.contains('key missing')) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('External Market Signals'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Signals',
            onPressed: () => _search(_activeQuery.isNotEmpty ? _activeQuery : _buildProfileDerivedQuery()),
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
                onSubmitted: (val) => _search(val),
                decoration: InputDecoration(
                  hintText: 'Search markets, commodities, suppliers or trends...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primaryPurple),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                  ),
                ),
              ),
            ),

            // Active Query / Profile Banner
            if (widget.merchantProfile != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Profile context: ${widget.merchantProfile!.businessCategory} • ${widget.merchantProfile!.city}, ${widget.merchantProfile!.state}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

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

  Widget _buildBodyContent() {
    switch (_state) {
      case MarketSignalsState.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Retrieving market signals via SerpApi...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'SERPAPI_API_KEY is not configured on the backend gateway. Set the provider credentials to enable live market intelligence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unable to reach market intelligence server. Check internet connection and backend status.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
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
                const Icon(Icons.travel_explore, size: 56, color: Color(0xFF64748B)),
                const SizedBox(height: 16),
                const Text(
                  'No Relevant Market Signals Found',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  _activeQuery.isNotEmpty
                      ? 'No verified results returned for query "$_activeQuery". Try searching specific commodities (e.g. "Wheat prices", "Turmeric market", "FMCG wholesale").'
                      : 'No external market events currently match your declared business profile.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
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
                const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Market Research Request Failed',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'An error occurred while retrieving external market intelligence.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
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

            String relevanceReason = item.explanation ?? 'Relevant to procurement costs and inventory planning.';
            if (widget.merchantProfile != null && widget.merchantProfile!.mainProcurementCategories.isNotEmpty) {
              relevanceReason = 'Relevant because your business purchases ${widget.merchantProfile!.mainProcurementCategories.toLowerCase()}.';
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.public, color: Color(0xFF0284C7), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ev?.title ?? 'External Market Signal',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                if (src != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${src.sourceName} • ${src.providerName}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.relevanceStatus == 'POTENTIALLY_RELEVANT' ? 'POTENTIALLY RELEVANT' : 'MORE CONTEXT',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ev?.summary ?? 'Market signal observed from external sources.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: AppColors.primaryPurple),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                relevanceReason,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
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
