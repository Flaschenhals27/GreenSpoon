import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-Initialisierung (einmalig in `main()`); liest die
/// Credentials aus der `.env`-Datei.
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
      // Der Wert aus SUPABASE_ANON_KEY — Supabase nennt den öffentlichen
      // Client-Key inzwischen „publishable key".
      publishableKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    final client = Supabase.instance.client;
    if (client.auth.currentSession != null) {
      // Session vorhanden, aber evtl. abgelaufen. Refresh erzwingen.
      try {
        await client.auth.refreshSession();
      } catch (_) {
        // Refresh fehlgeschlagen (z.B. Refresh-Token auch abgelaufen).
        // Sauber ausloggen, Auth-Guard im Router schickt zum Login.
        await client.auth.signOut();
      }
    }
  }

  /// Bequemer Zugriff auf den Client.
  static SupabaseClient get client => Supabase.instance.client;
}
