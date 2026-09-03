import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isConfigured) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint("Supabase initialization error: $e");
    }
  }

  runApp(const ProviderScope(child: MeraVyaparApp()));
}

class MeraVyaparApp extends StatelessWidget {
  const MeraVyaparApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeraVyapar AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AppRouter(),
    );
  }
}
