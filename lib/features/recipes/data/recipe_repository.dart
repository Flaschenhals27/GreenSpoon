import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/recipe.dart';

/// Spricht mit der Edge Function `generate-recipes`.
/// Der Supabase-Client hängt den User-JWT automatisch an.
class RecipeRepository {
  RecipeRepository();

  SupabaseClient get _client => SupabaseService.client;

  /// Ruft die Edge Function auf und gibt die Rezeptliste zurück.
  /// Wirft [RecipeException] mit lesbarer Message bei Fehlern.
  Future<List<Recipe>> generate() async {
    try {
      final response = await _client.functions.invoke(
        'generate-recipes',
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final body = response.data;
        final msg = (body is Map && body['error'] != null)
            ? body['error'].toString()
            : 'Status ${response.status}';
        throw RecipeException(msg);
      }

      final data = response.data;
      if (data is! Map) {
        throw const RecipeException('Antwortformat unerwartet.');
      }
      final recipesRaw = data['recipes'];
      if (recipesRaw is! List) {
        throw const RecipeException('Keine Rezepte in der Antwort.');
      }

      return recipesRaw
          .whereType<Map<String, dynamic>>()
          .map(Recipe.fromJson)
          .toList();
    } on FunctionException catch (e) {
      throw RecipeException('Function-Fehler: ${e.details ?? e.reasonPhrase}');
    }
  }
}

class RecipeException implements Exception {
  const RecipeException(this.message);
  final String message;

  @override
  String toString() => message;
}