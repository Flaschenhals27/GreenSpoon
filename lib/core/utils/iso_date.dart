/// Datums-Formatierung für DATE-Spalten (z.B. `expires_at` in Postgres).
extension IsoDateOnly on DateTime {
  /// Nur der `yyyy-MM-dd`-Anteil, ohne Zeit — das Format, das Postgres
  /// für DATE-Spalten erwartet.
  String toIsoDateString() => toIso8601String().split('T').first;
}
