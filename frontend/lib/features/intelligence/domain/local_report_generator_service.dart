import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/intelligence_repository.dart';
import '../data/local_report_repository.dart';
import 'generated_report_model.dart';
import 'local_financial_intelligence_engine.dart';
import '../../onboarding/data/local_business_profile_repository.dart';

final localReportGeneratorServiceProvider = Provider((ref) => LocalReportGeneratorService(
      intelligenceRepository: ref.watch(intelligenceRepositoryProvider),
      reportRepository: ref.watch(localReportRepositoryProvider),
      businessProfileRepository: ref.watch(localBusinessProfileRepositoryProvider),
    ));

final intelligenceRepositoryProvider = Provider((ref) => IntelligenceRepository());

class LocalReportGeneratorService {
  final IntelligenceRepository _intelligenceRepo;
  final LocalReportRepository _reportRepo;
  final LocalBusinessProfileRepository _profileRepo;
  final LocalFinancialIntelligenceEngine _finEngine;

  LocalReportGeneratorService({
    required IntelligenceRepository intelligenceRepository,
    required LocalReportRepository reportRepository,
    required LocalBusinessProfileRepository businessProfileRepository,
    LocalFinancialIntelligenceEngine? finEngine,
  })  : _intelligenceRepo = intelligenceRepository,
        _reportRepo = reportRepository,
        _profileRepo = businessProfileRepository,
        _finEngine = finEngine ?? LocalFinancialIntelligenceEngine();

  /// Generates an intelligent, deterministic financial report in the chosen reportLanguage (independent of app UI language).
  Future<GeneratedReportModel> generateReport({
    required String merchantId,
    required String reportType,
    required String reportLanguage, // 'en', 'hi', or 'mr'
    String? customTitle,
  }) async {
    final pos = await _finEngine.calculatePosition(merchantId: merchantId);
    final profile = await _profileRepo.getProfile(merchantId: merchantId);

    // Build deterministic sanitized context package
    final sanitizedContext = <String, dynamic>{
      'business_name': profile.businessName,
      'business_type': profile.businessType,
      'business_category': profile.businessCategory,
      'city': profile.city,
      'state': profile.state,
      'computed_metrics': {
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
      },
    };

    String promptQuestion;
    String defaultTitle;

    if (reportType == 'CASH_FLOW_HEALTH') {
      promptQuestion = 'Analyze cash flow health, net liquidity movement, and upcoming obligations.';
      defaultTitle = reportLanguage == 'hi'
          ? 'रोकड़ प्रवाह स्वास्थ्य रिपोर्ट'
          : (reportLanguage == 'mr' ? 'रोख प्रवाह आरोग्य अहवाल' : 'Cash Flow Health Report');
    } else if (reportType == 'CREDIT_RECOVERY') {
      promptQuestion = 'Analyze pending and overdue receivables, counterparty risks, and cash recovery actions.';
      defaultTitle = reportLanguage == 'hi'
          ? 'उधारी वसूली एवं प्राप्य रिपोर्ट'
          : (reportLanguage == 'mr' ? 'येणे वसुली आणि बाकी अहवाल' : 'Credit Recovery & Receivables Report');
    } else {
      // Default: DAILY_FINANCIAL_DIGEST
      promptQuestion = 'Generate executive daily financial briefing with key balance facts and recommended next steps.';
      defaultTitle = reportLanguage == 'hi'
          ? 'दैनिक वित्तीय सारांश'
          : (reportLanguage == 'mr' ? 'दैनिक आर्थिक सारांश' : 'Daily Financial Digest');
    }

    final queryRes = await _intelligenceRepo.queryIntelligence(
      question: promptQuestion,
      sanitizedContext: sanitizedContext,
      targetLanguage: reportLanguage,
    );

    final insight = queryRes.insight;
    final summary = insight?.summary ??
        (reportLanguage == 'hi'
            ? 'निजी बहीखाता डेटा से तैयार की गई वित्तीय स्थिति।'
            : (reportLanguage == 'mr'
                ? 'खाजगी खातेवही डेटावरून तयार केलेली आर्थिक स्थिती.'
                : 'Deterministic financial position generated from private ledger records.'));

    final payload = <String, dynamic>{
      'metrics': sanitizedContext['computed_metrics'],
      'why_it_matters': insight?.whyItMatters,
      'key_facts': insight?.keyFacts.map((kf) => {
            'label': kf.label,
            'value': kf.value,
            'source_reference': kf.sourceReference,
          }).toList() ?? [],
      'suggested_actions': insight?.suggestedActions ?? [],
      'limitations': insight?.limitations ?? [],
      'source_references': insight?.sourceReferences.map((sr) => {
            'entity_type': sr.entityType,
            'entity_id': sr.entityId,
            'label': sr.label,
          }).toList() ?? [],
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
