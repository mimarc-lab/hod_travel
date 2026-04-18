import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/supabase/app_db.dart';
import 'features/ai_suggestions/services/ai_key_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url:       SupabaseConfig.url,
      anonKey:   SupabaseConfig.anonKey,
    );
    AppRepositories.init(Supabase.instance.client);
  }

  await AiKeyStore.loadAndConfigure();

  runApp(const HODApp());
}
