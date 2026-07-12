import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die drei Tabs der MainShell.
enum ShellTab { pantry, recipes, profile }

/// Aktiver Tab der MainShell.
///
/// Über den Notifier kann jede Stelle der App gezielt einen Tab öffnen
/// (z.B. Notification-Tap → Rezepte, CTA im leeren Vorrat → Profil),
/// ohne eine Referenz auf die Shell zu kennen — lose Kopplung über
/// zentralen State statt globaler ValueNotifier.
final shellTabProvider =
    NotifierProvider<ShellTabNotifier, ShellTab>(ShellTabNotifier.new);

class ShellTabNotifier extends Notifier<ShellTab> {
  @override
  ShellTab build() => ShellTab.pantry;

  void open(ShellTab tab) => state = tab;
}

/// Signal an die MainShell, das Scan-Sheet zu öffnen.
///
/// Zähler statt bool, damit jedes Anstoßen ein neues Event auslöst —
/// auch wenn das Sheet zwischendurch geschlossen wurde.
final scanRequestProvider =
    NotifierProvider<ScanRequestNotifier, int>(ScanRequestNotifier.new);

class ScanRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}
