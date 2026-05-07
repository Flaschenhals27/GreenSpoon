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
      final items = rows.map(PantryItem.fromJson).toList();
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
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}