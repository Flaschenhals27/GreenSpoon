import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/supabase_service.dart';
import 'package:intl/date_symbol_data_local.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env laden (enthält Supabase-Credentials).
  
  await dotenv.load(fileName: '.env');

  // Supabase initialisieren.
  await SupabaseService.initialize();
  await initializeDateFormatting('de_DE');
  runApp(
    const ProviderScope(
      child: GreenSpoonApp(),
    ),
  );
}
