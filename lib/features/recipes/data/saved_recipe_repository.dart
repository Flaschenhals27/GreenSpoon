import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/recipe.dart';

/// Verwaltet gespeicherte Rezepte in der `saved_recipes`-Tabelle.
class SavedRecipeRepository {
  SavedRecipeRepository();

  SupabaseClient get _client => SupabaseService.client;
  static const _table = 'saved_recipes';

  /// Speichert ein Rezept für den aktuellen User.
  Future<void> save(Recipe r) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Nicht eingeloggt.');

    await _client.from(_table).insert({
      'user_id': userId,
      'title': r.title,
      'meal': r.meal,
      'time_min': r.timeMin,
      'difficulty': r.difficulty,
      'servings': r.servings,
      'tags': r.tags,
      'used_items': r.uses,
      'missing': r.missing,
      'blurb': r.blurb,
      'body': r.steps.join('\n'),
    });
  }

  /// Entfernt ein gespeichertes Rezept (per Titel des aktuellen Users).
  Future<void> unsaveByTitle(String title) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from(_table)
        .delete()
        .eq('user_id', userId)
        .eq('title', title);
  }

  /// Prüft, ob ein Rezept mit diesem Titel schon gespeichert ist.
  Future<bool> isSaved(String title) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final res = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('title', title)
        .limit(1);
    return (res as List).isNotEmpty;
  }

  /// Lädt alle gespeicherten Rezepte des Users.
  Future<List<Recipe>> fetchAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List).map((row) {
      final m = row as Map<String, dynamic>;
      // DB → Recipe: body zurück in steps splitten, used_items → uses
      return Recipe(
        title: m['title'] as String? ?? 'Ohne Titel',
        meal: m['meal'] as String? ?? 'Mittag',
        timeMin: (m['time_min'] as num?)?.toInt() ?? 0,
        difficulty: m['difficulty'] as String? ?? 'Einfach',
        servings: (m['servings'] as num?)?.toInt() ?? 2,
        tags: _strList(m['tags']),
        uses: _strList(m['used_items']),
        missing: _strList(m['missing']),
        blurb: m['blurb'] as String? ?? '',
        steps: (m['body'] as String?)?.split('\n') ?? const [],
      );
    }).toList();
  }

  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }
}
