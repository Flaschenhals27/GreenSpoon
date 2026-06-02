/// Die festen Vorrats-Kategorien der App. Eine einzige Quelle der Wahrheit,
/// damit Scan-Review, Foto-Erkennung und Edge Function dieselben Werte nutzen.
///
/// ⚠️ Wird im Prompt der Edge Function `scan-groceries` gespiegelt — bei
/// Änderungen dort mitziehen.
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
  'Sonstiges',
];
