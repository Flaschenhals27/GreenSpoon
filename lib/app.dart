import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/settings/theme_providers.dart';
import 'features/onboarding/onboarding_screen.dart';

import 'core/router/app_router.dart';
import 'core/theme/gs_theme.dart';

class GreenSpoonApp extends ConsumerWidget {
  const GreenSpoonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Green Spoon',
      debugShowCheckedModeBanner: false,
      theme: GSTheme.light(),
      darkTheme: GSTheme.dark(),
      themeMode: ref.watch(themeModeProvider).value ?? ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      builder: (context, child) {
        // child = der gerouteten Inhalt. Wir legen bei Bedarf das
        // Onboarding darüber, bis es abgeschlossen ist.
        return _OnboardingGate(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

/// Zeigt beim allerersten Start das Onboarding über der App an.
/// Liest das `onboarding_done`-Flag aus SharedPreferences.
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate({required this.child});
  final Widget child;

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool? _needsOnboarding; // null = noch nicht geladen

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    if (mounted) setState(() => _needsOnboarding = !done);
  }

  @override
  Widget build(BuildContext context) {
    // Solange unklar: einfach die App zeigen (kein Flackern eines Spinners).
    if (_needsOnboarding == null) return widget.child;

    if (_needsOnboarding == true) {
      return OnboardingScreen(
        onDone: () => setState(() => _needsOnboarding = false),
      );
    }

    return widget.child;
  }
}
