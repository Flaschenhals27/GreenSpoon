import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../pantry/domain/pantry_item.dart';
import '../domain/recipe.dart';

/// Persistenter Rezept-Cache mit Signatur (Tag + Vorrat + User) — nur bei
/// geänderter Signatur wird die teure Edge Function erneut aufgerufen.
class RecipeCache {
  RecipeCache(this._client);

  final SupabaseClient _client;

  static const _kRecipes = 'recipes_cache_json';
  static const _kSignature = 'recipes_cache_signature';

  /// Baut die Signatur aus User, aktuellem Datum und Vorrats-IDs.
  String signatureFor(List<PantryItem> pantry) {
    final userId = _client.auth.currentUser?.id ?? 'anon';
    final now = DateTime.now();
    final day = '${now.year}-${now.month}-${now.day}';
    final ids = pantry.map((e) => e.id).toList()..sort();
    return '$userId|$day|${ids.join(",")}';
  }

  /// Liest die gecachten Rezepte + Signatur. Gibt `null` zurück, wenn nichts
  /// gespeichert ist oder der Inhalt nicht gelesen werden kann.
  Future<({List<Recipe> recipes, String signature})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRecipes);
    final signature = prefs.getString(_kSignature);
    if (raw == null || signature == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final recipes = decoded
          .whereType<Map<String, dynamic>>()
          .map(Recipe.fromJson)
          .toList();
      return (recipes: recipes, signature: signature);
    } catch (_) {
      // Defektes JSON → so behandeln, als gäbe es keinen Cache.
      return null;
    }
  }

  /// Speichert Rezepte + zugehörige Signatur.
  Future<void> save(List<Recipe> recipes, String signature) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(recipes.map((r) => r.toJson()).toList());
    await prefs.setString(_kRecipes, raw);
    await prefs.setString(_kSignature, signature);
  }

  /// Löscht den Cache (erzwingt beim nächsten Laden eine frische Generierung).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecipes);
    await prefs.remove(_kSignature);
  }
}
