/// Fallback-Kategorie für alles Unbekannte — überall diese Konstante
/// verwenden statt verstreuter String-Literale.
const String kFallbackCategory = 'Sonstiges';

/// Die festen Vorrats-Kategorien (Single Source of Truth).
/// ⚠️ Im Prompt der Edge Function `scan-groceries` gespiegelt — dort mitziehen.
const List<String> kPantryCategories = [
  'Milchprodukte',
  'Obst',
  'Gemüse',
  'Fleisch & Fisch',
  'Hülsenfrüchte & Tofu',
  'Pasta & Reis',
  'Brot & Backwaren',
  'Backzutaten',
  'Müsli & Cerealien',
  'Eier',
  'Süßes & Snacks',
  'Gewürze & Saucen',
  'Öle & Fette',
  'Aufstriche',
  'Konserven',
  'Tiefkühl',
  'Getränke',
  kFallbackCategory,
];
