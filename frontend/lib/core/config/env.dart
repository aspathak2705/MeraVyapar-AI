class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://meravyapar-ai.onrender.com/api/v1',
  );
}
