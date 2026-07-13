import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Die drei Tabs der MainShell.
enum ShellTab { pantry, recipes, profile }

/// Aktiver Tab der MainShell — jede Stelle der App kann darüber einen Tab
/// öffnen, ohne die Shell zu kennen (lose Kopplung).
final shellTabProvider =
    NotifierProvider<ShellTabNotifier, ShellTab>(ShellTabNotifier.new);

class ShellTabNotifier extends Notifier<ShellTab> {
  @override
  ShellTab build() => ShellTab.pantry;

  void open(ShellTab tab) => state = tab;
}

/// Signal an die MainShell, das Scan-Sheet zu öffnen — Zähler statt bool,
/// damit jedes Anstoßen ein neues Event auslöst.
final scanRequestProvider =
    NotifierProvider<ScanRequestNotifier, int>(ScanRequestNotifier.new);

class ScanRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}
