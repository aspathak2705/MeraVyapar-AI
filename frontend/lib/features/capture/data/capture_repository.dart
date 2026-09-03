import '../../../core/api/api_client.dart';
import '../domain/capture_setting_model.dart';
import '../../evidence/domain/evidence_model.dart';

class CaptureRepository {
  final ApiClient _apiClient;

  CaptureRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<EvidenceModel> submitSharedText(String text) async {
    final res = await _apiClient.post(
      '/capture/shared-text',
      body: {'text': text},
    );
    return EvidenceModel.fromJson(res['data']);
  }

  Future<List<CaptureSourceSettingModel>> getCaptureSettings() async {
    final res = await _apiClient.get('/capture/settings');
    final List list = res['data'] ?? [];
    return list.map((item) => CaptureSourceSettingModel.fromJson(item)).toList();
  }

  Future<CaptureSourceSettingModel> updateCaptureSetting({
    required String sourceType,
    required String providerIdentifier,
    required bool enabled,
  }) async {
    final res = await _apiClient.put(
      '/capture/settings',
      body: {
        'source_type': sourceType,
        'provider_identifier': providerIdentifier,
        'enabled': enabled,
      },
    );
    return CaptureSourceSettingModel.fromJson(res['data']);
  }
}
