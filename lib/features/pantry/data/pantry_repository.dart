import 'package:supabase_flutter/supabase_flutter.dart';

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
    // Filtern auf der Client-Seite, weil .stream() nur EIN .eq akzeptiert
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
    });
  }

  /// Item hinzufügen.
  Future<PantryItem> add({
    required String name,
    String? brand,
    String? quantity,
    required String category,
    String? barcode,
    required String emoji,
    DateTime? expiresAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Nicht eingeloggt.');
    }

    final inserted = await _client.from(_table).insert({
      'user_id': userId,
      'name': name,
      'brand': brand,
      'quantity': quantity,
      'category': category,
      'barcode': barcode,
      'emoji': emoji,
      'expires_at': expiresAt?.toIso8601String().split('T').first,
    }).select().single();

    return PantryItem.fromJson(inserted);
  }

  /// Item löschen.
  /// Archiviert ein Item mit Grund. Echtes Löschen passiert nicht mehr.
  Future<void> archive(String id, {required String status}) async {
    await _client.from(_table).update({
      'status': status,
      'removed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Backwards-kompatibler Alias — wird vom Dismissible-Wisch aufgerufen.
  /// Default-Grund: 'discarded'.
  Future<void> delete(String id) => archive(id, status: 'discarded');

  /// Berechnet die User-Stats für den Profil-Screen.
  Future<UserStats> fetchStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const UserStats();

    // 1. Aktuelle Vorrat-Größe
    final activeRes = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'active')
        .count();

    // 2. Diese Woche gekocht (consumed in letzten 7 Tagen)
    final weekAgo =
        DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();

    final consumedWeekRes = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'consumed')
        .gte('removed_at', weekAgo)
        .count();

    // 3. Insgesamt gerettet (consumed total)
    final consumedTotalRes = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'consumed')
        .count();

    return UserStats(
      inPantry: activeRes.count,
      cookedThisWeek: consumedWeekRes.count,
      rescued: consumedTotalRes.count,
    );
  }
}

class UserStats {
  const UserStats({
    this.inPantry = 0,
    this.cookedThisWeek = 0,
    this.rescued = 0,
  });
  final int inPantry;
  final int cookedThisWeek;
  final int rescued;
}