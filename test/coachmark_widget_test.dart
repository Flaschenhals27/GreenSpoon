import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:green_spoon/features/coachmarks/presentation/coachmark_scaffold.dart';
import 'package:green_spoon/features/coachmarks/presentation/pantry_swipe_coach.dart';
import 'package:green_spoon/features/coachmarks/presentation/recipe_match_coach.dart';

Widget _host(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  // Keine Netzwerk-Fetches für Fonts im Test — Fallback genügt.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget scaffold(VoidCallback onDismiss) => CoachmarkScaffold(
        eyebrow: 'DEMO',
        title: 'Titel',
        message: 'Nachricht',
        demo: const SizedBox(height: 24),
        onDismiss: onDismiss,
      );

  testWidgets('Verstanden-Button blendet aus und meldet zurück',
      (tester) async {
    var dismissed = false;
    await tester.pumpWidget(_host(scaffold(() => dismissed = true)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Titel'), findsOneWidget);

    await tester.tap(find.text('Verstanden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(dismissed, isTrue);
  });

  testWidgets('Tippen auf den abgedunkelten Hintergrund schließt',
      (tester) async {
    var dismissed = false;
    await tester.pumpWidget(_host(scaffold(() => dismissed = true)));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tapAt(const Offset(6, 6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(dismissed, isTrue);
  });

  testWidgets('PantrySwipeCoach erklärt beide Wischrichtungen',
      (tester) async {
    await tester.pumpWidget(
      _host(PantrySwipeCoach(onDismiss: () {}), reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Wischen erledigt alles'), findsOneWidget);
    expect(find.text('Verbraucht'), findsOneWidget);
    expect(find.text('Weggeworfen'), findsOneWidget);
  });

  testWidgets('RecipeMatchCoach zeigt die drei Farbstufen', (tester) async {
    await tester.pumpWidget(
      _host(RecipeMatchCoach(onDismiss: () {}), reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('fast alles da'), findsOneWidget);
    expect(find.text('etwas fehlt'), findsOneWidget);
    expect(find.text('wenig da'), findsOneWidget);
  });
}
