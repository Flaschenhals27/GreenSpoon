import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../pantry/domain/shelf_life.dart';
import '../domain/recognized_grocery.dart';
import 'product_emoji.dart';

/// Vertrag für den Foto-Scan eines Einkaufs. Konsumenten hängen nur an dieser
/// Abstraktion (DIP).
abstract interface class GroceryScanService {
  /// Sendet [imageBytes] an die Erkennung und liefert die erkannten
  /// Lebensmittel. Wirft [GroceryScanException] bei Problemen.
  Future<List<RecognizedGrocery>> scan(
    Uint8List imageBytes, {
    String mimeType,
  });
}

/// Supabase-gestützte Umsetzung: spricht mit der Edge Function
/// `scan-groceries`. Schickt ein Foto und bekommt eine Liste erkannter
/// Lebensmittel zurück (inkl. Vorrats-Abgleich). Der [SupabaseClient] wird
/// injiziert.
class SupabaseGroceryScanService implements GroceryScanService {
  SupabaseGroceryScanService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RecognizedGrocery>> scan(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final response = await _client.functions.invoke(
        'scan-groceries',
        method: HttpMethod.post,
        body: {
          'image': base64Encode(imageBytes),
          'mimeType': mimeType,
        },
      );

      if (response.status != 200) {
        if (response.status == 502 ||
            response.status == 503 ||
            response.status == 504 ||
            response.status == 500) {
          throw const GroceryScanException(GroceryScanError.aiDown);
        }
        throw GroceryScanException(
          GroceryScanError.unknown,
          details: 'Status ${response.status}',
        );
      }

      final data = response.data;
      if (data is! Map || data['items'] is! List) {
        throw const GroceryScanException(
          GroceryScanError.unknown,
          details: 'Antwortformat unerwartet.',
        );
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return (data['items'] as List)
          .whereType<Map>()
          .map((raw) => _fromJson(raw, today))
          .toList();
    } on SocketException catch (e) {
      throw GroceryScanException(GroceryScanError.offline, details: e.message);
    } on FunctionException catch (e) {
      if (e.status == 502 ||
          e.status == 503 ||
          e.status == 504 ||
          e.status == 500) {
        throw const GroceryScanException(GroceryScanError.aiDown);
      }
      throw GroceryScanException(
        GroceryScanError.unknown,
        details: e.details?.toString() ?? e.reasonPhrase,
      );
    } on GroceryScanException {
      rethrow;
    } catch (e) {
      throw GroceryScanException(
        GroceryScanError.unknown,
        details: e.toString(),
      );
    }
  }

  RecognizedGrocery _fromJson(Map raw, DateTime today) {
    final name = (raw['name'] as String?)?.trim();
    final category = raw['category'] as String? ?? 'Sonstiges';
    final isNew = (raw['status'] as String?) != 'schon_da';
    final resolvedName = (name == null || name.isEmpty) ? 'Unbekannt' : name;

    // Haltbarkeit: KI-Schätzung zuerst; liefert sie nichts, greift die
    // lokale ShelfLife-Heuristik. So bekommt Frischware auch dann ein
    // Datum (→ Erinnerung + Impact-Statistik), wenn das Modell das Feld
    // mal weglässt. null = lange haltbar, bewusst kein Tracking.
    final days = (raw['expiry_days'] as num?)?.toInt();
    final expiresAt = days != null
        ? today.add(Duration(days: days))
        : ShelfLife.estimateExpiry(
            name: resolvedName,
            category: category,
            from: today,
          );

    return RecognizedGrocery(
      name: resolvedName,
      category: category,
      emoji: ProductEmojiResolver.resolve(name: name, category: category),
      quantity: (raw['quantity'] as String?)?.trim().isEmpty ?? true
          ? null
          : (raw['quantity'] as String).trim(),
      expiresAt: expiresAt,
      isNew: isNew,
      matchedName: raw['matched_name'] as String?,
    );
  }
}

enum GroceryScanError {
  /// Kein Internet.
  offline,

  /// Gemini/Edge Function nicht erreichbar oder Antwort unbrauchbar.
  aiDown,

  /// Sonstiges.
  unknown,
}

class GroceryScanException implements Exception {
  const GroceryScanException(this.type, {this.details});
  final GroceryScanError type;
  final String? details;

  @override
  String toString() => 'GroceryScanException(${type.name}): ${details ?? ""}';
}
