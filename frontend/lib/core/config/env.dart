class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://meravyapar-ai-gateway.onrender.com/api/v1',
  );
}
