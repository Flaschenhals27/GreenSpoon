import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';

import '../pantry/domain/pantry_item.dart';

/// Versorgt das Android-Homescreen-Widget mit Daten (bei jeder
/// Vorrats-Änderung); auf iOS bis zur WidgetKit-Extension ein No-op.
class PantryWidgetUpdater {
  PantryWidgetUpdater._();

  /// Muss zum Klassennamen des Android-Receivers passen.
  static const _androidProvider = 'GreenSpoonWidgetProvider';

  static Future<void> update(List<PantryItem> items) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final expiring = items.where((i) => i.daysUntilExpiry != null).toList()
        ..sort((a, b) => a.daysUntilExpiry!.compareTo(b.daysUntilExpiry!));
      final soon = expiring.where((i) => i.daysUntilExpiry! <= 3).toList();

      final String title;
      final String body;
      if (soon.isEmpty) {
        title = 'VORRAT';
        body = expiring.isEmpty
            ? 'Alles im grünen Bereich 🌿'
            : 'Nichts fällig — als Nächstes: '
                '${expiring.first.name} (${_dayLabel(expiring.first.daysUntilExpiry!)})';
      } else {
        title = soon.length == 1
            ? '1 PRODUKT LÄUFT BALD AB'
            : '${soon.length} PRODUKTE LAUFEN BALD AB';
        body = soon
            .take(3)
            .map(
              (i) => '${i.emoji} ${i.name} · ${_dayLabel(i.daysUntilExpiry!)}',
            )
            .join('\n');
      }

      await HomeWidget.saveWidgetData<String>('widget_title', title);
      await HomeWidget.saveWidgetData<String>('widget_body', body);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (_) {
      // Widget-Updates dürfen die App nie stören (z.B. Widget nicht
      // platziert oder Plugin auf der Plattform nicht verfügbar).
    }
  }

  static String _dayLabel(int days) {
    if (days < 0) return 'abgelaufen';
    if (days == 0) return 'heute';
    if (days == 1) return 'morgen';
    return 'in $days Tagen';
  }
}
