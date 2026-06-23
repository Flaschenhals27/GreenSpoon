import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/gs_colors.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String code) async {
    if (_processing) return;
    setState(() => _processing = true);
    await _controller.stop();

    ScannedProduct? product;
    try {
      product = await ref.read(openFoodFactsProvider).lookup(code);
    } catch (_) {
      // Network error or timeout — proceed with empty product
    }

    if (!mounted) {
      await _controller.start();
      return;
    }

    final scanned = product ??
        ScannedProduct(
          barcode: code,
          name: '',
          brand: null,
          quantity: null,
          category: 'Sonstiges',
          emoji: '📦',
        );

    // Direkt im Anschluss das MHD scannen — ohne Extra-Tap im Review-Sheet.
    // Gibt null zurück, wenn der User den MHD-Scan abbricht/überspringt;
    // das Datum lässt sich im Review-Sheet weiterhin manuell setzen.
    DateTime? expiry;
    try {
      expiry = await Navigator.of(context).push<DateTime>(
        MaterialPageRoute(builder: (_) => const MhdScannerScreen()),
      );
    } catch (_) {
      // Scanner unerwartet geschlossen — ohne Datum weiter.
    }

    if (!mounted) return;

    bool? result;
    try {
      result = await showModalBottomSheet<bool>(
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

    if (result == true) {
      Navigator.of(context).pop();
    } else {
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final bgColor = isDark ? GSColors.bgAppDark : GSColors.bgApp;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

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
                    onTap: () => Navigator.of(context).pop(),
                    surfaceColor: surfaceColor,
                    inkColor: inkColor,
                    lineColor: lineColor,
                  ),
                  _CircleButton(
                    icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                    onTap: () async {
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
                                    horizontal: 14, vertical: 8,),
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
            // Hilfetext
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
              child: Text(
                'Halte den Barcode in den Rahmen.',
                textAlign: TextAlign.center,
                style: GSTypography.italicCaption(color: muteColor)
                    .copyWith(fontSize: 14),
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
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color surfaceColor;
  final Color inkColor;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return Material(
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
  }
}
