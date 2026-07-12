import 'package:flutter/material.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../domain/meal.dart';

/// Mahlzeit-Akzente: Farbe je Tageszeit.
///
/// Die Leit-Emojis liefert die Domain (`Meal.emoji`); die Farben bleiben
/// hier in der Präsentationsschicht. Der erschöpfende switch über [Meal]
/// erzwingt, dass eine neue Mahlzeit hier behandelt werden muss (OCP).
({Color tint, Color ink}) mealColors(Meal meal) {
  switch (meal) {
    case Meal.breakfast:
      return (tint: GSColors.honey, ink: const Color(0xFF8A6A17));
    case Meal.dinner:
      return (tint: GSColors.accent, ink: GSColors.accentDeep);
    case Meal.lunch:
      return (tint: GSColors.primary, ink: GSColors.primary);
  }
}
