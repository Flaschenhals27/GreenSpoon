import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../domain/scanned_product.dart';
import '../providers/scanner_providers.dart';
import 'scan_review_sheet.dart';

/// Kamera-View mit Barcode-Erkennung.
///
/// Workflow:
/// 1. mobile_scanner liefert einen Barcode
/// 2. Open Food Facts wird abgefragt
/// 3. ScanReviewSheet öffnet sich (bestätigen/anpassen → speichern)
/// 4. Nach Speichern → Scanner bleibt offen für nächsten Scan
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _processing = false;
  String? _lastBarcode;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kamera bei Hintergrund anhalten, sonst hängt sie sich auf manchen
    // Geräten auf.
    if (state == AppLifecycleState.resumed) {
      _controller.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    // Doppel-Scans desselben Codes innerhalb von 2 s ignorieren.
    final now = DateTime.now();
    if (code == _lastBarcode &&
        now.difference(_lastScanAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastBarcode = code;
    _lastScanAt = now;

    setState(() => _processing = true);
    await _controller.stop();

    try {
      final svc = ref.read(openFoodFactsProvider);
      final product = await svc.lookup(code) ?? ScannedProduct.unknown(code);

      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ScanReviewSheet(product: product),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lookup fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        await _controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, controller) => _CameraError(error: error),
          ),

          // Dunkles Overlay mit Reticle
          const _ScanReticle(),

          // Top-Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  _StatusPill(processing: _processing),
                  const Spacer(),
                  _RoundIconButton(
                    icon: Icons.flash_on,
                    onTap: () => _controller.toggleTorch(),
                  ),
                ],
              ),
            ),
          ),

          // Hint unten
          Positioned(
            bottom: 56,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _processing ? 'Suche Produktdaten…' : 'Halte den Barcode in den Rahmen.',
                style: GSTypography.body(
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _ScanReticle extends StatelessWidget {
  const _ScanReticle();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 280,
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 60,
                spreadRadius: 1000,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.processing});
  final bool processing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: GSColors.primaryLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            processing ? 'Wird verarbeitet' : 'Suche Barcode…',
            style: GSTypography.body(color: Colors.white, size: 12),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined,
              color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          Text(
            'Kamera nicht verfügbar',
            style: GSTypography.headline(color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'Bitte erlaube den Kamera-Zugriff in den Geräte-Einstellungen.'
                : error.errorDetails?.message ?? 'Unbekannter Fehler.',
            textAlign: TextAlign.center,
            style: GSTypography.body(
              color: Colors.white.withValues(alpha: 0.7),
              size: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}