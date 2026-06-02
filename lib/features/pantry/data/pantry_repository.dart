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
    }).handleError((error) async {
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

    final inserted = await _client.from(_table).insert({
      'user_id': userId,
      'name': name,
      'brand': brand,
      'quantity': quantity,
      'category': category,
      'barcode': barcode,
      'emoji': emoji,
      'expires_at': expiresAt?.toIso8601String().split('T').first,
      'co2_kg': co2Kg,
    }).select().single().timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException('Speichern hat zu lange gedauert.'),
        );

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

  /// Ändert nur das MHD eines Items.
  Future<void> updateExpiry(String id, DateTime? expiresAt) async {
    await _client.from(_table).update({
      'expires_at': expiresAt?.toIso8601String().split('T').first,
    }).eq('id', id);
  }

  /// Backwards-kompatibler Alias — wird vom Dismissible-Wisch aufgerufen.
  /// Default-Grund: 'discarded'.
  Future<void> delete(String id) => archive(id, status: 'discarded');

    /// Berechnet die User-Stats für den Profil-Screen.
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
    final weekAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toUtc()
        .toIso8601String();

    final consumedWeekRes = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'consumed')
        .gte('removed_at', weekAgo)
        .count();

    // 3. Insgesamt gerettet (consumed total) — mit CO₂- und Kategorie-Daten
    //    für die Impact-Summen.
    final consumedRows = await _client
        .from(_table)
        .select('co2_kg, category, quantity')
        .eq('user_id', userId)
        .eq('status', 'consumed');

    final rescued = (consumedRows as List).length;

    double co2Total = 0;
    double eurTotal = 0;
    for (final row in consumedRows) {
      final map = row as Map<String, dynamic>;
      final co2 = map['co2_kg'];
      final category = map['category'] as String? ?? 'Sonstiges';
      final quantity = map['quantity'] as String?;

      // CO₂: gespeicherter Wert oder Schätzung als Fallback
      if (co2 is num) {
        co2Total += co2.toDouble();
      } else {
        co2Total += Co2Estimator.estimateCo2Kg(
          category: category,
          quantity: quantity,
        );
      }

      // Euro immer geschätzt (speichern wir nicht)
      eurTotal += Co2Estimator.estimatePriceEur(
        category: category,
        quantity: quantity,
      );
    }

    return UserStats(
      inPantry: activeRes.count,
      cookedThisWeek: consumedWeekRes.count,
      rescued: rescued,
      co2SavedKg: double.parse(co2Total.toStringAsFixed(1)),
      eurSaved: double.parse(eurTotal.toStringAsFixed(0)),
    );
  }
}

class UserStats {
  const UserStats({
    this.inPantry = 0,
    this.cookedThisWeek = 0,
    this.rescued = 0,
    this.co2SavedKg = 0,
    this.eurSaved = 0,
  });
  final int inPantry;
  final int cookedThisWeek;
  final int rescued;
  final double co2SavedKg;
  final double eurSaved;
}