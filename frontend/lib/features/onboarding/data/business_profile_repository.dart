import '../../../core/api/api_client.dart';
import '../domain/business_profile_model.dart';

class BusinessProfileRepository {
  final ApiClient _apiClient;

  BusinessProfileRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<BusinessProfileModel?> getMyProfile() async {
    final res = await _apiClient.get('/business-profile/me');
    if (res['data'] != null) {
      return BusinessProfileModel.fromJson(res['data']);
    }
    return null;
  }

  Future<BusinessProfileModel> saveProfile(BusinessProfileModel profile) async {
    final res = await _apiClient.put(
      '/business-profile/me',
      body: profile.toJson(),
    );
    return BusinessProfileModel.fromJson(res['data']);
  }
}
