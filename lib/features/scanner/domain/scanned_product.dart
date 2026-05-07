import 'package:flutter/foundation.dart';

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
  });

  final String barcode;
  final String name;
  final String? brand;
  final String? quantity;
  final String category;
  final String? imageUrl;
  final String emoji;

  /// Stub für unbekannten Barcode — User füllt die Felder selbst aus.
  factory ScannedProduct.unknown(String barcode) => ScannedProduct(
        barcode: barcode,
        name: '',
        category: 'Sonstiges',
        emoji: '📦',
      );
}