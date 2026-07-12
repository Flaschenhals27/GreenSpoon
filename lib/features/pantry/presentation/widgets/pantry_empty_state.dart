import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/gs_tone.dart';
import '../../../../core/theme/gs_typography.dart';
import '../../../shell/shell_providers.dart';

/// Leerer Zustand der Vorratsliste — Text passt sich an, je nachdem ob
/// eine Suche aktiv ist, ein Filter greift oder der Vorrat wirklich leer ist.
class PantryEmptyState extends ConsumerWidget {
  const PantryEmptyState({
    super.key,
    this.searching = false,
    this.showScanCta = false,
  });

  /// `true`, wenn gerade eine Suche aktiv ist — dann passt der
  /// Hinweis zur Suche statt zum Scannen.
  final bool searching;

  /// `true`, wenn der Vorrat komplett leer ist — dann führt ein CTA
  /// direkt in den Scan-Flow (Anschluss ans Onboarding).
  final bool showScanCta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = GSTone.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            showScanCta ? '🥬' : (searching ? '🔍' : '🌱'),
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 16),
          Text(
            showScanCta ? 'Dein Vorrat wartet' : 'Nichts gefunden',
            style: GSTypography.headline(color: tone.ink, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            showScanCta
                ? 'Scanne deinen ersten Einkauf — ab dann\nbehalten wir die Haltbarkeit im Blick.'
                : searching
                    ? 'Kein Treffer für deine Suche —\nprobier einen anderen Begriff.'
                    : 'Tipp auf "Scannen" oder probier\neinen anderen Filter.',
            textAlign: TextAlign.center,
            style: GSTypography.body(color: tone.inkMute, size: 13.5),
          ),
          if (showScanCta) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(scanRequestProvider.notifier).request(),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Erstes Produkt scannen'),
              style: FilledButton.styleFrom(minimumSize: const Size(230, 50)),
            ),
          ],
        ],
      ),
    );
  }
}
