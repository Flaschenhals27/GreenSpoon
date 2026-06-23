import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/pantry_item.dart';
import '../domain/user_stats.dart';
import '../domain/user_stats_calculator.dart';

/// Vertrag für den Zugriff auf den Vorrat. Konsumenten (Provider, UI) hängen
/// nur an dieser Abstraktion (DIP).
abstract interface class PantryRepository {
  /// Live-Stream aller aktiven Items des Users, sortiert nach Ablaufdatum.
  Stream<List<PantryItem>> watchAll();

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
  });

  /// Mehrere Items in einem Round-Trip hinzufügen.
  Future<void> addAll(List<PantryDraft> drafts);

  /// Archiviert ein Item mit Grund (kein echtes Löschen).
  Future<void> archive(String id, {required String status});

  /// Aktive Items, die innerhalb der nächsten [withinDays] Tage ablaufen.
  Future<List<PantryItem>> fetchExpiringSoon({int withinDays});

  /// Ändert nur das MHD eines Items.
  Future<void> updateExpiry(String id, DateTime? expiresAt);

  /// Backwards-kompatibler Alias — Default-Grund: 'discarded'.
  Future<void> delete(String id);

  /// Macht ein Archivieren rückgängig (Undo nach einem Wisch).
  Future<void> restore(String id);

  /// Berechnet die User-Stats für Profil + Impact-Seite.
  Future<UserStats> fetchStats();
}

/// Supabase-gestützte Umsetzung von [PantryRepository].
///
/// Der [SupabaseClient] wird injiziert; die Aggregation der Statistik ist an
/// den reinen [UserStatsCalculator] delegiert (SRP) — dieses Repository
/// kümmert sich nur um Laden, Mappen und Schreiben.
class SupabasePantryRepository implements PantryRepository {
  SupabasePantryRepository(
    this._client, {
    UserStatsCalculator statsCalculator = const UserStatsCalculator(),
  }) : _statsCalculator = statsCalculator;

  final SupabaseClient _client;
  final UserStatsCalculator _statsCalculator;

  static const _table = 'pantry_items';

  /// Live-Stream aller Items des aktuellen Users, sortiert nach Ablaufdatum.
  /// `null`-Ablaufdaten landen am Ende.
  @override
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

  @override
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
  @override
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

  /// Archiviert ein Item mit Grund. Echtes Löschen passiert nicht mehr.
  @override
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
  @override
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
  @override
  Future<void> updateExpiry(String id, DateTime? expiresAt) async {
    await _client.from(_table).update({
      'expires_at': expiresAt?.toIso8601String().split('T').first,
    }).eq('id', id);
  }

  /// Backwards-kompatibler Alias — wird vom Dismissible-Wisch aufgerufen.
  /// Default-Grund: 'discarded'.
  @override
  Future<void> delete(String id) => archive(id, status: 'discarded');

  /// Macht ein Archivieren rückgängig (für den Undo nach einem Wisch).
  @override
  Future<void> restore(String id) async {
    await _client.from(_table).update({
      'status': 'active',
      'removed_at': null,
    }).eq('id', id);
  }

  /// Lädt die rohen Stats-Daten und überlässt die Aggregation dem
  /// [UserStatsCalculator].
  @override
  Future<UserStats> fetchStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const UserStats();

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

    return _statsCalculator.compute(
      inPantry: activeRes.count,
      now: DateTime.now(),
      consumed: (consumedRows as List).map((row) {
        final m = row as Map<String, dynamic>;
        final co2 = m['co2_kg'];
        return ConsumedItem(
          category: m['category'] as String? ?? 'Sonstiges',
          quantity: m['quantity'] as String?,
          co2Kg: co2 is num ? co2.toDouble() : null,
          expiresAt: m['expires_at'] != null
              ? DateTime.tryParse(m['expires_at'] as String)
              : null,
          removedAt: DateTime.tryParse(m['removed_at'] as String? ?? ''),
        );
      }).toList(),
      wasted: (wastedRows as List).map((row) {
        final m = row as Map<String, dynamic>;
        return WastedItem(
          quantity: m['quantity'] as String?,
          removedAt: DateTime.tryParse(m['removed_at'] as String? ?? ''),
        );
      }).toList(),
    );
  }
}
