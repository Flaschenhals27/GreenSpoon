import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../../../core/widgets/mascot.dart';
import '../data/grocery_scan_service.dart';
import '../providers/scanner_providers.dart';
import 'grocery_review_sheet.dart';

/// Fotografiert den restlichen Einkauf, schickt das Bild an die KI-Erkennung
/// und öffnet danach das Review-Sheet zum Übernehmen in den Vorrat.
class GroceryPhotoScreen extends ConsumerStatefulWidget {
  const GroceryPhotoScreen({super.key});

  @override
  ConsumerState<GroceryPhotoScreen> createState() => _GroceryPhotoScreenState();
}

class _GroceryPhotoScreenState extends ConsumerState<GroceryPhotoScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  bool _busy = false;
  bool _leaving = false;
  String _status = 'Richte die Kamera auf deinen Einkauf';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    _leaving = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed && !_leaving) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _initializing = false);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted || _leaving) return;
      setState(() => _initializing = false);
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _capture() async {
    final c = _controller;
    if (_busy || c == null || !c.value.isInitialized) return;
    setState(() {
      _busy = true;
      _status = 'Foto wird gemacht …';
    });

    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _status = 'Löffeli schaut sich deinen Einkauf an …');

      final items = await ref.read(groceryScanServiceProvider).scan(bytes);
      if (!mounted) return;

      final added = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => GroceryReviewSheet(items: items),
      );

      if (!mounted) return;
      if (added == true) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _busy = false;
          _status = 'Richte die Kamera auf deinen Einkauf';
        });
      }
    } on GroceryScanException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFor(e.type))),
      );
      setState(() {
        _busy = false;
        _status = 'Richte die Kamera auf deinen Einkauf';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Das Foto konnte nicht verarbeitet werden.')),
      );
      setState(() {
        _busy = false;
        _status = 'Richte die Kamera auf deinen Einkauf';
      });
    }
  }

  String _messageFor(GroceryScanError type) {
    switch (type) {
      case GroceryScanError.offline:
        return 'Keine Verbindung — die Erkennung braucht Internet.';
      case GroceryScanError.aiDown:
        return 'Die KI macht gerade Pause. Versuch es gleich nochmal.';
      case GroceryScanError.unknown:
        return 'Etwas ist schiefgelaufen. Versuch es nochmal.';
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

    final c = _controller;
    final cameraReady = c != null && c.value.isInitialized;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Material(
                    color: surfaceColor,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: lineColor),
                        ),
                        child:
                            Icon(Icons.chevron_left, color: inkColor, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EINKAUF FOTOGRAFIEREN',
                      style: GSTypography.label(color: muteColor)),
                  const SizedBox(height: 6),
                  Text(
                    'Alles auf einmal',
                    style: GSTypography.headline(color: inkColor, size: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (cameraReady)
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: c.value.previewSize?.height ?? 1,
                                height: c.value.previewSize?.width ?? 1,
                                child: CameraPreview(c),
                              ),
                            )
                          else
                            Container(
                              color: surfaceColor,
                              alignment: Alignment.center,
                              child: _initializing
                                  ? const CircularProgressIndicator(
                                      color: GSColors.primary)
                                  : Text(
                                      'Keine Kamera verfügbar',
                                      style: GSTypography.body(
                                          color: muteColor, size: 14),
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
                          if (_busy) _AnalyzingOverlay(status: _status),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
              child: Text(
                _busy ? _status : 'Leg den Einkauf hin und tippe auf Auslösen.',
                textAlign: TextAlign.center,
                style: GSTypography.italicCaption(color: muteColor)
                    .copyWith(fontSize: 14),
              ),
            ),
            // Auslöser
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: GestureDetector(
                onTap: (cameraReady && !_busy) ? _capture : null,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (cameraReady && !_busy)
                        ? GSColors.primary
                        : GSColors.primary.withValues(alpha: 0.4),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: GSColors.cream, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Mascot(pose: MascotPose.searching, size: 120),
          const SizedBox(height: 14),
          Text(
            status,
            textAlign: TextAlign.center,
            style: GSTypography.body(
              color: GSColors.cream,
              size: 15,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: GSColors.cream,
              strokeWidth: 2.5,
            ),
          ),
        ],
      ),
    );
  }
}
