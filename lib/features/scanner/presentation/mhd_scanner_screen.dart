import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../data/mhd_parser.dart';

/// Live-OCR-Scanner für MHD-Daten.
/// Gibt das gefundene Datum via Navigator.pop zurück.
class MhdScannerScreen extends StatefulWidget {
  const MhdScannerScreen({super.key});

  @override
  State<MhdScannerScreen> createState() => _MhdScannerScreenState();
}

class _MhdScannerScreenState extends State<MhdScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isProcessing = false;
  bool _torchOn = false;
  bool _streaming = false;
  bool _leaving = false;
  DateTime? _lastProcessAt;

  // Sticky match — wenn dasselbe Datum 4 Sekunden lang dominiert, wird's gewählt.
  DateTime? _stickyDate;
  DateTime? _stickySince;
  String _statusText = 'Halte den Aufdruck ins Bild …';

  // Häufigkeit der erkannten Daten
  final Map<DateTime, int> _candidateCounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    _leaving = true;
    _streaming = false;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  /// Stoppt den Bild-Stream sauber (idempotent) und kehrt mit dem Datum
  /// zurück. Schützt vor doppeltem pop und laufenden Frames nach dem Verlassen.
  Future<void> _finish(DateTime? date) async {
    if (_leaving) return;
    _leaving = true;
    if (_streaming) {
      _streaming = false;
      try {
        await _controller?.stopImageStream();
      } catch (_) {
        // Stream evtl. schon gestoppt — ignorieren.
      }
    }
    if (mounted) Navigator.of(context).pop(date);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _streaming = false;
      c.dispose();
    } else if (state == AppLifecycleState.resumed && !_leaving) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      back,
      // medium reicht für Text-OCR locker und entlastet Main-Thread/GC
      // deutlich gegenüber high (sonst Frame-Drops / gefühltes Einfrieren).
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    _controller = controller;
    await controller.initialize();
    if (!mounted || _leaving) return;
    setState(() {});
    await controller.startImageStream(_onFrame);
    _streaming = true;
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isProcessing || _leaving || !mounted) return;

    // Drossel: höchstens ~alle 500 ms OCR laufen lassen. Ohne das läuft
    // die Texterkennung auf JEDEM Frame und blockiert den Main-Thread
    // (ständige GC-Pausen → UI wirkt eingefroren).
    final now = DateTime.now();
    if (_lastProcessAt != null &&
        now.difference(_lastProcessAt!).inMilliseconds < 500) {
      return;
    }
    _lastProcessAt = now;
    _isProcessing = true;

    try {
      final input = _imageFromCamera(image, _controller!.description);
      if (input == null) return;

      final result = await _recognizer.processImage(input);
      final found = MhdParser.parseAll(result.text);

      // Häufigkeits-Voting
      for (final match in found) {
        _candidateCounts.update(match.date, (v) => v + 1, ifAbsent: () => 1);
      }

      DateTime? top;
      int topCount = 0;
      _candidateCounts.forEach((d, c) {
        if (c > topCount) {
          top = d;
          topCount = c;
        }
      });

      if (top != null) {
        if (_stickyDate != top) {
          _stickyDate = top;
          _stickySince = DateTime.now();
        }

        final stableFor =
            DateTime.now().difference(_stickySince!).inMilliseconds;
        if (stableFor >= 4000) {
          await _finish(_stickyDate);
          return;
        }

        if (mounted) {
          setState(() {
            _statusText =
                'Erkannt: ${_format(_stickyDate!)}  ·  übernimm es oder warte ${(4 - (stableFor / 1000)).clamp(0, 4).toStringAsFixed(0)}s';
          });
        }
      } else if (mounted) {
        setState(() => _statusText = 'Halte den Aufdruck ins Bild …');
      }
    } catch (_) {
      // OCR-Fehler ignorieren, einfach weitermachen
    } finally {
      _isProcessing = false;
    }
  }

  static String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// Zeigt die Kamera formatfüllend (BoxFit.cover), ohne sie zu verzerren.
  /// Ohne das presst [StackFit.expand] den Feed in die 5:4-Box und streckt ihn.
  Widget _coverPreview(CameraController c) {
    final preview = c.value.previewSize;
    if (preview == null) return CameraPreview(c);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        // previewSize ist in Landschafts-Orientierung → für Portrait drehen.
        child: SizedBox(
          width: preview.height,
          height: preview.width,
          child: CameraPreview(c),
        ),
      ),
    );
  }

  InputImage? _imageFromCamera(CameraImage image, CameraDescription cam) {
    final rotation =
        InputImageRotationValue.fromRawValue(cam.sensorOrientation);
    if (rotation == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final bgColor = isDark ? GSColors.bgAppDark : GSColors.bgApp;
    final surfaceColor = isDark ? GSColors.surfaceDark : GSColors.surface;
    final lineColor = isDark ? GSColors.lineDark : GSColors.line;

    final c = _controller;

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
                    onTap: () => _finish(null),
                    surfaceColor: surfaceColor,
                    inkColor: inkColor,
                    lineColor: lineColor,
                  ),
                  _CircleButton(
                    icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                    onTap: () async {
                      if (c == null) return;
                      final newValue = !_torchOn;
                      await c.setFlashMode(
                          newValue ? FlashMode.torch : FlashMode.off);
                      setState(() => _torchOn = newValue);
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
                  Text('MHD-SCAN', style: GSTypography.label(color: muteColor)),
                  const SizedBox(height: 6),
                  Text(
                    'Datum erkennen',
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
                          if (c != null && c.value.isInitialized)
                            _coverPreview(c)
                          else
                            Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                color: GSColors.primaryMid,
                              ),
                            ),
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
                          IgnorePointer(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _statusText,
                                    style: GSTypography.body(
                                      color: GSColors.cream,
                                      size: 12.5,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
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
            // Manueller Übernehmen-Button (sobald ein Datum erkannt wurde) —
            // garantierter Ausweg, kein Warten auf die 4s-Auto-Bestätigung.
            // Darunter immer ein „MHD überspringen", falls kein Datum
            // aufgedruckt ist oder man es später manuell setzen will.
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_stickyDate != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _finish(_stickyDate),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          backgroundColor: GSColors.primary,
                          foregroundColor: GSColors.cream,
                        ),
                        child: Text(
                          'Datum übernehmen · ${_format(_stickyDate!)}',
                          style: GSTypography.body(
                            color: GSColors.cream,
                            size: 14.5,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      'Halte den MHD-Aufdruck mittig in den Rahmen.',
                      textAlign: TextAlign.center,
                      style: GSTypography.italicCaption(color: muteColor)
                          .copyWith(fontSize: 14),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _finish(null),
                    child: Text(
                      'MHD überspringen',
                      style: GSTypography.body(
                        color: muteColor,
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
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
