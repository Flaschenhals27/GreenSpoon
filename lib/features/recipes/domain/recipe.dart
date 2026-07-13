import 'package:flutter/foundation.dart';

import 'meal.dart';

@immutable
class Recipe {
  const Recipe({
    required this.title,
    required this.meal,
    required this.timeMin,
    required this.difficulty,
    required this.servings,
    required this.tags,
    required this.uses,
    required this.missing,
    required this.blurb,
    required this.steps,
    this.amounts = const {},
  });

  final String title;
  final Meal meal;
  final int timeMin;
  final String difficulty;
  final int servings;
  final List<String> tags;
  final List<String> uses; // Zutaten aus dem Vorrat
  final List<String> missing; // Zutaten, die fehlen
  final String blurb;
  final List<String> steps;

  /// Benötigte Menge je Zutat („Eier" → „3", „Mehl" → „200 g"). Leer, wenn die
  /// KI (noch) keine Mengen liefert — dann greifen die Defaults im UI.
  final Map<String, String> amounts;

  /// Wie gut nutzt das Rezept den Vorrat (0..100).
  /// Wir zeigen das im UI als „Match"-Badge.
  int get matchScore {
    final total = uses.length + missing.length;
    if (total == 0) return 0;
    return ((uses.length / total) * 100).round();
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    List<String> stringList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    Map<String, String> stringMap(dynamic v) {
      if (v is Map) {
        return {
          for (final entry in v.entries)
            entry.key.toString(): entry.value.toString(),
        };
      }
      return const {};
    }

    return Recipe(
      title: json['title'] as String? ?? 'Ohne Titel',
      meal: Meal.fromLabel(json['meal'] as String?),
      timeMin: (json['time_min'] as num?)?.toInt() ?? 0,
      difficulty: json['difficulty'] as String? ?? 'Einfach',
      servings: (json['servings'] as num?)?.toInt() ?? 2,
      tags: stringList(json['tags']),
      uses: stringList(json['uses']),
      missing: stringList(json['missing']),
      blurb: json['blurb'] as String? ?? '',
      steps: stringList(json['steps']),
      amounts: stringMap(json['amounts']),
    );
  }

  /// Spiegelt [fromJson] — für den persistenten Rezept-Cache.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'meal': meal.label,
      'time_min': timeMin,
      'difficulty': difficulty,
      'servings': servings,
      'tags': tags,
      'uses': uses,
      'missing': missing,
      'blurb': blurb,
      'steps': steps,
      'amounts': amounts,
    };
  }
}
