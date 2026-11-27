import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_report_repository.dart';
import 'generated_report_model.dart';
import 'local_financial_intelligence_engine.dart';
import '../../onboarding/data/local_business_profile_repository.dart';

final localReportGeneratorServiceProvider = Provider((ref) => LocalReportGeneratorService(
      reportRepository: ref.watch(localReportRepositoryProvider),
      businessProfileRepository: ref.watch(localBusinessProfileRepositoryProvider),
    ));

class LocalReportGeneratorService {
  final LocalReportRepository _reportRepo;
  final LocalBusinessProfileRepository _profileRepo;
  final LocalFinancialIntelligenceEngine _finEngine;

  LocalReportGeneratorService({
    required LocalReportRepository reportRepository,
    required LocalBusinessProfileRepository businessProfileRepository,
    LocalFinancialIntelligenceEngine? finEngine,
  })  : _reportRepo = reportRepository,
        _profileRepo = businessProfileRepository,
        _finEngine = finEngine ?? LocalFinancialIntelligenceEngine();

  /// Generates a deterministic financial report from local ledger data in the chosen reportLanguage.
  Future<GeneratedReportModel> generateReport({
    required String merchantId,
    required String reportType,
    required String reportLanguage, // 'en', 'hi', or 'mr'
    String? customTitle,
  }) async {
    final pos = await _finEngine.calculatePosition(merchantId: merchantId);
    final profile = await _profileRepo.getProfile(merchantId: merchantId);

    final netRupees = (pos.netCashMovementPaise / 100.0).toStringAsFixed(2);
    final inflowRupees = (pos.totalInflowsPaise / 100.0).toStringAsFixed(2);
    final outflowRupees = (pos.totalOutflowsPaise / 100.0).toStringAsFixed(2);
    final recRupees = (pos.totalReceivablesPaise / 100.0).toStringAsFixed(2);

    String defaultTitle;
    String summary;

    if (reportType == 'CASH_FLOW_HEALTH') {
      defaultTitle = reportLanguage == 'hi'
          ? 'रोकड़ प्रवाह स्वास्थ्य रिपोर्ट'
          : (reportLanguage == 'mr' ? 'रोख प्रवाह आरोग्य अहवाल' : 'Cash Flow Health Report');
      summary = reportLanguage == 'hi'
          ? 'कुल आवक ₹$inflowRupees और जावक ₹$outflowRupees। शुद्ध नकदी गति ₹$netRupees।'
          : (reportLanguage == 'mr'
              ? 'एकूण आवक ₹$inflowRupees आणि जावक ₹$outflowRupees. निव्वळ रोख हालचाल ₹$netRupees.'
              : 'Total inflows ₹$inflowRupees and outflows ₹$outflowRupees. Net cash movement ₹$netRupees.');
    } else if (reportType == 'CREDIT_RECOVERY') {
      defaultTitle = reportLanguage == 'hi'
          ? 'उधारी वसूली एवं प्राप्य रिपोर्ट'
          : (reportLanguage == 'mr' ? 'येणे वसुली आणि बाकी अहवाल' : 'Credit Recovery & Receivables Report');
      summary = reportLanguage == 'hi'
          ? 'कुल प्राप्य ₹$recRupees बकाया है। ${pos.openPromiseCount} सक्रिय भुगतान वादे दर्ज हैं।'
          : (reportLanguage == 'mr'
              ? 'एकूण येणे ₹$recRupees बाकी आहे. ${pos.openPromiseCount} सक्रिय देयक वचने नोंदवली आहेत.'
              : 'Total receivables balance of ₹$recRupees pending. ${pos.openPromiseCount} active payment promises recorded.');
    } else {
      defaultTitle = reportLanguage == 'hi'
          ? 'दैनिक वित्तीय सारांश'
          : (reportLanguage == 'mr' ? 'दैनिक आर्थिक सारांश' : 'Daily Financial Digest');
      summary = reportLanguage == 'hi'
          ? '${profile.businessName.isNotEmpty ? profile.businessName : "व्यापार"} का दैनिक बहीखाता सारांश। कुल लेनदेन: ${pos.transactionCount}।'
          : (reportLanguage == 'mr'
              ? '${profile.businessName.isNotEmpty ? profile.businessName : "व्यापार"} चा दैनिक खातेवही सारांश. एकूण व्यवहार: ${pos.transactionCount}.'
              : 'Daily financial briefing for ${profile.businessName.isNotEmpty ? profile.businessName : "Business"}. Total transactions: ${pos.transactionCount}.');
    }

    final computedMetrics = <String, dynamic>{
      'total_inflows_paise': pos.totalInflowsPaise,
      'total_outflows_paise': pos.totalOutflowsPaise,
      'net_cash_movement_paise': pos.netCashMovementPaise,
      'total_receivables_paise': pos.totalReceivablesPaise,
      'total_overdue_receivables_paise': pos.totalOverdueReceivablesPaise,
      'total_payables_paise': pos.totalPayablesPaise,
      'open_promise_count': pos.openPromiseCount,
      'overdue_promise_count': pos.overduePromiseCount,
      'counterparty_count': pos.counterpartyCount,
      'transaction_count': pos.transactionCount,
      'total_inflows_rupees': pos.totalInflowsPaise / 100,
      'total_outflows_rupees': pos.totalOutflowsPaise / 100,
      'net_cash_movement_rupees': pos.netCashMovementPaise / 100,
      'total_receivables_rupees': pos.totalReceivablesPaise / 100,
      'total_overdue_receivables_rupees': pos.totalOverdueReceivablesPaise / 100,
      'total_payables_rupees': pos.totalPayablesPaise / 100,
    };

    final payload = <String, dynamic>{
      'metrics': computedMetrics,
      'why_it_matters': summary,
      'key_facts': [
        {'label': 'Net Cash', 'value': '₹$netRupees', 'source_reference': 'canonical_transactions'},
        {'label': 'Total Inflows', 'value': '₹$inflowRupees', 'source_reference': 'canonical_transactions'},
        {'label': 'Total Outflows', 'value': '₹$outflowRupees', 'source_reference': 'canonical_transactions'},
        {'label': 'Receivables', 'value': '₹$recRupees', 'source_reference': 'receivables'},
      ],
      'suggested_actions': [
        'Review open counterparty promises and overdue balances',
        'Verify reconciled transactions against statements',
      ],
      'limitations': [
        'Calculated strictly from local SQLite ledger data without external estimations.',
      ],
      'source_references': [
        {'entity_type': 'canonical_transactions', 'entity_id': merchantId, 'label': 'Device Ledger'},
      ],
    };

    final report = GeneratedReportModel(
      id: const Uuid().v4(),
      merchantId: merchantId,
      reportType: reportType,
      title: customTitle ?? defaultTitle,
      summary: summary,
      language: reportLanguage,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
    );

    await _reportRepo.saveReport(report);
    return report;
  }
}
