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
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
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
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    _controller = controller;
    await controller.initialize();
    if (!mounted) return;
    setState(() {});
    await controller.startImageStream(_onFrame);
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isProcessing || !mounted) return;
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
          if (mounted) Navigator.of(context).pop(_stickyDate);
          return;
        }

        setState(() {
          _statusText =
              'Erkannt: ${_format(_stickyDate!)}  ·  bestätige in ${(4 - (stableFor / 1000)).clamp(0, 4).toStringAsFixed(0)}s';
        });
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
                    onTap: () => Navigator.of(context).pop(),
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
                            CameraPreview(c)
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
                                    color:
                                        Colors.black.withValues(alpha: 0.55),
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
            // Hilfetext
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
              child: Text(
                'Halte den MHD-Aufdruck mittig in den Rahmen.',
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