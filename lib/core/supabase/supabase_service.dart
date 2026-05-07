import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper um die Supabase-Initialisierung.
///
/// Wird einmalig in `main()` aufgerufen, bevor `runApp()` läuft.
/// Liest `SUPABASE_URL` und `SUPABASE_ANON_KEY` aus der `.env`-Datei.
class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL oder SUPABASE_ANON_KEY fehlen in der .env-Datei. '
        'Lege eine .env-Datei im Projekt-Root an (siehe .env.example).',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Bequemer Zugriff auf den Client.
  static SupabaseClient get client => Supabase.instance.client;
}
