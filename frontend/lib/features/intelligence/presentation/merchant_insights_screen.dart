import 'package:flutter/material.dart';
import '../data/intelligence_repository.dart';
import '../domain/merchant_insight_model.dart';
import 'merchant_insight_card.dart';

class MerchantInsightsScreen extends StatefulWidget {
  final IntelligenceRepository? repository;

  const MerchantInsightsScreen({
    super.key,
    this.repository,
  });

  @override
  State<MerchantInsightsScreen> createState() => _MerchantInsightsScreenState();
}

class _MerchantInsightsScreenState extends State<MerchantInsightsScreen> {
  late final IntelligenceRepository _repo;
  bool _isLoading = true;
  String? _errorMessage;
  List<MerchantInsightItemModel> _insights = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? IntelligenceRepository();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _repo.listInsights();
      if (mounted) {
        setState(() {
          _insights = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load financial insights. Please retry.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInsights,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInsights,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_insights.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.insights, size: 54, color: Color(0xFF94A3B8)),
              SizedBox(height: 16),
              Text(
                'No Financial Insights Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 8),
              Text(
                'MeraVyapar will surface important events as your financial activity is analyzed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _insights.length,
        itemBuilder: (context, index) {
          final insight = _insights[index];
          return MerchantInsightCard(insight: insight);
        },
      ),
    );
  }
}
