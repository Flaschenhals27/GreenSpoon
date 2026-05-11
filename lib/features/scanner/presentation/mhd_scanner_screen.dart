import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../data/mhd_parser.dart';

class MhdScannerScreen extends StatefulWidget {
  const MhdScannerScreen({super.key});

  @override
  State<MhdScannerScreen> createState() => _MhdScannerScreenState();
}

class _MhdScannerScreenState extends State<MhdScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _busy = false;
  DateTime _lastProcess = DateTime.fromMillisecondsSinceEpoch(0);
  String? _initError;
  bool _torchOn = false;

  /// Aktuelle Treffer + Zeitpunkt, an dem sie zuletzt gesehen wurden.
  /// Treffer bleiben bis zu _stickyDuration sichtbar, auch wenn nachfolgende
  /// Frames sie nicht mehr enthalten.
  final Map<DateTime, _StickyMatch> _sticky = {};
  static const _stickyDuration = Duration(seconds: 4);
  Timer? _pruneTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
    // Alle 500 ms abgelaufene Sticky-Treffer wegräumen.
    _pruneTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final before = _sticky.length;
      _sticky.removeWhere(
        (_, m) => now.difference(m.lastSeenAt) > _stickyDuration,
      );
      if (_sticky.length != before) setState(() {});
    });
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _initError = 'Keine Kamera gefunden.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.startImageStream(_onFrame);
      // Initialer Flash-Mode = off
      await controller.setFlashMode(FlashMode.off);
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _initError = 'Kamera-Init fehlgeschlagen: $e');
    }
  }

  Future<void> _toggleTorch() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      final next = _torchOn ? FlashMode.off : FlashMode.torch;
      await c.setFlashMode(next);
      setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Manche Geräte unterstützen torch im Image-Stream nicht — still ignorieren
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pruneTimer?.cancel();
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  Future<void> _onFrame(CameraImage image) async {
    final now = DateTime.now();
    if (_busy ||
        now.difference(_lastProcess) < const Duration(milliseconds: 200)) {
      return;
    }
    _busy = true;
    _lastProcess = now;

    try {
      final input = _toInputImage(image);
      if (input == null) return;

      final result = await _recognizer.processImage(input);
      final found = MhdParser.parseAll(result.text);

      if (found.isNotEmpty && mounted) {
        final seenAt = DateTime.now();
        var changed = false;
        for (final m in found) {
          final existing = _sticky[m.date];
          if (existing == null) {
            _sticky[m.date] = _StickyMatch(match: m, lastSeenAt: seenAt);
            changed = true;
          } else {
            _sticky[m.date] =
                _StickyMatch(match: existing.match, lastSeenAt: seenAt);
            // kein UI-Change nötig, nur Timestamp aktualisiert
          }
        }
        if (changed) setState(() {});
      }
    } catch (_) {
      // Frame-Fehler ignorieren — nächster Frame kommt sofort
    } finally {
      _busy = false;
    }
  }

  /// Wandelt ein CameraImage in ein InputImage für ML Kit.
  /// Konkateniert alle Planes — wichtig für vollständige Bildinformation.
  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      controller.description.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (format != InputImageFormat.nv21 &&
            format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.isEmpty) return null;

    // Alle Plane-Bytes zusammenfügen
    // Alle Plane-Bytes zusammenfügen
// Alle Plane-Bytes zusammenfügen
    final totalLength =
        image.planes.fold<int>(0, (sum, p) => sum + p.bytes.length);
    final bytes = Uint8List(totalLength);
    var offset = 0;
    for (final plane in image.planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void _accept(MhdMatch m) {
    Navigator.of(context).pop<DateTime>(m.date);
  }

  List<MhdMatch> get _orderedMatches {
    final list = _sticky.values.map((s) => s.match).toList();
    final now = DateTime.now();
    list.sort((a, b) {
      final aSoon = a.date.difference(now).inDays.abs();
      final bSoon = b.date.difference(now).inDays.abs();
      return aSoon.compareTo(bSoon);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography_outlined,
                      color: Colors.white70, size: 56),
                  const SizedBox(height: 16),
                  Text('Kamera nicht verfügbar',
                      style:
                          GSTypography.headline(color: Colors.white, size: 20)),
                  const SizedBox(height: 8),
                  Text(_initError!,
                      textAlign: TextAlign.center,
                      style: GSTypography.body(
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 13.5,
                      )),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Zurück',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final matches = _orderedMatches;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            CameraPreview(controller)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Overlay-Rahmen
          IgnorePointer(
            child: Center(
              child: Container(
                width: 300,
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 60,
                      spreadRadius: 1000,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top-Bar mit Back, Hint und Torch
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
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Halte das MHD in den Rahmen',
                        textAlign: TextAlign.center,
                        style:
                            GSTypography.body(color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                    active: _torchOn,
                    onTap: _toggleTorch,
                  ),
                ],
              ),
            ),
          ),

          // Bottom: Treffer
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: matches.isEmpty
                  ? const _Hint(key: ValueKey('hint'))
                  : _MatchesList(
                      key: const ValueKey('matches'),
                      matches: matches,
                      onTap: _accept,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────

class _StickyMatch {
  const _StickyMatch({required this.match, required this.lastSeenAt});
  final MhdMatch match;
  final DateTime lastSeenAt;
}

class _Hint extends StatelessWidget {
  const _Hint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Suche nach Datumsangaben…',
              style: GSTypography.body(
                color: Colors.white.withValues(alpha: 0.85),
                size: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchesList extends StatelessWidget {
  const _MatchesList({super.key, required this.matches, required this.onTap});
  final List<MhdMatch> matches;
  final ValueChanged<MhdMatch> onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy', 'de_DE');
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < matches.length && i < 3; i++)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onTap(matches[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: GSColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fmt.format(matches[i].date),
                            style: GSTypography.body(
                              color: Colors.white,
                              size: 16,
                              weight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'erkannt: "${matches[i].rawText}"',
                            style: GSTypography.body(
                              color: Colors.white.withValues(alpha: 0.6),
                              size: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white54, size: 14),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? GSColors.primary
              : Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}