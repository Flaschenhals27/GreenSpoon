import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/scanned_product.dart';

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

    return ScannedProduct(
      barcode: barcode,
      name: finalName,
      brand: (p['brands'] as String?)?.split(',').first.trim(),
      quantity: (p['quantity'] as String?)?.trim(),
      category: _mapCategory(p['categories_tags']),
      imageUrl: p['image_small_url'] as String?,
      emoji: _emojiFor(finalName, p['categories_tags']),
    );
  }

  /// Mappt Open-Food-Facts-Kategorien auf unsere App-Kategorien.
  String _mapCategory(dynamic tags) {
    if (tags is! List) return 'Sonstiges';
    final flat = tags.whereType<String>().join(' ').toLowerCase();

    if (flat.contains('dairy') || flat.contains('milk') ||
        flat.contains('cheese') || flat.contains('yogurt')) {
      return 'Milchprodukte';
    }
    if (flat.contains('vegetable')) return 'Gemüse';
    if (flat.contains('fruit')) return 'Obst';
    if (flat.contains('meat') || flat.contains('fish') ||
        flat.contains('seafood')) return 'Fleisch & Fisch';
    if (flat.contains('pasta') || flat.contains('rice') ||
        flat.contains('cereal')) return 'Pasta & Reis';
    if (flat.contains('bread') || flat.contains('bakery')) {
      return 'Brot & Backwaren';
    }
    if (flat.contains('frozen')) return 'Tiefkühl';
    if (flat.contains('beverage') || flat.contains('drink') ||
        flat.contains('water')) return 'Getränke';
    return 'Sonstiges';
  }

  /// Sehr simple Emoji-Heuristik basierend auf Name/Tags.
  String _emojiFor(String name, dynamic tags) {
    final n = name.toLowerCase();
    final flat = tags is List
        ? tags.whereType<String>().join(' ').toLowerCase()
        : '';

    if (n.contains('milch') || flat.contains('milk')) return '🥛';
    if (n.contains('käse') || flat.contains('cheese')) return '🧀';
    if (n.contains('joghurt') || flat.contains('yogurt')) return '🥣';
    if (n.contains('ei') && !n.contains('eis')) return '🥚';
    if (n.contains('tomat')) return '🍅';
    if (n.contains('apfel') || n.contains('apple')) return '🍎';
    if (n.contains('banane') || n.contains('banana')) return '🍌';
    if (n.contains('brot') || flat.contains('bread')) return '🍞';
    if (n.contains('pasta') || n.contains('spaghetti') ||
        n.contains('nudel')) return '🍝';
    if (n.contains('reis')) return '🌾';
    if (n.contains('öl') || n.contains('oil')) return '🫒';
    if (n.contains('honig')) return '🍯';
    if (flat.contains('vegetable')) return '🥬';
    if (flat.contains('fruit')) return '🍇';
    if (flat.contains('meat')) return '🥩';
    if (flat.contains('fish')) return '🐟';
    if (flat.contains('beverage')) return '🥤';
    return '📦';
  }

  void dispose() => _client.close();
}