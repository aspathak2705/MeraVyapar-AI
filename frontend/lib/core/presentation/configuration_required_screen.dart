import 'package:flutter/material.dart';

class ConfigurationRequiredScreen extends StatelessWidget {
  const ConfigurationRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings_suggest_outlined,
                    size: 36,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Environment Configuration Required',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'MeraVyapar AI Phase 0 is unconfigured.\nProvide SUPABASE_URL and SUPABASE_ANON_KEY environment variables to enable merchant identity and backend authentication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Required Setup Steps:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('1. Set SUPABASE_URL in environment or .env', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      SizedBox(height: 4),
                      Text('2. Set SUPABASE_ANON_KEY in environment or .env', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      SizedBox(height: 4),
                      Text('3. Restart application build', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
