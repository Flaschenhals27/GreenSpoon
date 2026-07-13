import 'package:flutter/foundation.dart';

import '../../pantry/domain/pantry_categories.dart';

@immutable
class ScannedProduct {
  const ScannedProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.quantity,
    required this.category,
    this.imageUrl,
    required this.emoji,
    this.co2PerKg,
  });

  final String barcode;
  final String name;
  final String? brand;
  final String? quantity;
  final String category;
  final String? imageUrl;
  final String emoji;
  final double? co2PerKg; // kg CO₂ pro kg Produkt, aus Open Food Facts

  /// Stub für unbekannten Barcode — User füllt die Felder selbst aus.
  factory ScannedProduct.unknown(String barcode) => ScannedProduct(
        barcode: barcode,
        name: '',
        category: kFallbackCategory,
        emoji: '📦',
      );
}
