import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/settings/theme_providers.dart';

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
    );
  }
}
