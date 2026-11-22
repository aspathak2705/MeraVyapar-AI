import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MeraVyapar AI'**
  String get appTitle;

  /// No description provided for @privateDeviceLedger.
  ///
  /// In en, this message translates to:
  /// **'Private Device Ledger'**
  String get privateDeviceLedger;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'हिंदी'**
  String get hindi;

  /// No description provided for @marathi.
  ///
  /// In en, this message translates to:
  /// **'मराठी'**
  String get marathi;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @receivables.
  ///
  /// In en, this message translates to:
  /// **'Receivables'**
  String get receivables;

  /// No description provided for @financialServices.
  ///
  /// In en, this message translates to:
  /// **'Financial Services'**
  String get financialServices;

  /// No description provided for @intelligenceAndInsights.
  ///
  /// In en, this message translates to:
  /// **'Intelligence & Insights'**
  String get intelligenceAndInsights;

  /// No description provided for @localSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Local Suppliers'**
  String get localSuppliers;

  /// No description provided for @supplierShortlist.
  ///
  /// In en, this message translates to:
  /// **'Supplier Shortlist'**
  String get supplierShortlist;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @netCashMovement.
  ///
  /// In en, this message translates to:
  /// **'Net Cash Movement'**
  String get netCashMovement;

  /// No description provided for @totalMoneyIn.
  ///
  /// In en, this message translates to:
  /// **'Total Inflows'**
  String get totalMoneyIn;

  /// No description provided for @totalMoneyOut.
  ///
  /// In en, this message translates to:
  /// **'Total Outflows'**
  String get totalMoneyOut;

  /// No description provided for @outstandingReceivables.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Receivables'**
  String get outstandingReceivables;

  /// No description provided for @totalPayables.
  ///
  /// In en, this message translates to:
  /// **'Total Payables'**
  String get totalPayables;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @importStatement.
  ///
  /// In en, this message translates to:
  /// **'Import Statement'**
  String get importStatement;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record Inflow'**
  String get recordPayment;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Record Outflow'**
  String get addExpense;

  /// No description provided for @recordCredit.
  ///
  /// In en, this message translates to:
  /// **'Record Credit (Money In)'**
  String get recordCredit;

  /// No description provided for @recordDebit.
  ///
  /// In en, this message translates to:
  /// **'Record Debit (Money Out)'**
  String get recordDebit;

  /// No description provided for @viewAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'View All Transactions'**
  String get viewAllTransactions;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @businessProfile.
  ///
  /// In en, this message translates to:
  /// **'Business Profile'**
  String get businessProfile;

  /// No description provided for @devicePermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions & Privacy'**
  String get devicePermissions;

  /// No description provided for @lockWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Lock Workspace'**
  String get lockWorkspace;

  /// No description provided for @unreconciled.
  ///
  /// In en, this message translates to:
  /// **'Unresolved'**
  String get unreconciled;

  /// No description provided for @reconciled.
  ///
  /// In en, this message translates to:
  /// **'Reconciled'**
  String get reconciled;

  /// No description provided for @passbookLedger.
  ///
  /// In en, this message translates to:
  /// **'Passbook Ledger'**
  String get passbookLedger;

  /// No description provided for @allTransactions.
  ///
  /// In en, this message translates to:
  /// **'All Transactions'**
  String get allTransactions;

  /// No description provided for @moneyIn.
  ///
  /// In en, this message translates to:
  /// **'Money In'**
  String get moneyIn;

  /// No description provided for @moneyOut.
  ///
  /// In en, this message translates to:
  /// **'Money Out'**
  String get moneyOut;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @upi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get upi;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransfer;

  /// No description provided for @cheque.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get cheque;

  /// No description provided for @counterparty.
  ///
  /// In en, this message translates to:
  /// **'Counterparty'**
  String get counterparty;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @transactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetails;

  /// No description provided for @transactionType.
  ///
  /// In en, this message translates to:
  /// **'Transaction Type'**
  String get transactionType;

  /// No description provided for @paymentMode.
  ///
  /// In en, this message translates to:
  /// **'Payment Mode'**
  String get paymentMode;

  /// No description provided for @occurredAt.
  ///
  /// In en, this message translates to:
  /// **'Occurred At'**
  String get occurredAt;

  /// No description provided for @reconciliationStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get reconciliationStatus;

  /// No description provided for @manualEntry.
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get manualEntry;

  /// No description provided for @statementImport.
  ///
  /// In en, this message translates to:
  /// **'Statement Import'**
  String get statementImport;

  /// No description provided for @noTransactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No transactions recorded yet.'**
  String get noTransactionsFound;

  /// No description provided for @receivablesTracker.
  ///
  /// In en, this message translates to:
  /// **'Receivables Tracker'**
  String get receivablesTracker;

  /// No description provided for @paymentPromises.
  ///
  /// In en, this message translates to:
  /// **'Payment Promises'**
  String get paymentPromises;

  /// No description provided for @financialRelationships.
  ///
  /// In en, this message translates to:
  /// **'Financial Relationships'**
  String get financialRelationships;

  /// No description provided for @debtorFollowups.
  ///
  /// In en, this message translates to:
  /// **'Debtor Follow-ups'**
  String get debtorFollowups;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDate;

  /// No description provided for @expectedAmount.
  ///
  /// In en, this message translates to:
  /// **'Expected Amount'**
  String get expectedAmount;

  /// No description provided for @settledAmount.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get settledAmount;

  /// No description provided for @pendingAmount.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingAmount;

  /// No description provided for @fulfillPromise.
  ///
  /// In en, this message translates to:
  /// **'Mark Fulfilled'**
  String get fulfillPromise;

  /// No description provided for @sendReminder.
  ///
  /// In en, this message translates to:
  /// **'Send Reminder'**
  String get sendReminder;

  /// No description provided for @createReminderDraft.
  ///
  /// In en, this message translates to:
  /// **'Create Reminder Draft'**
  String get createReminderDraft;

  /// No description provided for @noReceivablesFound.
  ///
  /// In en, this message translates to:
  /// **'No pending receivables found.'**
  String get noReceivablesFound;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @procurementTitle.
  ///
  /// In en, this message translates to:
  /// **'KharidSaathi Procurement'**
  String get procurementTitle;

  /// No description provided for @suppliersTitle.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliersTitle;

  /// No description provided for @purchaseOrders.
  ///
  /// In en, this message translates to:
  /// **'Purchase Orders'**
  String get purchaseOrders;

  /// No description provided for @supplierObligations.
  ///
  /// In en, this message translates to:
  /// **'Supplier Obligations'**
  String get supplierObligations;

  /// No description provided for @purchaseRequests.
  ///
  /// In en, this message translates to:
  /// **'Purchase Requests'**
  String get purchaseRequests;

  /// No description provided for @requestQuotes.
  ///
  /// In en, this message translates to:
  /// **'Request Quotes'**
  String get requestQuotes;

  /// No description provided for @createOrder.
  ///
  /// In en, this message translates to:
  /// **'Create Order'**
  String get createOrder;

  /// No description provided for @confirmDelivery.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delivery'**
  String get confirmDelivery;

  /// No description provided for @qualityCheck.
  ///
  /// In en, this message translates to:
  /// **'Quality Inspection'**
  String get qualityCheck;

  /// No description provided for @pendingObligations.
  ///
  /// In en, this message translates to:
  /// **'Pending Obligations'**
  String get pendingObligations;

  /// No description provided for @marketIntelligenceTitle.
  ///
  /// In en, this message translates to:
  /// **'VyaparPulse Market Intelligence'**
  String get marketIntelligenceTitle;

  /// No description provided for @marketSignals.
  ///
  /// In en, this message translates to:
  /// **'Market Signals'**
  String get marketSignals;

  /// No description provided for @searchMarkets.
  ///
  /// In en, this message translates to:
  /// **'Search markets, commodities, suppliers...'**
  String get searchMarkets;

  /// No description provided for @wholesaleGoods.
  ///
  /// In en, this message translates to:
  /// **'Wholesale Goods'**
  String get wholesaleGoods;

  /// No description provided for @commodityNews.
  ///
  /// In en, this message translates to:
  /// **'Commodity News'**
  String get commodityNews;

  /// No description provided for @allMarkets.
  ///
  /// In en, this message translates to:
  /// **'All Markets'**
  String get allMarkets;

  /// No description provided for @suppliersAndMarkets.
  ///
  /// In en, this message translates to:
  /// **'Suppliers & Markets'**
  String get suppliersAndMarkets;

  /// No description provided for @localSupplierDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Local Supplier Discovery'**
  String get localSupplierDiscovery;

  /// No description provided for @supplierComparison.
  ///
  /// In en, this message translates to:
  /// **'Supplier Comparison'**
  String get supplierComparison;

  /// No description provided for @compareSelected.
  ///
  /// In en, this message translates to:
  /// **'Compare Selected'**
  String get compareSelected;

  /// No description provided for @savedSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Saved Suppliers'**
  String get savedSuppliers;

  /// No description provided for @noSuppliersFound.
  ///
  /// In en, this message translates to:
  /// **'No suppliers found.'**
  String get noSuppliersFound;

  /// No description provided for @noCoordinatesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Geographic Coordinates Provided'**
  String get noCoordinatesAvailable;

  /// No description provided for @unverifiedDiscoveryDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Unverified Online Supplier Discovery: Discovered via public online sources and Google Maps. Not an established trade quote or endorsed partner.'**
  String get unverifiedDiscoveryDisclaimer;

  /// No description provided for @savedToShortlist.
  ///
  /// In en, this message translates to:
  /// **'Saved to shortlist.'**
  String get savedToShortlist;

  /// No description provided for @removedFromShortlist.
  ///
  /// In en, this message translates to:
  /// **'Removed from shortlist.'**
  String get removedFromShortlist;

  /// No description provided for @inShortlist.
  ///
  /// In en, this message translates to:
  /// **'In Shortlist'**
  String get inShortlist;

  /// No description provided for @saveToShortlist.
  ///
  /// In en, this message translates to:
  /// **'Save to Shortlist'**
  String get saveToShortlist;

  /// No description provided for @merchantAssistant.
  ///
  /// In en, this message translates to:
  /// **'Merchant Assistant'**
  String get merchantAssistant;

  /// No description provided for @askFinancialQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask about cash flow, payables or market impact...'**
  String get askFinancialQuestion;

  /// No description provided for @analyzeImpact.
  ///
  /// In en, this message translates to:
  /// **'Analyze Impact on My Business'**
  String get analyzeImpact;

  /// No description provided for @cashFlowSummary.
  ///
  /// In en, this message translates to:
  /// **'Cash Flow Summary'**
  String get cashFlowSummary;

  /// No description provided for @keyObservations.
  ///
  /// In en, this message translates to:
  /// **'Key Facts'**
  String get keyObservations;

  /// No description provided for @suggestedActions.
  ///
  /// In en, this message translates to:
  /// **'Suggested Actions'**
  String get suggestedActions;

  /// No description provided for @aiGeneratedDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI-generated insight based on your private ledger. Verify critical decisions.'**
  String get aiGeneratedDisclaimer;

  /// No description provided for @setupBusinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Merchant Business Profile'**
  String get setupBusinessTitle;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business Name'**
  String get businessName;

  /// No description provided for @businessCategory.
  ///
  /// In en, this message translates to:
  /// **'Business Category'**
  String get businessCategory;

  /// No description provided for @businessType.
  ///
  /// In en, this message translates to:
  /// **'Business Type'**
  String get businessType;

  /// No description provided for @productsAndServices.
  ///
  /// In en, this message translates to:
  /// **'Products & Services'**
  String get productsAndServices;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @customerType.
  ///
  /// In en, this message translates to:
  /// **'Customer Type'**
  String get customerType;

  /// No description provided for @salesChannels.
  ///
  /// In en, this message translates to:
  /// **'Sales Channels'**
  String get salesChannels;

  /// No description provided for @mainProcurementCategories.
  ///
  /// In en, this message translates to:
  /// **'Main Procurement Categories'**
  String get mainProcurementCategories;

  /// No description provided for @turnoverRange.
  ///
  /// In en, this message translates to:
  /// **'Turnover Range'**
  String get turnoverRange;

  /// No description provided for @businessGoals.
  ///
  /// In en, this message translates to:
  /// **'Business Goals'**
  String get businessGoals;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get saveProfile;

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully.'**
  String get profileUpdatedSuccess;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @permissionSettings.
  ///
  /// In en, this message translates to:
  /// **'Permission Settings'**
  String get permissionSettings;

  /// No description provided for @smsPermission.
  ///
  /// In en, this message translates to:
  /// **'SMS Read Permission'**
  String get smsPermission;

  /// No description provided for @cameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Camera Permission'**
  String get cameraPermission;

  /// No description provided for @storagePermission.
  ///
  /// In en, this message translates to:
  /// **'Storage Permission'**
  String get storagePermission;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grantPermission;

  /// No description provided for @permissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get permissionGranted;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get permissionDenied;

  /// No description provided for @evidenceHistory.
  ///
  /// In en, this message translates to:
  /// **'Evidence History'**
  String get evidenceHistory;

  /// No description provided for @captureProof.
  ///
  /// In en, this message translates to:
  /// **'Capture Transaction Proof'**
  String get captureProof;

  /// No description provided for @receivableDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Receivable Detail'**
  String get receivableDetailTitle;

  /// No description provided for @priorityBucket.
  ///
  /// In en, this message translates to:
  /// **'Priority Bucket'**
  String get priorityBucket;

  /// No description provided for @prioritizationReasons.
  ///
  /// In en, this message translates to:
  /// **'Prioritization Reasons & Provenance'**
  String get prioritizationReasons;

  /// No description provided for @sourcePromiseId.
  ///
  /// In en, this message translates to:
  /// **'Source Promise ID'**
  String get sourcePromiseId;

  /// No description provided for @reasonCodes.
  ///
  /// In en, this message translates to:
  /// **'Reason Codes:'**
  String get reasonCodes;

  /// No description provided for @createPaymentReminderDraft.
  ///
  /// In en, this message translates to:
  /// **'Create Payment Reminder Draft'**
  String get createPaymentReminderDraft;

  /// No description provided for @reviewFollowUpContext.
  ///
  /// In en, this message translates to:
  /// **'Review Follow-Up Context'**
  String get reviewFollowUpContext;

  /// No description provided for @paymentPromisesTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Promises Memory'**
  String get paymentPromisesTitle;

  /// No description provided for @recordPaymentPromise.
  ///
  /// In en, this message translates to:
  /// **'Record Explicit Payment Promise'**
  String get recordPaymentPromise;

  /// No description provided for @promisedAmount.
  ///
  /// In en, this message translates to:
  /// **'Promised Amount (₹)'**
  String get promisedAmount;

  /// No description provided for @direction.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get direction;

  /// No description provided for @expectedIncoming.
  ///
  /// In en, this message translates to:
  /// **'Expected Payment Incoming (Receivable)'**
  String get expectedIncoming;

  /// No description provided for @expectedOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Expected Payment Outgoing (Payable)'**
  String get expectedOutgoing;

  /// No description provided for @linkCounterparty.
  ///
  /// In en, this message translates to:
  /// **'Link Counterparty (Optional)'**
  String get linkCounterparty;

  /// No description provided for @savePromise.
  ///
  /// In en, this message translates to:
  /// **'Save Payment Promise'**
  String get savePromise;

  /// No description provided for @openStatus.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openStatus;

  /// No description provided for @fulfilledStatus.
  ///
  /// In en, this message translates to:
  /// **'Fulfilled'**
  String get fulfilledStatus;

  /// No description provided for @overdueStatus.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueStatus;

  /// No description provided for @cancelledStatus.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelledStatus;

  /// No description provided for @fulfill.
  ///
  /// In en, this message translates to:
  /// **'Fulfill'**
  String get fulfill;

  /// No description provided for @noPromisesInSection.
  ///
  /// In en, this message translates to:
  /// **'No payment promises in this section.'**
  String get noPromisesInSection;

  /// No description provided for @recordPromise.
  ///
  /// In en, this message translates to:
  /// **'Record Promise'**
  String get recordPromise;

  /// No description provided for @counterpartyRelationships.
  ///
  /// In en, this message translates to:
  /// **'Financial Relationships'**
  String get counterpartyRelationships;

  /// No description provided for @noCounterpartiesObserved.
  ///
  /// In en, this message translates to:
  /// **'No Financial Counterparties Observed'**
  String get noCounterpartiesObserved;

  /// No description provided for @noCounterpartiesDesc.
  ///
  /// In en, this message translates to:
  /// **'As financial evidence and canonical transactions are recorded, merchant relationship profiles are built deterministically.'**
  String get noCounterpartiesDesc;

  /// No description provided for @observedStatus.
  ///
  /// In en, this message translates to:
  /// **'OBSERVED'**
  String get observedStatus;

  /// No description provided for @confirmedStatus.
  ///
  /// In en, this message translates to:
  /// **'CONFIRMED'**
  String get confirmedStatus;

  /// No description provided for @passbookAndTransactions.
  ///
  /// In en, this message translates to:
  /// **'Passbook & Transactions'**
  String get passbookAndTransactions;

  /// No description provided for @runReconciliationPass.
  ///
  /// In en, this message translates to:
  /// **'Run Reconciliation Pass'**
  String get runReconciliationPass;

  /// No description provided for @noCanonicalTransactions.
  ///
  /// In en, this message translates to:
  /// **'No Canonical Transactions Yet'**
  String get noCanonicalTransactions;

  /// No description provided for @noCanonicalTransactionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Add financial evidence or reconcile captured receipts to build your private canonical ledger.'**
  String get noCanonicalTransactionsDesc;

  /// No description provided for @reconciledStatus.
  ///
  /// In en, this message translates to:
  /// **'Reconciled'**
  String get reconciledStatus;

  /// No description provided for @needsReviewStatus.
  ///
  /// In en, this message translates to:
  /// **'Needs Review'**
  String get needsReviewStatus;

  /// No description provided for @unresolvedStatus.
  ///
  /// In en, this message translates to:
  /// **'Unresolved'**
  String get unresolvedStatus;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @transactionDetailProvenance.
  ///
  /// In en, this message translates to:
  /// **'Transaction Detail & Provenance'**
  String get transactionDetailProvenance;

  /// No description provided for @evidenceProvenanceChain.
  ///
  /// In en, this message translates to:
  /// **'Evidence Provenance Chain'**
  String get evidenceProvenanceChain;

  /// No description provided for @simulatedDemoNotice.
  ///
  /// In en, this message translates to:
  /// **'DEMO EVENT: Simulated payment event processed through reconciliation pipeline.'**
  String get simulatedDemoNotice;

  /// No description provided for @procurementAndKharidSaathi.
  ///
  /// In en, this message translates to:
  /// **'Procurement & KharidSaathi'**
  String get procurementAndKharidSaathi;

  /// No description provided for @quotationsAndComparison.
  ///
  /// In en, this message translates to:
  /// **'Quotations & Comparison'**
  String get quotationsAndComparison;

  /// No description provided for @noPurchaseRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No purchase requests yet'**
  String get noPurchaseRequestsYet;

  /// No description provided for @noPurchaseRequestsDesc.
  ///
  /// In en, this message translates to:
  /// **'Use voice or tap + to create a purchase request.'**
  String get noPurchaseRequestsDesc;

  /// No description provided for @addEntry.
  ///
  /// In en, this message translates to:
  /// **'Add Entry'**
  String get addEntry;

  /// No description provided for @actionCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Action Center'**
  String get actionCenterTitle;

  /// No description provided for @noActionsPending.
  ///
  /// In en, this message translates to:
  /// **'No Pending Actions'**
  String get noActionsPending;

  /// No description provided for @noActionsPendingDesc.
  ///
  /// In en, this message translates to:
  /// **'All financial actions and reminders are currently up to date.'**
  String get noActionsPendingDesc;

  /// No description provided for @reminderDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Reminder Draft'**
  String get reminderDraftTitle;

  /// No description provided for @sendViaWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Send via WhatsApp'**
  String get sendViaWhatsApp;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy Text'**
  String get copyText;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Merchant Login'**
  String get loginTitle;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @verifyAndProceed.
  ///
  /// In en, this message translates to:
  /// **'Verify & Proceed'**
  String get verifyAndProceed;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure local-first merchant intelligence'**
  String get authSubtitle;

  /// No description provided for @noReceivablesPending.
  ///
  /// In en, this message translates to:
  /// **'No Outstanding Receivables'**
  String get noReceivablesPending;

  /// No description provided for @noReceivablesDesc.
  ///
  /// In en, this message translates to:
  /// **'Receivables originate strictly from explicit incoming payment promises. None are currently pending.'**
  String get noReceivablesDesc;

  /// No description provided for @highPriority.
  ///
  /// In en, this message translates to:
  /// **'High Priority'**
  String get highPriority;

  /// No description provided for @mediumPriority.
  ///
  /// In en, this message translates to:
  /// **'Medium Priority'**
  String get mediumPriority;

  /// No description provided for @lowPriority.
  ///
  /// In en, this message translates to:
  /// **'Low Priority'**
  String get lowPriority;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @externalMarketSignals.
  ///
  /// In en, this message translates to:
  /// **'External Market Signals'**
  String get externalMarketSignals;

  /// No description provided for @searchMarketCommodities.
  ///
  /// In en, this message translates to:
  /// **'Search markets, commodities, suppliers or trends...'**
  String get searchMarketCommodities;

  /// No description provided for @reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reference;

  /// No description provided for @intelligentReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Reports & History'**
  String get intelligentReportsTitle;

  /// No description provided for @generateReport.
  ///
  /// In en, this message translates to:
  /// **'Generate Report'**
  String get generateReport;

  /// No description provided for @reportLanguage.
  ///
  /// In en, this message translates to:
  /// **'Report Language'**
  String get reportLanguage;

  /// No description provided for @reportType.
  ///
  /// In en, this message translates to:
  /// **'Report Type'**
  String get reportType;

  /// No description provided for @dailyFinancialDigest.
  ///
  /// In en, this message translates to:
  /// **'Daily Financial Digest'**
  String get dailyFinancialDigest;

  /// No description provided for @cashFlowHealthReport.
  ///
  /// In en, this message translates to:
  /// **'Cash Flow Health Report'**
  String get cashFlowHealthReport;

  /// No description provided for @creditRecoveryReport.
  ///
  /// In en, this message translates to:
  /// **'Credit Recovery & Receivables'**
  String get creditRecoveryReport;

  /// No description provided for @noReportsYet.
  ///
  /// In en, this message translates to:
  /// **'No Reports Generated Yet'**
  String get noReportsYet;

  /// No description provided for @noReportsDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate localized intelligence reports from your private device records.'**
  String get noReportsDesc;

  /// No description provided for @reportDetails.
  ///
  /// In en, this message translates to:
  /// **'Report Details'**
  String get reportDetails;

  /// No description provided for @deleteReport.
  ///
  /// In en, this message translates to:
  /// **'Delete Report'**
  String get deleteReport;

  /// No description provided for @generatingReport.
  ///
  /// In en, this message translates to:
  /// **'Generating report with Nemotron AI...'**
  String get generatingReport;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
