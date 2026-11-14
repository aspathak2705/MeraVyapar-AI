import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/local_database_schema.dart';
import '../domain/merchant_business_profile.dart';

final localBusinessProfileRepositoryProvider = Provider((ref) => LocalBusinessProfileRepository());

class LocalBusinessProfileRepository {
  final LocalDatabaseService _dbService;

  LocalBusinessProfileRepository({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  Future<MerchantBusinessProfile> getProfile({required String merchantId, String? fallbackName}) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database driver not initialized');

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableMerchantBusinessProfile}
      WHERE merchant_id = ?
      ''',
      [merchantId],
    );

    if (rows.isNotEmpty) {
      return MerchantBusinessProfile.fromMap(rows.first);
    }

    // Default initialized profile based on merchant
    final defaultProfile = MerchantBusinessProfile(
      merchantId: merchantId,
      businessName: fallbackName ?? 'My Business',
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await saveProfile(defaultProfile);
    return defaultProfile;
  }

  Future<void> saveProfile(MerchantBusinessProfile profile) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database driver not initialized');

    final map = profile.toMap();

    await driver.execute(
      '''
      INSERT OR REPLACE INTO ${LocalDatabaseSchema.tableMerchantBusinessProfile} (
        merchant_id, business_name, business_category, business_type,
        products_and_services, city, state, customer_type, sales_channels,
        main_procurement_categories, turnover_range, business_goals, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        map['merchant_id'],
        map['business_name'],
        map['business_category'],
        map['business_type'],
        map['products_and_services'],
        map['city'],
        map['state'],
        map['customer_type'],
        map['sales_channels'],
        map['main_procurement_categories'],
        map['turnover_range'],
        map['business_goals'],
        map['updated_at'],
      ],
    );
  }
}
