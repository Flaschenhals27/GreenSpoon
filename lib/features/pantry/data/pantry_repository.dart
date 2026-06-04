import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../scanner/data/co2_estimator.dart';
import '../../../core/supabase/supabase_service.dart';
import '../domain/pantry_item.dart';

class PantryRepository {
  PantryRepository();

  SupabaseClient get _client => SupabaseService.client;
  static const _table = 'pantry_items';

  /// Live-Stream aller Items des aktuellen Users, sortiert nach Ablaufdatum.
  /// `null`-Ablaufdaten landen am Ende.
  Stream<List<PantryItem>> watchAll() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value(const <PantryItem>[]);
    }

    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final items = rows
              .where((r) => (r['status'] ?? 'active') == 'active')
              .map(PantryItem.fromJson)
              .toList();
          items.sort((a, b) {
            if (a.expiresAt == null && b.expiresAt == null) return 0;
            if (a.expiresAt == null) return 1;
            if (b.expiresAt == null) return -1;
            return a.expiresAt!.compareTo(b.expiresAt!);
          });
          return items;
        })
        .handleError((error) async {
          // Token-Probleme: einmalig versuchen zu refreshen, dann signOut
          if (error.toString().toLowerCase().contains('jwt')) {
            try {
              await _client.auth.refreshSession();
            } catch (_) {
              await _client.auth.signOut();
            }
          }
        });
  }

  /// Item hinzufügen.
  /// Item hinzufügen.
  Future<PantryItem> add({
    required String name,
    String? brand,
    String? quantity,
    required String category,
    String? barcode,
    required String emoji,
    DateTime? expiresAt,
    double? co2Kg,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Nicht eingeloggt.');
    }

    final inserted = await _client
        .from(_table)
        .insert({
          'user_id': userId,
          'name': name,
          'brand': brand,
          'quantity': quantity,
          'category': category,
          'barcode': barcode,
          'emoji': emoji,
          'expires_at': expiresAt?.toIso8601String().split('T').first,
          'co2_kg': co2Kg,
        })
        .select()
        .single()
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () =>
              throw TimeoutException('Speichern hat zu lange gedauert.'),
        );

    return PantryItem.fromJson(inserted);
  }

  /// Mehrere Items auf einmal hinzufügen (z.B. nach dem Foto-Scan eines
  /// ganzen Einkaufs). Ein einziger Insert-Round-Trip.
  Future<void> addAll(List<PantryDraft> drafts) async {
    if (drafts.isEmpty) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Nicht eingeloggt.');
    }

    final rows = drafts
        .map((d) => {
              'user_id': userId,
              'name': d.name,
              'brand': d.brand,
              'quantity': d.quantity,
              'category': d.category,
              'barcode': d.barcode,
              'emoji': d.emoji,
              'expires_at': d.expiresAt?.toIso8601String().split('T').first,
              'co2_kg': d.co2Kg,
            },)
        .toList();

    await _client.from(_table).insert(rows).timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw TimeoutException('Speichern hat zu lange gedauert.'),
        );
  }

  /// Item löschen.
  /// Archiviert ein Item mit Grund. Echtes Löschen passiert nicht mehr.
  Future<void> archive(String id, {required String status}) async {
    await _client.from(_table).update({
      'status': status,
      'removed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Aktive Items, die innerhalb der nächsten [withinDays] Tage ablaufen
  /// (inkl. heute) — frisch aus der DB. Liefert nur tatsächlich vorhandene
  /// Items (kein abgelaufener/verwerteter/weggeworfener Bestand), damit z.B.
  /// die Test-Benachrichtigung nie über Lebensmittel informiert, die es nicht
  /// mehr gibt.
  Future<List<PantryItem>> fetchExpiringSoon({int withinDays = 2}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final until = DateTime(now.year, now.month, now.day + withinDays);

    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .not('expires_at', 'is', null)
        .gte('expires_at', today.toIso8601String().split('T').first)
        .lte('expires_at', until.toIso8601String().split('T').first)
        .order('expires_at');

    return (rows as List)
        .map((r) => PantryItem.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Ändert nur das MHD eines Items.
  Future<void> updateExpiry(String id, DateTime? expiresAt) async {
    await _client.from(_table).update({
      'expires_at': expiresAt?.toIso8601String().split('T').first,
    }).eq('id', id);
  }

  /// Backwards-kompatibler Alias — wird vom Dismissible-Wisch aufgerufen.
  /// Default-Grund: 'discarded'.
  Future<void> delete(String id) => archive(id, status: 'discarded');

  /// Macht ein Archivieren rückgängig (für den Undo nach einem Wisch).
  Future<void> restore(String id) async {
    await _client.from(_table).update({
      'status': 'active',
      'removed_at': null,
    }).eq('id', id);
  }

  /// Schwelle (Tage Restlaufzeit), bis zu der ein verwertetes Item als
  /// „auf den letzten Drücker gerettet" zählt.
  static const buzzerThresholdDays = 3;

  /// Berechnet die User-Stats für Profil + Impact-Seite.
  Future<UserStats> fetchStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const UserStats();

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);

    // 1. Aktueller Vorrat
    final activeRes = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'active')
        .count();

    // 2. Verwertete Items (mit Datums-Infos für Wochen- + Buzzer-Zählung)
    final consumedRows = await _client
        .from(_table)
        .select('co2_kg, category, quantity, expires_at, removed_at')
        .eq('user_id', userId)
        .eq('status', 'consumed');

    // 3. Weggeworfene Items (weggeworfen + abgelaufen)
    final wastedRows = await _client
        .from(_table)
        .select('category, quantity, removed_at')
        .eq('user_id', userId)
        .inFilter('status', ['discarded', 'expired']);

    // ── consumed auswerten ────────────────────────────────────────
    var consumedTotal = 0;
    var cookedThisWeek = 0;
    var buzzerSaves = 0;
    double co2Total = 0;
    double eurTotal = 0;
    for (final row in consumedRows as List) {
      final m = row as Map<String, dynamic>;
      consumedTotal++;
      final category = m['category'] as String? ?? 'Sonstiges';
      final quantity = m['quantity'] as String?;
      final co2 = m['co2_kg'];

      co2Total += (co2 is num)
          ? co2.toDouble()
          : Co2Estimator.estimateCo2Kg(category: category, quantity: quantity);
      eurTotal +=
          Co2Estimator.estimatePriceEur(category: category, quantity: quantity);

      final removedAt = DateTime.tryParse(m['removed_at'] as String? ?? '');
      if (removedAt != null && removedAt.isAfter(weekAgo)) cookedThisWeek++;

      // „Auf den letzten Drücker gerettet": verwertet ≤ N Tage vor MHD.
      final expiresAt = m['expires_at'] != null
          ? DateTime.tryParse(m['expires_at'] as String)
          : null;
      if (expiresAt != null && removedAt != null) {
        final daysLeft =
            DateTime(expiresAt.year, expiresAt.month, expiresAt.day)
                .difference(
                    DateTime(removedAt.year, removedAt.month, removedAt.day),)
                .inDays;
        if (daysLeft <= buzzerThresholdDays) buzzerSaves++;
      }
    }

    // ── wasted auswerten ──────────────────────────────────────────
    var wastedTotal = 0;
    double wastedKgThisMonth = 0;
    double wastedKgLastMonth = 0;
    for (final row in wastedRows as List) {
      final m = row as Map<String, dynamic>;
      wastedTotal++;
      final kg = Co2Estimator.parseWeightKg(m['quantity'] as String?) ?? 0.5;
      final removedAt = DateTime.tryParse(m['removed_at'] as String? ?? '');
      if (removedAt == null) continue;
      if (removedAt.isAfter(startOfThisMonth)) {
        wastedKgThisMonth += kg;
      } else if (removedAt.isAfter(startOfLastMonth)) {
        wastedKgLastMonth += kg;
      }
    }

    return UserStats(
      inPantry: activeRes.count,
      cookedThisWeek: cookedThisWeek,
      consumedTotal: consumedTotal,
      wastedTotal: wastedTotal,
      buzzerSaves: buzzerSaves,
      co2SavedKg: double.parse(co2Total.toStringAsFixed(1)),
      eurSaved: double.parse(eurTotal.toStringAsFixed(0)),
      wastedKgThisMonth: double.parse(wastedKgThisMonth.toStringAsFixed(1)),
      wastedKgLastMonth: double.parse(wastedKgLastMonth.toStringAsFixed(1)),
    );
  }
}

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

  /// Verwertet ≤ [PantryRepository.buzzerThresholdDays] Tage vor MHD.
  final int buzzerSaves;

  final double co2SavedKg;
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
