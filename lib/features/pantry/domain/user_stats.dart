/// Aggregierte Nutzer-Statistiken für Profil- und Impact-Seite.
///
/// Reines Wertobjekt ohne Datenbank- oder Berechnungslogik — befüllt wird es
/// vom [UserStatsCalculator]. So bleibt die Aggregation testbar und vom
/// Repository entkoppelt (SRP).
class UserStats {
  const UserStats({
    this.inPantry = 0,
    this.cookedThisWeek = 0,
    this.consumedTotal = 0,
    this.wastedTotal = 0,
    this.buzzerSaves = 0,
    this.co2SavedKg = 0,
    this.eurSaved = 0,
    this.wastedKgThisMonth = 0,
    this.wastedKgLastMonth = 0,
  });

  final int inPantry;
  final int cookedThisWeek;

  /// Insgesamt verwertete (gegessene/gekochte) Items.
  final int consumedTotal;

  /// Insgesamt weggeworfene Items.
  final int wastedTotal;

  /// Verwertet ≤ `UserStatsCalculator.buzzerThresholdDays` Tage vor MHD
  /// (oder danach) — also plausibel vor der Tonne gerettet.
  final int buzzerSaves;

  /// CO₂e (kg) der *geretteten* Items ([buzzerSaves]-Kohorte) — nicht des
  /// gesamten Konsums. Kontrafaktik siehe `UserStatsCalculator`-Doku.
  final double co2SavedKg;

  /// Geschätzter Warenwert (€) der geretteten Items — der vermiedene
  /// Ersatzkauf. Gleiche Kohorte wie [co2SavedKg].
  final double eurSaved;
  final double wastedKgThisMonth;
  final double wastedKgLastMonth;

  /// Anteil verwertet an allem, was den Vorrat verlassen hat (0..1).
  double get useRate {
    final total = consumedTotal + wastedTotal;
    if (total == 0) return 0;
    return consumedTotal / total;
  }

  /// Gibt es überhaupt schon Historie für eine sinnvolle Quote?
  bool get hasHistory => (consumedTotal + wastedTotal) > 0;
}
