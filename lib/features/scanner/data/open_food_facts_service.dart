import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/scanned_product.dart';
import 'product_emoji.dart';

/// Wrapper um die kostenlose Open Food Facts API.
///
/// Endpoint: https://world.openfoodfacts.org/api/v2/product/<barcode>.json
/// Kein API-Key, kein Auth nötig.
class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://world.openfoodfacts.org/api/v2/product';

  /// Sucht ein Produkt anhand des Barcodes.
  ///
  /// Liefert `null`, wenn das Produkt unbekannt ist (sehr häufig bei
  /// regionalen/Bio-Produkten — dann fallback auf manuelle Eingabe).
  Future<ScannedProduct?> lookup(String barcode) async {
    final uri = Uri.parse('$_base/$barcode.json'
        '?fields=product_name,product_name_de,brands,quantity,'
        'categories_tags,image_small_url,code');

    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['status'] != 1) return null; // Produkt unbekannt

    final p = body['product'] as Map<String, dynamic>?;
    if (p == null) return null;

    final name = (p['product_name_de'] as String?)?.trim();
    final fallbackName = (p['product_name'] as String?)?.trim();
    final finalName = (name != null && name.isNotEmpty)
        ? name
        : (fallbackName ?? '');

    if (finalName.isEmpty) return null;

    final category = _mapCategory(p['categories_tags']);

    return ScannedProduct(
      barcode: barcode,
      name: finalName,
      brand: (p['brands'] as String?)?.split(',').first.trim(),
      quantity: (p['quantity'] as String?)?.trim(),
      category: category,
      imageUrl: p['image_small_url'] as String?,
      emoji: ProductEmojiResolver.resolve(
        name: finalName,
        category: category,
      ),
    );
  }

  /// Mappt Open-Food-Facts-Kategorien auf unsere App-Kategorien.
  String _mapCategory(dynamic tags) {
    if (tags is! List) return 'Sonstiges';
    final flat = tags.whereType<String>().join(' ').toLowerCase();

    if (flat.contains('dairy') ||
        flat.contains('milk') ||
        flat.contains('cheese') ||
        flat.contains('yogurt')) {
      return 'Milchprodukte';
    }
    if (flat.contains('egg')) return 'Eier';
    if (flat.contains('vegetable')) return 'Gemüse';
    if (flat.contains('fruit')) return 'Obst';
    if (flat.contains('meat') ||
        flat.contains('fish') ||
        flat.contains('seafood')) {
      return 'Fleisch & Fisch';
    }
    if (flat.contains('pasta') ||
        flat.contains('rice') ||
        flat.contains('noodle')) {
      return 'Pasta & Reis';
    }
    if (flat.contains('cereal') ||
        flat.contains('breakfast') ||
        flat.contains('müsli') ||
        flat.contains('muesli') ||
        flat.contains('granola') ||
        flat.contains('oat')) {
      return 'Müsli & Cerealien';
    }
    if (flat.contains('bread') || flat.contains('bakery')) {
      return 'Brot & Backwaren';
    }
    if (flat.contains('frozen')) return 'Tiefkühl';
    if (flat.contains('beverage') ||
        flat.contains('drink') ||
        flat.contains('water') ||
        flat.contains('soda') ||
        flat.contains('juice') ||
        flat.contains('coffee') ||
        flat.contains('tea')) {
      return 'Getränke';
    }
    if (flat.contains('chocolate') ||
        flat.contains('candy') ||
        flat.contains('sweet') ||
        flat.contains('snack') ||
        flat.contains('biscuit') ||
        flat.contains('cookie') ||
        flat.contains('cake')) {
      return 'Süßes & Snacks';
    }
    if (flat.contains('spice') ||
        flat.contains('sauce') ||
        flat.contains('condiment') ||
        flat.contains('oil') ||
        flat.contains('vinegar') ||
        flat.contains('salt')) {
      return 'Gewürze & Saucen';
    }
    if (flat.contains('spread') ||
        flat.contains('honey') ||
        flat.contains('jam') ||
        flat.contains('marmalade') ||
        flat.contains('nutella')) {
      return 'Aufstriche';
    }
    if (flat.contains('canned') || flat.contains('preserve')) {
      return 'Konserven';
    }
    return 'Sonstiges';
  }

  void dispose() => _client.close();
}