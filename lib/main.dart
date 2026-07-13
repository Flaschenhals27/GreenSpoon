import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/supabase/supabase_service.dart';
import 'features/notifications/notification_service.dart';
import 'features/shell/shell_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env laden (enthält Supabase-Credentials).
  await dotenv.load(fileName: '.env');

  // Supabase initialisieren.
  await SupabaseService.initialize();
  await initializeDateFormatting('de_DE');

  // Expliziter Container statt implizitem ProviderScope, damit auch
  // Nicht-Widget-Code (Notification-Tap) auf die Provider zugreifen kann.
  final container = ProviderContainer();

  // Notification Service initialisieren. Geplant wird erst, wenn der Vorrat
  // geladen ist (siehe MainShell) bzw. der User die Erinnerung aktiviert.
  await NotificationService.instance.initialize(
    onOpenRecipes: () =>
        container.read(shellTabProvider.notifier).open(ShellTab.recipes),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GreenSpoonApp(),
    ),
  );
}
