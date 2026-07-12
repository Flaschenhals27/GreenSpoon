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

/// Berechnet die [UserStats] aus den rohen Vorrats-Daten.
///
/// Bewusst frei von Datenbank-Zugriffen: das Repository lädt und mappt die
/// Zeilen, dieser Calculator macht ausschließlich die Aggregation. Dadurch
/// ist die Logik (CO₂-/€-Summen, Wochen-Zählung, „Buzzer"-Rettungen,
/// Wegwerf-Bilanz pro Monat) ohne Supabase unit-testbar (SRP).
///
/// ## Methodik der „Ersparnis"-Werte (CO₂ & €)
///
/// „Vermieden/gespart" ist eine *kontrafaktische* Aussage: sie braucht ein
/// glaubwürdiges „was wäre sonst passiert?". Normal gegessene Lebensmittel
/// vermeiden nichts — ihr CO₂ ist bei der Produktion so oder so entstanden.
/// Deshalb zählen in [UserStats.co2SavedKg] und [UserStats.eurSaved] **nur
/// Rettungen**: Items, die ≤ [buzzerThresholdDays] Tage vor dem MHD (oder
/// danach) verwertet wurden. Kontrafaktik: ohne die Rettung wäre das Item
/// mit hoher Wahrscheinlichkeit im Müll gelandet — sein Produktions-CO₂
/// wäre „für nichts" ausgestoßen und ein Ersatzkauf (≈ gleicher Preis,
/// ≈ gleiches CO₂) nötig geworden. Dieselbe Kohorte speist auch den
/// [UserStats.buzzerSaves]-Zähler — eine Metrik, drei Sichten.
///
/// Konservativ dabei: Items ohne MHD oder ohne Entnahme-Datum können nie
/// als Rettung zählen — lieber unter- als überschätzen.
class UserStatsCalculator {
  const UserStatsCalculator();

  /// Schwelle (Tage Restlaufzeit), bis zu der ein verwertetes Item als
  /// „auf den letzten Drücker gerettet" zählt. Negative Restlaufzeit
  /// (nach MHD verwertet) zählt ebenfalls — MHD ist kein Verfallsdatum,
  /// und gerade das ist eine Rettung vor der Tonne.
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

      // „Auf den letzten Drücker gerettet": verwertet ≤ N Tage vor MHD
      // (oder danach). NUR diese Rettungen zählen als CO₂-/€-Ersparnis —
      // normal verbrauchte Lebensmittel vermeiden nichts (s. Klassen-Doku).
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
