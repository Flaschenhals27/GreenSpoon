import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';

/// Liest und schreibt die Diät-Vorlieben des Users in `profiles.dietary_prefs`.
///
/// Speicherformat (jsonb): eine Liste von Schlüsseln, z.B.
/// `{ "tags": ["vegetarisch", "laktosefrei"] }`
class DietaryPrefsRepository {
  DietaryPrefsRepository();

  SupabaseClient get _client => SupabaseService.client;

  /// Lädt die gesetzten Diät-Tags des aktuellen Users.
  Future<List<String>> fetch() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final row = await _client
        .from('profiles')
        .select('dietary_prefs')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return [];
    final prefs = row['dietary_prefs'];
    if (prefs is Map && prefs['tags'] is List) {
      return (prefs['tags'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Speichert die Diät-Tags.
  Future<void> save(List<String> tags) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Nicht eingeloggt.');
    await _client.from('profiles').update({
      'dietary_prefs': {'tags': tags},
    }).eq('id', userId);
  }
}