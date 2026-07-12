import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/mascot.dart';
import '../../core/theme/gs_colors.dart';
import '../../core/theme/gs_typography.dart';

/// Drei-Seiten-Onboarding beim ersten App-Start.
/// Nach Abschluss wird ein Flag in SharedPreferences gesetzt,
/// sodass es nur einmal erscheint.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  /// Wird aufgerufen, wenn der User "Los geht's" tippt oder überspringt.
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _pages = [
    _OnbData(
      eyebrow: 'GREENSPOON',
      titleNormal: 'Dein Vorrat,\n',
      titleItalic: 'gut sortiert.',
      body:
          'Wir merken uns, was du im Haus hast — und wann es gegessen werden will.',
      art: _OnbArt.cartons,
    ),
    _OnbData(
      eyebrow: 'SCHRITT 1',
      titleNormal: 'Scannen statt\n',
      titleItalic: 'tippen.',
      body:
          'Barcode kurz zeigen, Foto vom Mindesthaltbarkeitsdatum — fertig. Zwei Sekunden pro Produkt.',
      art: _OnbArt.scan,
    ),
    _OnbData(
      eyebrow: 'SCHRITT 2',
      titleNormal: 'Wir kochen,\n',
      titleItalic: 'was bald reif ist.',
      body:
          'Unsere KI macht Rezepte aus dem, was sonst im Müll landet. 100% deins, 0% Verschwendung.',
      art: _OnbArt.plate,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    widget.onDone();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? GSColors.inkDark : GSColors.ink;
    final muteColor = isDark ? GSColors.inkMuteDark : GSColors.inkMute;
    final bgColor = isDark ? GSColors.bgAppDark : GSColors.bgApp;
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Column(
                    children: [
                      // Art-Bereich oben
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _OnbArtwork(type: p.art, isDark: isDark),
                        ),
                      ),
                      // Text unten
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.eyebrow,
                                style: GSTypography.label(color: muteColor),
                              ),
                              const SizedBox(height: 14),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: p.titleNormal,
                                      style: GSTypography.headline(
                                        color: inkColor,
                                        size: 38,
                                      ),
                                    ),
                                    TextSpan(
                                      text: p.titleItalic,
                                      style: GSTypography.headline(
                                        color: isDark
                                            ? GSColors.primaryMid
                                            : GSColors.primary,
                                        size: 38,
                                      ).copyWith(fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                p.body,
                                style: GSTypography.body(
                                  color: muteColor,
                                  size: 15.5,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Progress-Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? (isDark ? GSColors.primaryMid : GSColors.primary)
                          : muteColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  if (!isLast)
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Überspringen',
                        style: TextStyle(color: muteColor),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: GSColors.primary,
                      foregroundColor: GSColors.cream,
                      minimumSize: Size(isLast ? 280 : 180, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLast ? 'Los geht\'s' : 'Weiter',
                          style: GSTypography.body(
                            color: GSColors.cream,
                            size: 15,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
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

enum _OnbArt { cartons, scan, plate }

class _OnbData {
  const _OnbData({
    required this.eyebrow,
    required this.titleNormal,
    required this.titleItalic,
    required this.body,
    required this.art,
  });
  final String eyebrow;
  final String titleNormal;
  final String titleItalic;
  final String body;
  final _OnbArt art;
}

// ─────────────────────────────────────────────────────────────────────

/// Einfache, illustrative Artworks pro Seite — bewusst ohne externe Assets,
/// nur mit Flutter-Primitiven, damit nichts geladen werden muss.
class _OnbArtwork extends StatelessWidget {
  const _OnbArtwork({required this.type, required this.isDark});
  final _OnbArt type;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case _OnbArt.cartons:
        return const Center(
          child: Mascot(pose: MascotPose.waving, size: 220),
        );
      case _OnbArt.scan:
        return _ScanArt(isDark: isDark);
      case _OnbArt.plate:
        return _PlateArt(isDark: isDark);
    }
  }
}

class _ScanArt extends StatelessWidget {
  const _ScanArt({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GSColors.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: SizedBox(
          width: 200,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Barcode-Streifen
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 18; i++)
                    Container(
                      width: i.isEven ? 4 : 2.5,
                      height: 90,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      color: GSColors.cream
                          .withValues(alpha: i % 3 == 0 ? 0.9 : 0.5),
                    ),
                ],
              ),
              // Reticle-Ecken
              ...List.generate(4, (i) {
                final isTop = i < 2;
                final isLeft = i.isEven;
                return Align(
                  alignment: Alignment(isLeft ? -1 : 1, isTop ? -1 : 1),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      border: Border(
                        top: isTop
                            ? const BorderSide(color: GSColors.cream, width: 3)
                            : BorderSide.none,
                        bottom: !isTop
                            ? const BorderSide(color: GSColors.cream, width: 3)
                            : BorderSide.none,
                        left: isLeft
                            ? const BorderSide(color: GSColors.cream, width: 3)
                            : BorderSide.none,
                        right: !isLeft
                            ? const BorderSide(color: GSColors.cream, width: 3)
                            : BorderSide.none,
                      ),
                    ),
                  ),
                );
              }),
              // Orange Scan-Linie
              Container(
                width: 180,
                height: 2.5,
                decoration: BoxDecoration(
                  color: GSColors.accent,
                  boxShadow: [
                    BoxShadow(
                      color: GSColors.accent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlateArt extends StatelessWidget {
  const _PlateArt({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Teller
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: GSColors.cream,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
          Container(
            width: 130,
            height: 130,
            decoration: const BoxDecoration(
              color: Color(0xFFC9824E),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🍳', style: TextStyle(fontSize: 56)),
          ),
          // Match-Pill oben rechts
          Positioned(
            top: 20,
            right: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: GSColors.primaryDeep,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: GSColors.cream,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '100%',
                    style: GSTypography.body(
                      color: GSColors.cream,
                      size: 12,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
