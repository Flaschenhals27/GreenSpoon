import 'package:flutter/material.dart';

import '../../../../core/theme/gs_colors.dart';
import '../../domain/meal.dart';

/// Akzentfarben je Mahlzeit — der erschöpfende switch erzwingt die
/// Behandlung neuer [Meal]-Werte (OCP).
({Color tint, Color ink}) mealColors(Meal meal) {
  switch (meal) {
    case Meal.breakfast:
      return (tint: GSColors.honey, ink: GSColors.honeyDeep);
    case Meal.dinner:
      return (tint: GSColors.accent, ink: GSColors.accentDeep);
    case Meal.lunch:
      return (tint: GSColors.primary, ink: GSColors.primary);
  }
}
