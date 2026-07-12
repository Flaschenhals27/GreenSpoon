/// Führende Zahl eines Mengen-Strings („500 g" → 500, „1,5 kg" → 1.5),
/// oder `null`, wenn keine erkennbar ist.
double? leadingQuantityValue(String quantity) {
  final match = RegExp(r'^([\d.,]+)').firstMatch(quantity.trim());
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  return (value == null || value <= 0) ? null : value;
}

/// Stück-Synonyme (OFF liefert englische, User tippen deutsche Einheiten).
const _pieceUnits = {
  'stück',
  'stueck',
  'stk',
  'st',
  'pcs',
  'pc',
  'piece',
  'pieces',
  'x',
};

/// Einheit hinter der führenden Zahl („2 Stück" → „Stück", „500 g" → „g"),
/// oder `null`, wenn keine da ist.
String? quantityUnit(String quantity) {
  final match = RegExp(r'^[\d.,]+\s*(.*)$').firstMatch(quantity.trim());
  final unit = match?.group(1)?.trim();
  return (unit == null || unit.isEmpty) ? null : unit;
}

/// Stückzählbar: ganzzahlig ohne Einheit oder mit Stück-Einheit —
/// dann ist „1 verbrauchen" das richtige Modell statt Bruchteilen.
bool isCountableQuantity(String quantity) {
  final value = leadingQuantityValue(quantity);
  if (value == null || value != value.roundToDouble()) return false;
  final unit = quantityUnit(quantity);
  if (unit == null) return true;
  return _pieceUnits.contains(unit.toLowerCase().replaceAll('.', ''));
}

/// Normalisiert Mengen-Strings („10pcs" → „10 Stück"); Unparsebares bleibt.
/// Greift beim Lesen ([PantryItem.fromJson]) — deckt so auch Alt-Bestände ab.
String normalizeQuantity(String quantity) {
  final trimmed = quantity.trim();
  final match = RegExp(r'^([\d.,]+)\s*(.*)$').firstMatch(trimmed);
  if (match == null) return trimmed;

  final number = match.group(1)!;
  final unit = match.group(2)!.trim();
  if (unit.isEmpty) return number;
  if (_pieceUnits.contains(unit.toLowerCase().replaceAll('.', ''))) {
    return '$number Stück';
  }
  return '$number $unit';
}

/// Skaliert einen Mengen-String („500 g" × 0,5 → „250 g");
/// `null` ohne führende Zahl — dann bietet das UI die Anpassung nicht an.
String? scaleQuantity(String quantity, double factor) {
  final match = RegExp(r'^([\d.,]+)\s*(.*)$').firstMatch(quantity.trim());
  if (match == null) return null;

  final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  if (value == null || value <= 0) return null;

  final scaled = value * factor;
  // Ganze Zahlen ohne Nachkommastelle, sonst eine — mit deutschem Komma,
  // der Co2Estimator-Parser versteht beides.
  final numStr = scaled == scaled.roundToDouble()
      ? scaled.round().toString()
      : scaled.toStringAsFixed(1).replaceAll('.', ',');

  final unit = match.group(2)!.trim();
  return unit.isEmpty ? numStr : '$numStr $unit';
}
