import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/notifications/notification_service.dart';
import 'features/notifications/notification_scheduler.dart';
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
  // Notification Service initialisieren.
  await NotificationService.instance.initialize();
  // Notification Scheduler initialisieren.
  await NotificationScheduler.initialize();
  runApp(
    const ProviderScope(
      child: GreenSpoonApp(),
    ),
  );
}
