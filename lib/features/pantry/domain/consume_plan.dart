import 'quantity_utils.dart';

/// Ergebnis eines geplanten Verbrauchs: entweder das ganze Item (dann
/// archivieren) oder ein Teil (dann Item verkleinern).
class ConsumptionPlan {
  const ConsumptionPlan.whole({required this.consumedCo2})
      : consumesWhole = true,
        remainingQuantity = null,
        consumedQuantity = null,
        remainingCo2 = null;

  const ConsumptionPlan.partial({
    required this.remainingQuantity,
    required this.consumedQuantity,
    required this.remainingCo2,
    required this.consumedCo2,
  }) : consumesWhole = false;

  /// True → die Menge deckt den ganzen Bestand: Item archivieren, statt es auf
  /// „0" zu verkleinern.
  final bool consumesWhole;

  /// Nur bei Teil-Verbrauch gesetzt.
  final String? remainingQuantity;
  final String? consumedQuantity;
  final double? remainingCo2;

  /// Anteiliges CO₂ des verbrauchten Teils (bzw. das ganze bei [consumesWhole]).
  final double? consumedCo2;
}

/// Plant den Verbrauch von [pieces] Stück eines stückzählbaren Items mit Menge
/// [quantity] und verteilt [totalCo2] gleichmäßig auf die Stücke.
///
/// Liefert `null`, wenn [quantity] keine Stückzahl trägt (z.B. „500 g") oder
/// die Eingaben unsinnig sind. Deckt [pieces] die ganze Menge (oder mehr) ab,
/// ist das Ergebnis [ConsumptionPlan.whole].
ConsumptionPlan? planPieceConsumption({
  required String quantity,
  required int pieces,
  double? totalCo2,
}) {
  if (pieces <= 0 || !isCountableQuantity(quantity)) return null;
  final available = leadingQuantityValue(quantity)?.round();
  if (available == null || available <= 0) return null;

  if (pieces >= available) {
    return ConsumptionPlan.whole(consumedCo2: totalCo2);
  }

  final unit = quantityUnit(quantity);
  String fmt(int n) => unit == null ? '$n' : '$n $unit';
  final perPiece = totalCo2 == null ? null : totalCo2 / available;
  final remaining = available - pieces;

  return ConsumptionPlan.partial(
    remainingQuantity: fmt(remaining),
    consumedQuantity: fmt(pieces),
    remainingCo2: perPiece == null ? null : perPiece * remaining,
    consumedCo2: perPiece == null ? null : perPiece * pieces,
  );
}

/// Plant den Verbrauch einer gemessenen Menge [needed] (z.B. „200 g") von einem
/// wiegbaren Item [quantity] (z.B. „500 g", „1,5 kg"). Rechnet innerhalb einer
/// Einheiten-Familie um (g/kg, ml/l) und teilt [totalCo2] anteilig auf.
///
/// Liefert `null`, wenn die Einheiten nicht zusammenpassen oder eine Menge
/// nicht parsebar ist — dann bleibt nur der Ganz-Verbrauch. Deckt [needed] die
/// ganze Menge (oder mehr) ab, ist das Ergebnis [ConsumptionPlan.whole].
ConsumptionPlan? planAmountConsumption({
  required String quantity,
  required String needed,
  double? totalCo2,
}) {
  final have = _measured(quantity);
  final want = _measured(needed);
  if (have == null || want == null || have.family != want.family) return null;

  final haveBase = have.value * have.factor;
  final wantBase = want.value * want.factor;
  if (haveBase <= 0 || wantBase <= 0) return null;

  if (wantBase >= haveBase) {
    return ConsumptionPlan.whole(consumedCo2: totalCo2);
  }

  final consumedRatio = wantBase / haveBase;
  final remainingBase = haveBase - wantBase;

  return ConsumptionPlan.partial(
    remainingQuantity: _formatMeasured(remainingBase / have.factor, have.unit),
    consumedQuantity: _formatMeasured(wantBase / have.factor, have.unit),
    remainingCo2: totalCo2 == null ? null : totalCo2 * (1 - consumedRatio),
    consumedCo2: totalCo2 == null ? null : totalCo2 * consumedRatio,
  );
}

// Umrechenbare Einheiten je Familie (Faktor → Basiseinheit: Gramm bzw. ml).
const _massUnits = {'mg': 0.001, 'g': 1.0, 'gr': 1.0, 'kg': 1000.0};
const _volumeUnits = {'ml': 1.0, 'cl': 10.0, 'dl': 100.0, 'l': 1000.0};

({double value, String unit, String family, double factor})? _measured(
  String raw,
) {
  final value = leadingQuantityValue(raw);
  final unit = quantityUnit(raw);
  if (value == null || unit == null) return null;
  final key = unit.toLowerCase();
  final mass = _massUnits[key];
  if (mass != null) {
    return (value: value, unit: unit, family: 'mass', factor: mass);
  }
  final volume = _volumeUnits[key];
  if (volume != null) {
    return (value: value, unit: unit, family: 'volume', factor: volume);
  }
  return null;
}

/// Formatiert eine Menge mit deutschem Komma, ohne überflüssige Nachkommastellen
/// („0.2" → „0,2 kg", „300.0" → „300 g").
String _formatMeasured(double value, String unit) {
  var text = value.toStringAsFixed(2);
  text = text.replaceAll(RegExp(r'0+$'), '');
  text = text.replaceAll(RegExp(r'\.$'), '');
  text = text.replaceAll('.', ',');
  return '$text $unit';
}
