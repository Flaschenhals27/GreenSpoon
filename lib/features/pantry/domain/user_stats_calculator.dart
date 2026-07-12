import '../../scanner/data/co2_estimator.dart';
import 'user_stats.dart';

/// Ein verwertetes (gegessenes/verkochtes) Item — die für die Statistik
/// relevanten Felder, losgelöst vom DB-Zeilenformat.
class ConsumedItem {
  const ConsumedItem({
    required this.category,
    this.quantity,
    this.co2Kg,
    this.expiresAt,
    this.removedAt,
  });

  final String category;
  final String? quantity;

  /// Gemessener CO₂-Wert (kg), falls bekannt. Sonst wird über die Kategorie
  /// geschätzt.
  final double? co2Kg;
  final DateTime? expiresAt;
  final DateTime? removedAt;
}

/// Ein weggeworfenes oder abgelaufenes Item.
class WastedItem {
  const WastedItem({this.quantity, this.removedAt});

  final String? quantity;
  final DateTime? removedAt;
}

/// Berechnet die [UserStats] — reine Aggregation ohne DB-Zugriffe,
/// dadurch ohne Supabase unit-testbar (SRP).
///
/// Methodik: Als CO₂-/€-„Ersparnis" zählen nur Rettungen (verwertet ≤
/// [buzzerThresholdDays] Tage vor dem MHD oder danach) — normal gegessene
/// Lebensmittel vermeiden nichts. Items ohne MHD/Entnahme-Datum zählen
/// konservativ nie als Rettung.
class UserStatsCalculator {
  const UserStatsCalculator();

  /// Restlaufzeit-Schwelle für „auf den letzten Drücker gerettet";
  /// nach MHD verwertet zählt ebenfalls.
  static const buzzerThresholdDays = 3;

  UserStats compute({
    required int inPantry,
    required List<ConsumedItem> consumed,
    required List<WastedItem> wasted,
    required DateTime now,
  }) {
    final weekAgo = now.subtract(const Duration(days: 7));
    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);

    // ── consumed auswerten ────────────────────────────────────────
    var cookedThisWeek = 0;
    var buzzerSaves = 0;
    double co2Total = 0;
    double eurTotal = 0;
    for (final item in consumed) {
      final removedAt = item.removedAt;
      if (removedAt != null && removedAt.isAfter(weekAgo)) cookedThisWeek++;

      // Nur Rettungen zählen als CO₂-/€-Ersparnis (s. Klassen-Doku).
      final expiresAt = item.expiresAt;
      if (expiresAt != null && removedAt != null) {
        final daysLeft =
            DateTime(expiresAt.year, expiresAt.month, expiresAt.day)
                .difference(
                  DateTime(removedAt.year, removedAt.month, removedAt.day),
                )
                .inDays;
        if (daysLeft <= buzzerThresholdDays) {
          buzzerSaves++;
          co2Total += item.co2Kg ??
              Co2Estimator.estimateCo2Kg(
                category: item.category,
                quantity: item.quantity,
              );
          eurTotal += Co2Estimator.estimatePriceEur(
            category: item.category,
            quantity: item.quantity,
          );
        }
      }
    }

    // ── wasted auswerten ──────────────────────────────────────────
    double wastedKgThisMonth = 0;
    double wastedKgLastMonth = 0;
    for (final item in wasted) {
      final kg = Co2Estimator.parseWeightKg(item.quantity) ?? 0.5;
      final removedAt = item.removedAt;
      if (removedAt == null) continue;
      if (removedAt.isAfter(startOfThisMonth)) {
        wastedKgThisMonth += kg;
      } else if (removedAt.isAfter(startOfLastMonth)) {
        wastedKgLastMonth += kg;
      }
    }

    return UserStats(
      inPantry: inPantry,
      cookedThisWeek: cookedThisWeek,
      consumedTotal: consumed.length,
      wastedTotal: wasted.length,
      buzzerSaves: buzzerSaves,
      co2SavedKg: double.parse(co2Total.toStringAsFixed(1)),
      eurSaved: double.parse(eurTotal.toStringAsFixed(0)),
      wastedKgThisMonth: double.parse(wastedKgThisMonth.toStringAsFixed(1)),
      wastedKgLastMonth: double.parse(wastedKgLastMonth.toStringAsFixed(1)),
    );
  }
}
