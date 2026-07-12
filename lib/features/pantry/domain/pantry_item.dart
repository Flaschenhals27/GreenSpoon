import 'package:flutter/foundation.dart';

import 'quantity_utils.dart';

@immutable
class PantryItem {
  const PantryItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.emoji,
    this.brand,
    this.quantity,
    this.barcode,
    this.expiresAt,
    required this.createdAt,
    this.co2Kg,
  });

  final String id;
  final String userId;
  final String name;
  final String? brand;
  final String? quantity;
  final String category;
  final String? barcode;
  final String emoji;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final double? co2Kg;

  /// Tage bis Ablauf (negative Werte = bereits abgelaufen, null = kein MHD).
  int? get daysUntilExpiry {
    if (expiresAt == null) return null;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final expDate = DateTime(expiresAt!.year, expiresAt!.month, expiresAt!.day);
    return expDate.difference(todayDate).inDays;
  }

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    final rawQuantity = json['quantity'] as String?;
    return PantryItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      // Beim Lesen normalisieren („10pcs" → „10 Stück"): deckt auch
      // Alt-Bestände ab, ohne die DB anfassen zu müssen.
      quantity: rawQuantity == null ? null : normalizeQuantity(rawQuantity),
      category: json['category'] as String? ?? 'Sonstiges',
      barcode: json['barcode'] as String?,
      emoji: json['emoji'] as String? ?? '📦',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      co2Kg: (json['co2_kg'] as num?)?.toDouble(),
    );
  }

  /// JSON für INSERT (ohne `id`/`created_at` — die setzt Postgres).
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'name': name,
      'brand': brand,
      'quantity': quantity,
      'category': category,
      'barcode': barcode,
      'emoji': emoji,
      'expires_at': expiresAt?.toIso8601String().split('T').first,
      'co2_kg': co2Kg,
    };
  }
}

/// Schlanker Entwurf für einen Batch-Insert (z.B. nach dem Foto-Scan eines
/// ganzen Einkaufs), bevor Postgres `id`/`created_at` vergibt.
@immutable
class PantryDraft {
  const PantryDraft({
    required this.name,
    this.brand,
    this.quantity,
    required this.category,
    this.barcode,
    required this.emoji,
    this.expiresAt,
    this.co2Kg,
  });

  final String name;
  final String? brand;
  final String? quantity;
  final String category;
  final String? barcode;
  final String emoji;
  final DateTime? expiresAt;
  final double? co2Kg;
}
