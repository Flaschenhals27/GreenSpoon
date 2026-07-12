import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_tone.dart';
import '../../../core/theme/gs_typography.dart';
import '../domain/scanned_product.dart';
import '../providers/scanner_providers.dart';
import 'mhd_scanner_screen.dart';
import 'scan_review_sheet.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  bool _torchOn = false;

  /// Anzahl der in dieser Session hinzugefügten Produkte (Serien-Scan).
  int _addedCount = 0;

  /// Vorab gescanntes MHD („MHD zuerst"): Wer den Aufdruck gerade in der
  /// Hand hat, scannt erst das Datum und dann den Barcode — der MHD-Schritt
  /// nach dem Barcode wird dann übersprungen.
  DateTime? _pendingExpiry;

  /// Debounce für den Serien-Scan: Nach dem Review liegt derselbe Barcode
  /// oft noch im Bild — ohne Sperre würde er sich sofort erneut auslösen.
  String? _lastCode;
  DateTime? _lastCodeAt;

  bool _isDuplicateScan(String code) {
    final at = _lastCodeAt;
    return code == _lastCode &&
        at != null &&
        DateTime.now().difference(at) < const Duration(seconds: 3);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String code) async {
    if (_processing || _isDuplicateScan(code)) return;
    // „Getroffen!" — der Moment, in dem der Barcode erkannt wurde,
    // ist sonst nur am Statustext ablesbar.
    HapticFeedback.mediumImpact();
    setState(() => _processing = true);
    await _controller.stop();

    ScannedProduct? product;
    try {
      product = await ref.read(openFoodFactsProvider).lookup(code);
    } catch (_) {
      // Network error or timeout — proceed with empty product
    }

    // Unmounted ⇒ dispose() hat den Controller schon freigegeben —
    // ein start() darauf würde werfen.
    if (!mounted) return;

    final scanned = product ??
        ScannedProduct(
          barcode: code,
          name: '',
          brand: null,
          quantity: null,
          category: 'Sonstiges',
          emoji: '📦',
        );

    // MHD: Wurde es schon vorab gescannt („MHD zuerst"), den Schritt
    // überspringen. Sonst direkt im Anschluss scannen — ohne Extra-Tap im
    // Review-Sheet. Gibt null zurück, wenn der User abbricht/überspringt;
    // das Datum lässt sich im Review-Sheet weiterhin manuell setzen.
    DateTime? expiry = _pendingExpiry;
    if (expiry == null) {
      try {
        expiry = await Navigator.of(context).push<DateTime>(
          MaterialPageRoute(builder: (_) => const MhdScannerScreen()),
        );
      } catch (_) {
        // Scanner unerwartet geschlossen — ohne Datum weiter.
      }
    }

    if (!mounted) return;

    // Liefert bei Erfolg den gespeicherten Produktnamen, sonst null.
    String? savedName;
    try {
      savedName = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            ScanReviewSheet(product: scanned, prefilledExpiry: expiry),
      );
    } catch (_) {
      // Sheet closed unexpectedly
    }

    if (!mounted) return;

    // Sperr-Fenster ab JETZT (Sheet zu): der eben behandelte Barcode
    // liegt vermutlich noch im Bild. Ein zweites identisches Produkt
    // lässt sich nach 3 Sekunden ganz normal scannen.
    _lastCode = code;
    _lastCodeAt = DateTime.now();

    // Serien-Scan: Nach dem Speichern bleibt der Scanner offen — beim
    // Wocheneinkauf entfällt so der komplette Neueinstieg pro Produkt
    // (Scan-Button → Sheet → „Einzeln scannen" → …). Raus geht's über
    // den Zurück-Button, der Zähler unten zeigt den Fortschritt.
    if (savedName != null) {
      _addedCount++;
      // Das vorab gescannte MHD gehörte zu genau diesem Produkt.
      _pendingExpiry = null;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('„$savedName" hinzugefügt — nächster Barcode?'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
    setState(() => _processing = false);
    await _controller.start();
  }

  /// „MHD zuerst": öffnet den MHD-Scanner vorab. Das erkannte Datum wird
  /// gemerkt und beim nächsten Barcode direkt übernommen — praktisch, wenn
  /// man den Aufdruck gerade vor der Linse hat und nicht erst umdrehen will.
  Future<void> _scanMhdFirst() async {
    if (_processing) return;
    setState(() => _processing = true);
    await _controller.stop();
    if (!mounted) return;

    DateTime? picked;
    try {
      picked = await Navigator.of(context).push<DateTime>(
        MaterialPageRoute(builder: (_) => const MhdScannerScreen()),
      );
    } catch (_) {
      // Scanner unerwartet geschlossen — ohne Datum weiter.
    }

    if (!mounted) return;
    setState(() {
      if (picked != null) _pendingExpiry = picked;
      _processing = false;
    });
    await _controller.start();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final tone = GSTone.of(context);
    final inkColor = tone.ink;
    final muteColor = tone.inkMute;
    final bgColor = tone.bg;
    final surfaceColor = tone.surface;
    final lineColor = tone.line;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top-Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(
                    icon: Icons.chevron_left,
                    tooltip: 'Zurück',
                    onTap: () => Navigator.of(context).pop(),
                    surfaceColor: surfaceColor,
                    inkColor: inkColor,
                    lineColor: lineColor,
                  ),
                  _CircleButton(
                    icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                    tooltip:
                        _torchOn ? 'Blitz ausschalten' : 'Blitz einschalten',
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await _controller.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                    surfaceColor: surfaceColor,
                    inkColor: inkColor,
                    lineColor: lineColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Eyebrow + Headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SCANNEN', style: GSTypography.label(color: muteColor)),
                  const SizedBox(height: 6),
                  Text(
                    'Barcode finden',
                    style: GSTypography.headline(color: inkColor, size: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Kamera-Box
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 5 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _controller,
                            onDetect: (capture) {
                              final code =
                                  capture.barcodes.firstOrNull?.rawValue;
                              if (code != null && code.isNotEmpty) {
                                _handleBarcode(code);
                              }
                            },
                          ),
                          // Reticle-Rahmen
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: inkColor.withValues(alpha: 0.85),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          // Status-Pille mittig
                          IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: GSColors.primaryMid,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _processing
                                          ? 'Suche Produkt …'
                                          : 'Suche Barcode …',
                                      style: GSTypography.body(
                                        color: GSColors.cream,
                                        size: 13,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Hilfetext + Serien-Scan-Ausstieg
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Halte den Barcode in den Rahmen.',
                    textAlign: TextAlign.center,
                    style: GSTypography.italicCaption(color: muteColor)
                        .copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  // Flexible Reihenfolge: Wer das MHD gerade vor der Linse
                  // hat, scannt es zuerst — der Chip zeigt das gemerkte
                  // Datum, das X verwirft es wieder.
                  if (_pendingExpiry == null)
                    TextButton.icon(
                      onPressed: _processing ? null : _scanMhdFirst,
                      icon: Icon(
                        Icons.event_outlined,
                        size: 18,
                        color: tone.primary,
                      ),
                      label: Text(
                        'MHD zuerst scannen',
                        style: GSTypography.body(
                          color:
                              tone.primary,
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: (tone.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 16,
                            color:
                                tone.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'MHD gemerkt: ${_formatDate(_pendingExpiry!)}',
                            style: GSTypography.body(
                              color: tone.primary,
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Tooltip(
                            message: 'Gemerktes MHD verwerfen',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () =>
                                  setState(() => _pendingExpiry = null),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: muteColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Sobald etwas hinzugefügt wurde, gibt es einen klaren
                  // „Fertig"-Ausstieg mit Zähler — der Zurück-Pfeil bleibt
                  // als Alternative.
                  if (_addedCount > 0) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(220, 48),
                      ),
                      child: Text(
                        _addedCount == 1
                            ? 'Fertig · 1 Produkt'
                            : 'Fertig · $_addedCount Produkte',
                        style: GSTypography.body(
                          color: GSColors.cream,
                          size: 14.5,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.surfaceColor,
    required this.inkColor,
    required this.lineColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color surfaceColor;
  final Color inkColor;
  final Color lineColor;

  /// Long-Press-Tooltip; dient gleichzeitig als Screenreader-Label
  /// für den ansonsten stummen Icon-Button.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: surfaceColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: lineColor),
          ),
          child: Icon(icon, color: inkColor, size: 22),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
