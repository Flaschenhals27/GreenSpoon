import 'package:flutter/foundation.dart';

/// Ein vom Foto-Scan erkanntes Lebensmittel, inkl. Abgleich mit dem
/// vorhandenen Vorrat (neu vs. schon da).
@immutable
class RecognizedGrocery {
  const RecognizedGrocery({
    required this.name,
    required this.category,
    required this.emoji,
    this.quantity,
    this.expiresAt,
    required this.isNew,
    this.matchedName,
  });

  final String name;
  final String category;
  final String emoji;
  final String? quantity;

  /// Geschätztes Ablaufdatum (heute + Haltbarkeit). null = lange haltbar
  /// (Salz, Mehl …) → kein Datum-Tracking.
  final DateTime? expiresAt;

  /// true = im Vorrat noch nicht vorhanden, false = passt zu [matchedName].
  final bool isNew;

  /// Name des passenden Vorrats-Items, falls [isNew] == false.
  final String? matchedName;

  RecognizedGrocery copyWith({
    String? name,
    String? category,
    String? emoji,
    Object? quantity = _sentinel,
    Object? expiresAt = _sentinel,
    bool? isNew,
    Object? matchedName = _sentinel,
  }) {
    return RecognizedGrocery(
      name: name ?? this.name,
      category: category ?? this.category,
      emoji: emoji ?? this.emoji,
      quantity: quantity == _sentinel ? this.quantity : quantity as String?,
      expiresAt:
          expiresAt == _sentinel ? this.expiresAt : expiresAt as DateTime?,
      isNew: isNew ?? this.isNew,
      matchedName:
          matchedName == _sentinel ? this.matchedName : matchedName as String?,
    );
  }

  static const _sentinel = Object();
}
