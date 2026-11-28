class ParsedSmsTransaction {
  final String amount;
  final int amountPaise;
  final String type; // 'MONEY_IN' or 'MONEY_OUT'
  final String rawDirection; // 'credit' or 'debit'
  final String merchant;
  final String paymentMode; // 'UPI', 'Card', 'ATM', 'Auto-debit', 'Bank Transfer'
  final String accountNo;
  final String bankRefNo;
  final bool isEligible;
  final String classification;
  final String? rejectionReason;

  const ParsedSmsTransaction({
    required this.amount,
    required this.amountPaise,
    required this.type,
    required this.rawDirection,
    required this.merchant,
    required this.paymentMode,
    required this.accountNo,
    required this.bankRefNo,
    required this.isEligible,
    required this.classification,
    this.rejectionReason,
  });
}

class SmsParser {
  static final List<Map<String, dynamic>> _smsPatterns = [
    {
      // Credit: verb-first (credited, received, deposited, paid you, sent you, refunded, reversed)
      'pattern': RegExp(
        r'(?:credited|received|credit\s+of|deposited|paid\s+you|sent\s+you|refunded|reversed).{0,25}?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      'type': 'credit',
    },
    {
      // Credit: amount-first
      'pattern': RegExp(
        r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?).{0,50}?(?:credited|received|deposited|refunded|reversed)',
        caseSensitive: false,
      ),
      'type': 'credit',
    },
    {
      // Debit: verb-first (debited, deducted, spent, paid to, payment of, purchase of)
      'pattern': RegExp(
        r'(?:debited|deducted|spent|paid\s+to|payment\s+of|purchase\s+of|(?:you\s+)?paid(?![\s]+you)).{0,25}?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      'type': 'debit',
    },
    {
      // Debit: amount-first
      'pattern': RegExp(
        r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?).{0,50}?(?:debited|deducted|spent|paid)',
        caseSensitive: false,
      ),
      'type': 'debit',
    },
  ];

  static final RegExp _merchantPattern = RegExp(
    r'(?:at|to|from|via|for(?!\s*(?:Rs\.?|INR|₹|dispute|query|help|queries)))\s+([A-Za-z0-9\s&\-\.]+?)(?:\s+on|\s+for|\s+ref|\s+avl|\.|;|$)',
    caseSensitive: false,
  );

  static final RegExp _merchantPatternSecondary = RegExp(
    r';\s*([A-Za-z0-9\s&\-\.]+?)\s+credited',
    caseSensitive: false,
  );

  static final RegExp _upiPattern = RegExp(
    r'UPI[\s:]+([a-zA-Z0-9@\.\-_]+)',
    caseSensitive: false,
  );

  static final RegExp _accountNoPattern = RegExp(
    r'(?:a/c|acct|account|card)(?:\s*no\.?|\s*number)?[\s:-]*(?:ending\s+with\s+|ending\s+in\s+)?([xX*0-9]+)',
    caseSensitive: false,
  );

  static final RegExp _refNoPattern = RegExp(
    r'(?:upi\s*ref(?:\s*no)?|ref(?:\s*no)?|reference(?:\s*no)?|utr(?:\s*no)?|txn\s*id|rrn)[\s:-]*([a-zA-Z0-9_-]{6,})',
    caseSensitive: false,
  );

  /// Parse currency amount into exact integer paise (1 INR = 100 paise)
  static int parsePaise(String amountStr) {
    final clean = amountStr.replaceAll(',', '').trim();
    if (clean.isEmpty) return 0;
    final parts = clean.split('.');
    final rupees = int.tryParse(parts[0]) ?? 0;
    int paise = 0;
    if (parts.length > 1) {
      final frac = parts[1].padRight(2, '0').substring(0, 2);
      paise = int.tryParse(frac) ?? 0;
    }
    return rupees * 100 + paise;
  }

  /// Known merchant alias mapping dictionary
  static final Map<String, String> _knownAliases = {
    'AMZN': 'Amazon',
    'AMAZON PAY': 'Amazon',
    'AVENUE SUPERMARTS': 'DMart',
    'DMART': 'DMart',
    'SWIGGY': 'Swiggy',
    'SWIGGY INSTAMART': 'Swiggy Instamart',
    'INSTAMART': 'Swiggy Instamart',
    'ZOMATO': 'Zomato',
    'BLINKIT': 'Blinkit',
    'ZEPTO': 'Zepto',
    'FLIPKART': 'Flipkart',
    'IRCTC': 'IRCTC',
    'JIO': 'Reliance Jio',
    'AIRTEL': 'Bharti Airtel',
    'VI': 'Vodafone Idea',
    'INDIAN OIL': 'Indian Oil',
    'HPCL': 'Hindustan Petroleum',
    'BPCL': 'Bharat Petroleum',
    'PETROL PUMP': 'Fuel Station',
    'PAYTM': 'Paytm',
    'PHONEPE': 'PhonePe',
    'BHARATPE': 'BharatPe',
    'GOOGLEPAY': 'Google Pay',
    'GPAY': 'Google Pay',
  };

  /// High precision parse of an SMS body into structured transaction
  static ParsedSmsTransaction? parse(String smsBody) {
    if (smsBody.trim().isEmpty) return null;
    final lower = smsBody.toLowerCase();

    // 1. Filter out OTP & security codes
    if (lower.contains('otp') ||
        lower.contains('verification code') ||
        lower.contains('one time password') ||
        lower.contains('secret code') ||
        lower.contains('do not share')) {
      final isOtpOnly = !lower.contains('debited') &&
          !lower.contains('credited') &&
          !lower.contains('paid you');
      if (isOtpOnly) {
        return const ParsedSmsTransaction(
          amount: '0.00',
          amountPaise: 0,
          type: 'UNKNOWN',
          rawDirection: 'unknown',
          merchant: 'Unknown',
          paymentMode: 'UNKNOWN',
          accountNo: '',
          bankRefNo: '',
          isEligible: false,
          classification: 'OTP',
          rejectionReason: 'Security OTP verification code',
        );
      }
    }

    // 2. Filter out Promotional & Loan offers
    if (lower.contains('pre-approved') ||
        lower.contains('apply now') ||
        lower.contains('get loan') ||
        lower.contains('congratulations! you are eligible') ||
        lower.contains('flat off on your next') ||
        lower.contains('cashback offer')) {
      return const ParsedSmsTransaction(
        amount: '0.00',
        amountPaise: 0,
        type: 'UNKNOWN',
        rawDirection: 'unknown',
        merchant: 'Unknown',
        paymentMode: 'UNKNOWN',
        accountNo: '',
        bankRefNo: '',
        isEligible: false,
        classification: 'PROMO',
        rejectionReason: 'Promotional marketing message',
      );
    }

    // 3. Filter out Payment Requests (collect requests)
    if (lower.contains('requested money') ||
        lower.contains('requested rs') ||
        lower.contains('has requested') ||
        lower.contains('request for rs') ||
        lower.contains('collect request') ||
        lower.contains('has requested ₹')) {
      return const ParsedSmsTransaction(
        amount: '0.00',
        amountPaise: 0,
        type: 'UNKNOWN',
        rawDirection: 'unknown',
        merchant: 'Unknown',
        paymentMode: 'UPI',
        accountNo: '',
        bankRefNo: '',
        isEligible: false,
        classification: 'PAYMENT_REQUEST',
        rejectionReason: 'Payment collect request; not settled',
      );
    }

    // 4. Filter out Failed / Declined transactions
    if (lower.contains('failed') ||
        lower.contains('declined') ||
        lower.contains('unsuccessful') ||
        lower.contains('could not be processed') ||
        lower.contains('transaction failed')) {
      return const ParsedSmsTransaction(
        amount: '0.00',
        amountPaise: 0,
        type: 'UNKNOWN',
        rawDirection: 'unknown',
        merchant: 'Unknown',
        paymentMode: 'UNKNOWN',
        accountNo: '',
        bankRefNo: '',
        isEligible: false,
        classification: 'FAILED',
        rejectionReason: 'Failed or declined transaction at gateway',
      );
    }

    // 5. Filter out Balance-only notifications
    final hasBalKeywords = lower.contains('avail bal') ||
        lower.contains('available balance') ||
        lower.contains('clear balance') ||
        lower.contains('bal rs.') ||
        lower.contains('balance is');
    final hasTxKeywords = lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('paid you') ||
        lower.contains('sent you') ||
        lower.contains('transferred') ||
        lower.contains('paid rs') ||
        lower.contains('spent');

    if (hasBalKeywords && !hasTxKeywords) {
      return const ParsedSmsTransaction(
        amount: '0.00',
        amountPaise: 0,
        type: 'UNKNOWN',
        rawDirection: 'unknown',
        merchant: 'Unknown',
        paymentMode: 'UNKNOWN',
        accountNo: '',
        bankRefNo: '',
        isEligible: false,
        classification: 'BALANCE_ONLY',
        rejectionReason: 'Balance inquiry notification',
      );
    }

    // 6. Extract Amount & Direction using paired regexes
    String? amountStr;
    String rawDirection = 'debit';

    for (final entry in _smsPatterns) {
      final pattern = entry['pattern'] as RegExp;
      final match = pattern.firstMatch(smsBody);
      if (match != null) {
        amountStr = match.group(1)?.replaceAll(',', '');
        rawDirection = entry['type'] as String;
        break;
      }
    }

    // Handle reversal / refund keywords
    if (lower.contains('refunded') ||
        lower.contains('refund') ||
        lower.contains('reversed') ||
        lower.contains('reversal')) {
      rawDirection = 'credit';
    }

    if (amountStr == null) return null;
    final int amountPaise = parsePaise(amountStr);
    if (amountPaise <= 0) return null;

    // 7. Extract Merchant / Counterparty
    String merchant = 'Unknown';

    // Priority A: "X paid you" / "X sent you"
    final paidYouRegex = RegExp(
      r'^([A-Za-z0-9\s]{3,35}?)\s+(?:paid|sent)\s+you',
      caseSensitive: false,
    );
    final paidYouMatch = paidYouRegex.firstMatch(smsBody.trim());

    if (paidYouMatch != null) {
      merchant = paidYouMatch.group(1)!.trim();
    } else {
      // Priority B: UPI handle
      final upiMatch = _upiPattern.firstMatch(smsBody);
      if (upiMatch != null) {
        final upiVal = upiMatch.group(1)!;
        if (!upiVal.toLowerCase().startsWith('ref')) {
          merchant = upiVal.contains('@') ? upiVal.split('@').first : upiVal;
        }
      }

      // Priority C: Standard merchant pattern
      if (merchant == 'Unknown') {
        final secondaryMatch = _merchantPatternSecondary.firstMatch(smsBody);
        final primaryMatch = _merchantPattern.firstMatch(smsBody);

        if (secondaryMatch != null &&
            secondaryMatch.group(1)?.trim().isNotEmpty == true) {
          merchant = secondaryMatch.group(1)!.trim();
        } else if (primaryMatch != null &&
            primaryMatch.group(1)?.trim().isNotEmpty == true) {
          final cand = primaryMatch.group(1)!.trim();
          final lowerCand = cand.toLowerCase();
          if (!lowerCand.startsWith('rs') &&
              !lowerCand.startsWith('inr') &&
              !lowerCand.startsWith('₹') &&
              !lowerCand.contains('account') &&
              !lowerCand.contains('a/c') &&
              !lowerCand.contains('your')) {
            merchant = cand;
          }
        }
      }
    }

    // Clean up trailing punctuation and payment mode keywords in merchant name
    merchant = merchant
        .replaceAll(RegExp(r'\s+upi$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\.,;:]+$'), '')
        .trim();
    if (merchant.isEmpty) merchant = 'Unknown';

    // Normalize known merchant alias
    final upperM = merchant.toUpperCase();
    final words = upperM.split(RegExp(r'\s+'));
    for (final entry in _knownAliases.entries) {
      if (upperM == entry.key || words.contains(entry.key)) {
        merchant = entry.value;
        break;
      }
    }

    // 8. Payment Mode
    String paymentMode = 'Bank Transfer';
    if (lower.contains('upi') || lower.contains('vpa') || smsBody.contains('@')) {
      paymentMode = 'UPI';
    } else if (lower.contains('atm') || lower.contains('cash withdrawal')) {
      paymentMode = 'ATM';
    } else if (lower.contains('credit card') ||
        lower.contains('debit card') ||
        lower.contains('cc ') ||
        lower.contains('dc ') ||
        lower.contains('card') ||
        lower.contains('pos')) {
      paymentMode = 'Card';
    } else if (lower.contains('auto') ||
        lower.contains('nach') ||
        lower.contains('mandate')) {
      paymentMode = 'Auto-debit';
    } else if (lower.contains('netbanking') ||
        lower.contains('imps') ||
        lower.contains('neft') ||
        lower.contains('rtgs')) {
      paymentMode = 'Bank Transfer';
    }

    // 9. Account Number & Bank Reference
    final accountMatch = _accountNoPattern.firstMatch(smsBody);
    final rawAccount = accountMatch?.group(1)?.trim() ?? '';
    final accountNo = rawAccount.replaceAll(RegExp(r'^[xX*]+'), '');

    final refMatch = _refNoPattern.firstMatch(smsBody);
    final bankRefNo = refMatch?.group(1)?.trim() ?? '';

    final canonicalType = rawDirection == 'credit' ? 'MONEY_IN' : 'MONEY_OUT';

    return ParsedSmsTransaction(
      amount: amountStr,
      amountPaise: amountPaise,
      type: canonicalType,
      rawDirection: rawDirection,
      merchant: merchant,
      paymentMode: paymentMode,
      accountNo: accountNo,
      bankRefNo: bankRefNo,
      isEligible: true,
      classification: rawDirection == 'credit' ? 'CREDIT' : 'DEBIT',
    );
  }
}
