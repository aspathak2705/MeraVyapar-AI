import 'dart:async';
import '../../../core/money/money.dart';
import '../data/local_canonical_transaction_repository.dart';

class DemoSeedResult {
  final int totalInserted;
  final int totalExisting;
  final int totalRecords;
  final int totalInflowsPaise;
  final int totalOutflowsPaise;
  final int netPaise;
  final int genuineRecordsCount;
  final String sampleMerchantName;

  const DemoSeedResult({
    required this.totalInserted,
    required this.totalExisting,
    required this.totalRecords,
    required this.totalInflowsPaise,
    required this.totalOutflowsPaise,
    required this.netPaise,
    required this.genuineRecordsCount,
    required this.sampleMerchantName,
  });
}

class DemoTxBlueprint {
  final int dayOffset; // 0 = today, 29 = 29 days ago
  final int hour;
  final int minute;
  final String transactionType; // 'CREDIT' or 'DEBIT'
  final int amountPaise;
  final String paymentMode; // 'UPI', 'CASH', 'BANK_TRANSFER', 'CARD'
  final String counterpartyName;
  final String description;
  final String reference;

  const DemoTxBlueprint({
    required this.dayOffset,
    required this.hour,
    required this.minute,
    required this.transactionType,
    required this.amountPaise,
    required this.paymentMode,
    required this.counterpartyName,
    required this.description,
    required this.reference,
  });
}

/// Dedicated 30-Day Synthetic Financial Demo Dataset for MeraVyapar AI.
/// Provides realistic, explainable transactions for sample merchant (Ramesh Store).
/// Amounts are stored strictly as integer paise. Real merchant data remains untouched.
class SyntheticDemoDatasetService {
  static const String sampleMerchant = 'Ramesh Store';
  static const String demoSourceType = 'SYNTHETIC_DEMO';

  /// Deterministic 30-day transaction blueprints covering sales, suppliers,
  /// rent, utilities, transport, and operating expenses.
  static final List<DemoTxBlueprint> blueprints = [
    // --- Day 29 (29 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 29,
      hour: 10,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 345000, // ₹3,450.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Morning counter sales via PhonePe QR',
      reference: 'UPI/29011015/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 29,
      hour: 16,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 182000, // ₹1,820.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Retail cash sales - grains & provisions',
      reference: 'CASH/29011630/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 29,
      hour: 17,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 12000, // ₹120.00
      paymentMode: 'CASH',
      counterpartyName: 'Chai Point',
      description: 'Store daily tea and refreshments',
      reference: 'CASH/29011700/DEMO',
    ),

    // --- Day 28 (28 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 28,
      hour: 10,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 1500000, // ₹15,000.00
      paymentMode: 'BANK_TRANSFER',
      counterpartyName: 'Suresh Agarwal (Landlord)',
      description: 'Shop monthly rent payment',
      reference: 'NEFT/28011000/RENT',
    ),
    const DemoTxBlueprint(
      dayOffset: 28,
      hour: 11,
      minute: 15,
      transactionType: 'DEBIT',
      amountPaise: 1850000, // ₹18,500.00
      paymentMode: 'BANK_TRANSFER',
      counterpartyName: 'Kisan Wholesale Mandi',
      description: 'Wholesale grains, pulses & wheat restock',
      reference: 'RTGS/28011115/MANDI',
    ),
    const DemoTxBlueprint(
      dayOffset: 28,
      hour: 12,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 75000, // ₹750.00
      paymentMode: 'CASH',
      counterpartyName: 'City Tempo Logistics',
      description: 'Tempo freight - Mandi consignment delivery',
      reference: 'CASH/28011200/FRT',
    ),
    const DemoTxBlueprint(
      dayOffset: 28,
      hour: 14,
      minute: 20,
      transactionType: 'CREDIT',
      amountPaise: 250000, // ₹2,500.00
      paymentMode: 'UPI',
      counterpartyName: 'Sharma Ji',
      description: 'Customer monthly khata clearance',
      reference: 'UPI/28011420/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 28,
      hour: 19,
      minute: 45,
      transactionType: 'CREDIT',
      amountPaise: 415000, // ₹4,150.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Evening counter cash reconciliation',
      reference: 'CASH/28011945/DEMO',
    ),

    // --- Day 27 (27 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 27,
      hour: 11,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 530000, // ₹5,300.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Daily QR counter sales',
      reference: 'UPI/27011130/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 27,
      hour: 16,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 210000, // ₹2,100.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Retail afternoon sales',
      reference: 'CASH/27011600/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 27,
      hour: 20,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 300000, // ₹3,000.00
      paymentMode: 'CASH',
      counterpartyName: 'Raju (Store Assistant)',
      description: 'Store assistant weekly wages',
      reference: 'CASH/27012000/WAGE',
    ),

    // --- Day 26 (26 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 26,
      hour: 11,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 480000, // ₹4,800.00
      paymentMode: 'BANK_TRANSFER',
      counterpartyName: 'Verma Ji',
      description: 'Customer credit payment received via IMPS',
      reference: 'IMPS/26011100/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 26,
      hour: 14,
      minute: 30,
      transactionType: 'DEBIT',
      amountPaise: 85000, // ₹850.00
      paymentMode: 'CASH',
      counterpartyName: 'Om Packaging Suppliers',
      description: 'Biodegradable carry bags and paper pouches',
      reference: 'CASH/26011430/BAGS',
    ),
    const DemoTxBlueprint(
      dayOffset: 26,
      hour: 18,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 375000, // ₹3,750.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Evening counter sales',
      reference: 'UPI/26011815/DEMO',
    ),

    // --- Day 25 (25 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 25,
      hour: 9,
      minute: 45,
      transactionType: 'DEBIT',
      amountPaise: 645000, // ₹6,450.00
      paymentMode: 'UPI',
      counterpartyName: 'Amul Distributor',
      description: 'Weekly milk, curd, paneer & butter supplies',
      reference: 'UPI/25010945/AMUL',
    ),
    const DemoTxBlueprint(
      dayOffset: 25,
      hour: 17,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 620000, // ₹6,200.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Store provisions sales',
      reference: 'UPI/25011730/DEMO',
    ),

    // --- Day 24 (24 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 24,
      hour: 12,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 195000, // ₹1,950.00
      paymentMode: 'UPI',
      counterpartyName: 'Anita Devi',
      description: 'Monthly grocery bill clearance',
      reference: 'UPI/24011215/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 24,
      hour: 16,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 15000, // ₹150.00
      paymentMode: 'CASH',
      counterpartyName: 'Chai Point',
      description: 'Tea and evening snacks for customer meeting',
      reference: 'CASH/24011600/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 24,
      hour: 19,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 388000, // ₹3,880.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Daily UPI collection',
      reference: 'UPI/24011900/DEMO',
    ),

    // --- Day 23 (23 days ago - Weekend Peak) ---
    const DemoTxBlueprint(
      dayOffset: 23,
      hour: 13,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 1245000, // ₹12,450.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Sunday peak retail sales collection',
      reference: 'UPI/23011330/PEAK',
    ),
    const DemoTxBlueprint(
      dayOffset: 23,
      hour: 20,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 420000, // ₹4,200.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Sunday cash drawer tally',
      reference: 'CASH/23012030/DEMO',
    ),

    // --- Day 22 (22 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 22,
      hour: 10,
      minute: 30,
      transactionType: 'DEBIT',
      amountPaise: 1420000, // ₹14,200.00
      paymentMode: 'BANK_TRANSFER',
      counterpartyName: 'HUL Agency',
      description: 'FMCG personal care and detergent stock consignment',
      reference: 'NEFT/22011030/HUL',
    ),
    const DemoTxBlueprint(
      dayOffset: 22,
      hour: 15,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 550000, // ₹5,500.00
      paymentMode: 'UPI',
      counterpartyName: 'Gupta Traders',
      description: 'Partial order payment settlement',
      reference: 'UPI/22011500/GUPTA',
    ),
    const DemoTxBlueprint(
      dayOffset: 22,
      hour: 18,
      minute: 45,
      transactionType: 'CREDIT',
      amountPaise: 360000, // ₹3,600.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Daily cash collections',
      reference: 'CASH/22011845/DEMO',
    ),

    // --- Day 21 (21 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 21,
      hour: 11,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 45000, // ₹450.00
      paymentMode: 'CASH',
      counterpartyName: 'Local Freight Auto',
      description: 'Auto goods delivery - flour consignment',
      reference: 'CASH/21011100/FRT',
    ),
    const DemoTxBlueprint(
      dayOffset: 21,
      hour: 16,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 475000, // ₹4,750.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Counter QR sales',
      reference: 'UPI/21011615/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 21,
      hour: 19,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 165000, // ₹1,650.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Retail cash sales',
      reference: 'CASH/21011930/DEMO',
    ),

    // --- Day 20 (20 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 20,
      hour: 10,
      minute: 15,
      transactionType: 'DEBIT',
      amountPaise: 385000, // ₹3,850.00
      paymentMode: 'UPI',
      counterpartyName: 'MSEDCL State Power',
      description: 'Shop commercial electricity bill payment',
      reference: 'UPI/20011015/POWER',
    ),
    const DemoTxBlueprint(
      dayOffset: 20,
      hour: 13,
      minute: 45,
      transactionType: 'CREDIT',
      amountPaise: 320000, // ₹3,200.00
      paymentMode: 'UPI',
      counterpartyName: 'Sunil Dairy Customer',
      description: 'Wholesale dairy supply payment',
      reference: 'UPI/20011345/SUNIL',
    ),
    const DemoTxBlueprint(
      dayOffset: 20,
      hour: 18,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 510000, // ₹5,100.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Daily QR sales',
      reference: 'UPI/20011800/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 20,
      hour: 20,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 300000, // ₹3,000.00
      paymentMode: 'CASH',
      counterpartyName: 'Raju (Store Assistant)',
      description: 'Store assistant weekly wages',
      reference: 'CASH/20012000/WAGE',
    ),

    // --- Day 19 (19 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 19,
      hour: 11,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 285000, // ₹2,850.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Morning counter sales',
      reference: 'UPI/19011130/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 19,
      hour: 15,
      minute: 15,
      transactionType: 'DEBIT',
      amountPaise: 11000, // ₹110.00
      paymentMode: 'CASH',
      counterpartyName: 'Chai Point',
      description: 'Daily staff tea and water',
      reference: 'CASH/19011515/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 19,
      hour: 19,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 340000, // ₹3,400.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Evening cash sales',
      reference: 'CASH/19011900/DEMO',
    ),

    // --- Day 18 (18 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 18,
      hour: 10,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 1180000, // ₹11,800.00
      paymentMode: 'BANK_TRANSFER',
      counterpartyName: 'Kisan Mandi Traders',
      description: 'Toor dal, moong dal & chana wholesale purchase',
      reference: 'RTGS/18011000/DAL',
    ),
    const DemoTxBlueprint(
      dayOffset: 18,
      hour: 11,
      minute: 45,
      transactionType: 'DEBIT',
      amountPaise: 99900, // ₹999.00
      paymentMode: 'UPI',
      counterpartyName: 'Jio Fibre',
      description: 'Store commercial broadband internet bill',
      reference: 'UPI/18011145/WIFI',
    ),
    const DemoTxBlueprint(
      dayOffset: 18,
      hour: 14,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 670000, // ₹6,700.00
      paymentMode: 'BANK_TRANSFER',
      counterpartyName: 'Mehta Ji',
      description: 'Provision bulk order settlement',
      reference: 'NEFT/18011430/MEHTA',
    ),
    const DemoTxBlueprint(
      dayOffset: 18,
      hour: 18,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 410000, // ₹4,100.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Evening counter QR collection',
      reference: 'UPI/18011830/DEMO',
    ),

    // --- Day 17 (17 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 17,
      hour: 12,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 495000, // ₹4,950.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Counter retail sales',
      reference: 'UPI/17011200/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 17,
      hour: 17,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 230000, // ₹2,300.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Cash drawer collection',
      reference: 'CASH/17011730/DEMO',
    ),

    // --- Day 16 (16 days ago - Weekend Peak) ---
    const DemoTxBlueprint(
      dayOffset: 16,
      hour: 13,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 1480000, // ₹14,800.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Sunday festival crowd sales record',
      reference: 'UPI/16011300/FESTIVAL',
    ),
    const DemoTxBlueprint(
      dayOffset: 16,
      hour: 20,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 515000, // ₹5,150.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Sunday cash drawer tally',
      reference: 'CASH/16012015/DEMO',
    ),

    // --- Day 15 (15 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 15,
      hour: 10,
      minute: 30,
      transactionType: 'DEBIT',
      amountPaise: 940000, // ₹9,400.00
      paymentMode: 'UPI',
      counterpartyName: 'Mahavir Oil Depot',
      description: 'Fortune sunflower oil & mustard oil cartons',
      reference: 'UPI/15011030/OIL',
    ),
    const DemoTxBlueprint(
      dayOffset: 15,
      hour: 14,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 825000, // ₹8,250.00
      paymentMode: 'UPI',
      counterpartyName: 'Sharma Ji',
      description: 'Mid-month settlement for provision supply',
      reference: 'UPI/15011400/SHARMA',
    ),
    const DemoTxBlueprint(
      dayOffset: 15,
      hour: 16,
      minute: 30,
      transactionType: 'DEBIT',
      amountPaise: 14000, // ₹140.00
      paymentMode: 'CASH',
      counterpartyName: 'Chai Point',
      description: 'Tea and biscuits for distributor rep meeting',
      reference: 'CASH/15011630/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 15,
      hour: 19,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 430000, // ₹4,300.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Evening counter sales',
      reference: 'UPI/15011900/DEMO',
    ),

    // --- Day 14 (14 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 14,
      hour: 11,
      minute: 15,
      transactionType: 'DEBIT',
      amountPaise: 38000, // ₹380.00
      paymentMode: 'UPI',
      counterpartyName: 'BlueDart Express',
      description: 'Courier charges - specialty organic spices delivery',
      reference: 'UPI/14011115/COURIER',
    ),
    const DemoTxBlueprint(
      dayOffset: 14,
      hour: 15,
      minute: 45,
      transactionType: 'CREDIT',
      amountPaise: 390000, // ₹3,900.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Daily counter retail sales',
      reference: 'UPI/14011545/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 14,
      hour: 18,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 175000, // ₹1,750.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Cash drawer evening total',
      reference: 'CASH/14011830/DEMO',
    ),

    // --- Day 13 (13 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 13,
      hour: 12,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 465000, // ₹4,650.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Afternoon QR collection',
      reference: 'UPI/13011200/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 13,
      hour: 17,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 320000, // ₹3,200.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Retail counter sales',
      reference: 'CASH/13011715/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 13,
      hour: 20,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 300000, // ₹3,000.00
      paymentMode: 'CASH',
      counterpartyName: 'Raju (Store Assistant)',
      description: 'Store assistant weekly wages',
      reference: 'CASH/13012000/WAGE',
    ),

    // --- Day 12 (12 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 12,
      hour: 10,
      minute: 30,
      transactionType: 'DEBIT',
      amountPaise: 45000, // ₹450.00
      paymentMode: 'CASH',
      counterpartyName: 'City Municipal Water',
      description: 'Commercial drinking water can supply',
      reference: 'CASH/12011030/WATER',
    ),
    const DemoTxBlueprint(
      dayOffset: 12,
      hour: 12,
      minute: 45,
      transactionType: 'DEBIT',
      amountPaise: 92000, // ₹920.00
      paymentMode: 'CASH',
      counterpartyName: 'Om Packaging Suppliers',
      description: 'Packaging tape, twine & paper bags',
      reference: 'CASH/12011245/PACK',
    ),
    const DemoTxBlueprint(
      dayOffset: 12,
      hour: 15,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 380000, // ₹3,800.00
      paymentMode: 'UPI',
      counterpartyName: 'Choudhary Ji',
      description: 'Customer grocery account payment',
      reference: 'UPI/12011500/CHOUDHARY',
    ),
    const DemoTxBlueprint(
      dayOffset: 12,
      hour: 19,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 510000, // ₹5,100.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Evening counter sales',
      reference: 'UPI/12011930/DEMO',
    ),

    // --- Day 11 (11 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 11,
      hour: 10,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 560000, // ₹5,600.00
      paymentMode: 'UPI',
      counterpartyName: 'Parle & Britannia Distributor',
      description: 'Biscuits, rusks & confectionery stock restock',
      reference: 'UPI/11011000/BISCUITS',
    ),
    const DemoTxBlueprint(
      dayOffset: 11,
      hour: 14,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 440000, // ₹4,400.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Daily retail counter',
      reference: 'UPI/11011415/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 11,
      hour: 18,
      minute: 45,
      transactionType: 'CREDIT',
      amountPaise: 205000, // ₹2,050.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Cash drawer settlement',
      reference: 'CASH/11011845/DEMO',
    ),

    // --- Day 10 (10 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 10,
      hour: 11,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 750000, // ₹7,500.00
      paymentMode: 'BANK_TRANSFER',
      counterpartyName: 'Vikas Provision Store',
      description: 'Inter-store wholesale supply settlement',
      reference: 'IMPS/10011130/VIKAS',
    ),
    const DemoTxBlueprint(
      dayOffset: 10,
      hour: 15,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 13000, // ₹130.00
      paymentMode: 'CASH',
      counterpartyName: 'Chai Point',
      description: 'Store tea & snacks',
      reference: 'CASH/10011500/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 10,
      hour: 19,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 485000, // ₹4,850.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Evening QR collection',
      reference: 'UPI/10011900/DEMO',
    ),

    // --- Day 9 (9 days ago - Weekend) ---
    const DemoTxBlueprint(
      dayOffset: 9,
      hour: 13,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 1160000, // ₹11,600.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Sunday grocery sales peak',
      reference: 'UPI/09011315/PEAK',
    ),
    const DemoTxBlueprint(
      dayOffset: 9,
      hour: 19,
      minute: 45,
      transactionType: 'CREDIT',
      amountPaise: 390000, // ₹3,900.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Sunday cash drawer collection',
      reference: 'CASH/09011945/DEMO',
    ),

    // --- Day 8 (8 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 8,
      hour: 11,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 375000, // ₹3,750.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Morning counter sales',
      reference: 'UPI/08011100/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 8,
      hour: 17,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 260000, // ₹2,600.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Evening cash sales',
      reference: 'CASH/08011730/DEMO',
    ),

    // --- Day 7 (7 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 7,
      hour: 10,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 820000, // ₹8,200.00
      paymentMode: 'BANK_TRANSFER',
      counterpartyName: 'Consumer Goods Agency',
      description: 'Soaps, detergents & kitchen cleaning supplies',
      reference: 'NEFT/07011000/SOAP',
    ),
    const DemoTxBlueprint(
      dayOffset: 7,
      hour: 11,
      minute: 30,
      transactionType: 'DEBIT',
      amountPaise: 120000, // ₹1,200.00
      paymentMode: 'UPI',
      counterpartyName: 'Indian Oil Petrol Pump',
      description: 'Delivery van diesel refuel',
      reference: 'UPI/07011130/FUEL',
    ),
    const DemoTxBlueprint(
      dayOffset: 7,
      hour: 14,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 420000, // ₹4,200.00
      paymentMode: 'UPI',
      counterpartyName: 'Sharma Ji',
      description: 'Weekly grocery khata payment',
      reference: 'UPI/07011430/SHARMA',
    ),
    const DemoTxBlueprint(
      dayOffset: 7,
      hour: 18,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 540000, // ₹5,400.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Evening QR collection',
      reference: 'UPI/07011815/DEMO',
    ),

    // --- Day 6 (6 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 6,
      hour: 12,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 485000, // ₹4,850.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Daily counter retail sales',
      reference: 'UPI/06011200/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 6,
      hour: 17,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 195000, // ₹1,950.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Retail cash collection',
      reference: 'CASH/06011700/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 6,
      hour: 20,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 300000, // ₹3,000.00
      paymentMode: 'CASH',
      counterpartyName: 'Raju (Store Assistant)',
      description: 'Store assistant weekly wages',
      reference: 'CASH/06012000/WAGE',
    ),

    // --- Day 5 (5 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 5,
      hour: 11,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 950000, // ₹9,500.00
      paymentMode: 'BANK_TRANSFER',
      counterpartyName: 'Tiwari Catering',
      description: 'Advance deposit for bulk wedding grocery order',
      reference: 'IMPS/05011115/TIWARI',
    ),
    const DemoTxBlueprint(
      dayOffset: 5,
      hour: 15,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 16000, // ₹160.00
      paymentMode: 'CASH',
      counterpartyName: 'Chai Point',
      description: 'Tea & biscuits for catering client discussion',
      reference: 'CASH/05011500/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 5,
      hour: 19,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 380000, // ₹3,800.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Evening counter QR collection',
      reference: 'UPI/05011900/DEMO',
    ),

    // --- Day 4 (4 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 4,
      hour: 12,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 520000, // ₹5,200.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Daily counter sales',
      reference: 'UPI/04011230/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 4,
      hour: 18,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 240000, // ₹2,400.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Afternoon cash drawer settlement',
      reference: 'CASH/04011800/DEMO',
    ),

    // --- Day 3 (3 days ago) ---
    const DemoTxBlueprint(
      dayOffset: 3,
      hour: 10,
      minute: 15,
      transactionType: 'DEBIT',
      amountPaise: 1650000, // ₹16,500.00
      paymentMode: 'BANK_TRANSFER',
      counterpartyName: 'Shree Ram Wholesale',
      description: 'Sugar bags (M30) & Basmati Rice (1121) consignment',
      reference: 'RTGS/03011015/SUGAR',
    ),
    const DemoTxBlueprint(
      dayOffset: 3,
      hour: 14,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 360000, // ₹3,600.00
      paymentMode: 'UPI',
      counterpartyName: 'Patel Ji',
      description: 'Monthly provision bill payment',
      reference: 'UPI/03011400/PATEL',
    ),
    const DemoTxBlueprint(
      dayOffset: 3,
      hour: 19,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 490000, // ₹4,900.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Evening UPI sales',
      reference: 'UPI/03011915/DEMO',
    ),

    // --- Day 2 (2 days ago - Weekend Peak) ---
    const DemoTxBlueprint(
      dayOffset: 2,
      hour: 11,
      minute: 0,
      transactionType: 'DEBIT',
      amountPaise: 65000, // ₹650.00
      paymentMode: 'CASH',
      counterpartyName: 'City Tempo Logistics',
      description: 'Tempo freight - sugar consignment to store',
      reference: 'CASH/02011100/FRT',
    ),
    const DemoTxBlueprint(
      dayOffset: 2,
      hour: 13,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 1325000, // ₹13,250.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Sunday peak retail sales collection',
      reference: 'UPI/02011330/PEAK',
    ),
    const DemoTxBlueprint(
      dayOffset: 2,
      hour: 20,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 450000, // ₹4,500.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Sunday evening cash drawer tally',
      reference: 'CASH/02012000/DEMO',
    ),

    // --- Day 1 (Yesterday) ---
    const DemoTxBlueprint(
      dayOffset: 1,
      hour: 11,
      minute: 45,
      transactionType: 'CREDIT',
      amountPaise: 565000, // ₹5,650.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Counter QR sales',
      reference: 'UPI/01011145/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 1,
      hour: 15,
      minute: 30,
      transactionType: 'DEBIT',
      amountPaise: 12000, // ₹120.00
      paymentMode: 'CASH',
      counterpartyName: 'Chai Point',
      description: 'Afternoon tea & refreshments',
      reference: 'CASH/01011530/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 1,
      hour: 18,
      minute: 0,
      transactionType: 'CREDIT',
      amountPaise: 280000, // ₹2,800.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Evening cash sales',
      reference: 'CASH/01011800/DEMO',
    ),

    // --- Day 0 (Today) ---
    const DemoTxBlueprint(
      dayOffset: 0,
      hour: 10,
      minute: 30,
      transactionType: 'CREDIT',
      amountPaise: 340000, // ₹3,400.00
      paymentMode: 'UPI',
      counterpartyName: 'Customer UPI Collection',
      description: 'Morning counter sales - provisions & milk',
      reference: 'UPI/00011030/DEMO',
    ),
    const DemoTxBlueprint(
      dayOffset: 0,
      hour: 13,
      minute: 15,
      transactionType: 'CREDIT',
      amountPaise: 160000, // ₹1,600.00
      paymentMode: 'CASH',
      counterpartyName: 'Cash Counter',
      description: 'Noon cash drawer collection',
      reference: 'CASH/00011315/DEMO',
    ),
  ];

  /// Seed the 30-day synthetic demo dataset for the given merchant.
  /// Uses existing LocalCanonicalTransactionRepository to ensure identical schema & calculations.
  /// Fully idempotent: repeated invocations do NOT create duplicates.
  static Future<DemoSeedResult> seed30DayDemoData({
    required String merchantId,
    LocalCanonicalTransactionRepository? txRepo,
  }) async {
    final repo = txRepo ?? LocalCanonicalTransactionRepository();

    // Check existing genuine count before operation to assert isolation
    final genuineCount =
        await repo.getGenuineTransactionCount(merchantId: merchantId);

    int insertedCount = 0;
    int alreadyExistingCount = 0;
    int totalInflows = 0;
    int totalOutflows = 0;

    final now = DateTime.now();
    final todayBase = DateTime.utc(now.year, now.month, now.day);

    for (int i = 0; i < blueprints.length; i++) {
      final bp = blueprints[i];
      final txDate = todayBase
          .subtract(Duration(days: bp.dayOffset))
          .add(Duration(hours: bp.hour, minutes: bp.minute));
      final occurredAt = txDate.toIso8601String();
      final idempotencyKey = 'demo_30d_${merchantId}_d${bp.dayOffset}_t$i';

      if (bp.transactionType == 'CREDIT') {
        totalInflows += bp.amountPaise;
      } else {
        totalOutflows += bp.amountPaise;
      }

      final amountStr = Money.formatPaise(bp.amountPaise);

      final result = await repo.createTransaction(
        merchantId: merchantId,
        amount: amountStr,
        transactionType: bp.transactionType,
        paymentMode: bp.paymentMode,
        counterpartyName: bp.counterpartyName,
        transactionReference: bp.reference,
        description: '[Synthetic Demo Data] ${bp.description}',
        occurredAt: occurredAt,
        idempotencyKey: idempotencyKey,
        sourceType: demoSourceType,
        sourceProvider: demoSourceType,
        isSimulated: true,
      );

      // If returned transaction was created today vs previously existed
      if (result.occurredAt == occurredAt) {
        insertedCount++;
      } else {
        alreadyExistingCount++;
      }
    }

    final postGenuineCount = await repo.getGenuineTransactionCount(merchantId: merchantId);
    assert(postGenuineCount == genuineCount, 'Genuine merchant data must remain untouched');

    return DemoSeedResult(
      totalInserted: insertedCount,
      totalExisting: alreadyExistingCount,
      totalRecords: blueprints.length,
      totalInflowsPaise: totalInflows,
      totalOutflowsPaise: totalOutflows,
      netPaise: totalInflows - totalOutflows,
      genuineRecordsCount: postGenuineCount,
      sampleMerchantName: sampleMerchant,
    );
  }

  /// Clear all synthetic demo transactions for the merchant.
  /// Preserves all genuine merchant records.
  static Future<int> clearDemoData({
    required String merchantId,
    LocalCanonicalTransactionRepository? txRepo,
  }) async {
    final repo = txRepo ?? LocalCanonicalTransactionRepository();
    return await repo.clearDemoTransactions(merchantId: merchantId);
  }

  /// Get status of synthetic demo data for merchant.
  static Future<int> getDemoRecordCount({
    required String merchantId,
    LocalCanonicalTransactionRepository? txRepo,
  }) async {
    final repo = txRepo ?? LocalCanonicalTransactionRepository();
    return await repo.getDemoTransactionCount(merchantId: merchantId);
  }
}
