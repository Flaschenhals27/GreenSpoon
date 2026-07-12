import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/meal.dart';
import '../domain/recipe.dart';

/// Vertrag für die Rezept-Generierung. Konsumenten hängen nur an dieser
/// Abstraktion (DIP).
abstract interface class RecipeRepository {
  /// Generiert Rezepte: ohne [meal] je eines pro Mahlzeit, mit [meal]
  /// [count] Alternativen dafür. Wirft [RecipeException] bei Problemen.
  Future<List<Recipe>> generate({Meal? meal, int count});
}

/// Supabase-Umsetzung über die Edge Function `generate-recipes`.
class SupabaseRecipeRepository implements RecipeRepository {
  SupabaseRecipeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Recipe>> generate({Meal? meal, int count = 3}) async {
    try {
      final response = await _client.functions.invoke(
        'generate-recipes',
        method: HttpMethod.post,
        body: meal == null ? null : {'meal': meal.label, 'count': count},
      );

      // Server-Fehler unterscheiden
      if (response.status != 200) {
        if (response.status == 503 ||
            response.status == 504 ||
            response.status == 500) {
          throw const RecipeException(
            type: RecipeErrorType.geminiDown,
            details: 'Edge Function returned status 5xx',
          );
        }
        throw RecipeException(
          type: RecipeErrorType.unknown,
          details: 'Status ${response.status}',
        );
      }

      final data = response.data;
      if (data is! Map) {
        throw const RecipeException(
          type: RecipeErrorType.unknown,
          details: 'Antwortformat unerwartet.',
        );
      }
      final recipesRaw = data['recipes'];
      if (recipesRaw is! List) {
        throw const RecipeException(
          type: RecipeErrorType.unknown,
          details: 'Keine Rezepte in der Antwort.',
        );
      }

      return recipesRaw
          .whereType<Map<String, dynamic>>()
          .map(Recipe.fromJson)
          .toList();
    } on SocketException catch (e) {
      throw RecipeException(
        type: RecipeErrorType.offline,
        details: e.message,
      );
    } on FunctionException catch (e) {
      // FunctionException kann verschiedene Statuscodes haben
      if (e.status == 503 || e.status == 504 || e.status == 500) {
        throw RecipeException(
          type: RecipeErrorType.geminiDown,
          details: e.details?.toString() ?? e.reasonPhrase,
        );
      }
      throw RecipeException(
        type: RecipeErrorType.unknown,
        details: e.details?.toString() ?? e.reasonPhrase,
      );
    } on RecipeException {
      rethrow;
    } catch (e) {
      throw RecipeException(
        type: RecipeErrorType.unknown,
        details: e.toString(),
      );
    }
  }
}

/// Kategorisiert verschiedene Fehler-Szenarien, damit das UI passende
/// Texte und Icons anzeigen kann.
enum RecipeErrorType {
  /// Kein Internet (DNS-Fehler, Socket-Exception)
  offline,

  /// Gemini-API hat ein 5xx oder ist gerade nicht erreichbar
  geminiDown,

  /// Default: irgendwas anderes ist schiefgelaufen
  unknown,
}

class RecipeException implements Exception {
  const RecipeException({
    required this.type,
    this.details,
  });

  final RecipeErrorType type;
  final String? details;

  @override
  String toString() => 'RecipeException(${type.name}): ${details ?? ""}';
}
