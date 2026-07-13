import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green_spoon/features/coachmarks/data/coachmark_store.dart';
import 'package:green_spoon/features/coachmarks/domain/coachmark.dart';
import 'package:green_spoon/features/coachmarks/providers/coachmark_providers.dart';

class _FakeCoachmarkStore implements CoachmarkStore {
  _FakeCoachmarkStore([Set<Coachmark> seen = const {}]) : _seen = {...seen};

  final Set<Coachmark> _seen;
  final Set<Coachmark> saved = {};

  @override
  Future<Set<Coachmark>> loadSeen() async => {..._seen};

  @override
  Future<void> markSeen(Coachmark mark) async => saved.add(mark);
}

ProviderContainer _container(CoachmarkStore store) {
  final container = ProviderContainer(
    overrides: [coachmarkStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('CoachmarkState', () {
    test('vor dem Laden wird nichts gezeigt', () {
      const state = CoachmarkState.initial();
      expect(state.shouldShow(Coachmark.pantrySwipe), isFalse);
    });

    test('geladen und ungesehen → wird gezeigt', () {
      const state = CoachmarkState(loaded: true, seen: {});
      expect(state.shouldShow(Coachmark.pantrySwipe), isTrue);
    });

    test('bereits gesehen → wird nicht mehr gezeigt', () {
      const state =
          CoachmarkState(loaded: true, seen: {Coachmark.pantrySwipe});
      expect(state.shouldShow(Coachmark.pantrySwipe), isFalse);
      expect(state.shouldShow(Coachmark.recipeMatch), isTrue);
    });

    test('withSeen ergänzt, ohne bestehende zu verlieren', () {
      const state =
          CoachmarkState(loaded: true, seen: {Coachmark.pantrySwipe});
      final next = state.withSeen(Coachmark.recipeMatch);
      expect(next.seen, {Coachmark.pantrySwipe, Coachmark.recipeMatch});
    });
  });

  group('CoachmarkController', () {
    test('lädt den gespeicherten Stand beim Start', () async {
      final container =
          _container(_FakeCoachmarkStore({Coachmark.recipeMatch}));

      container.read(coachmarkControllerProvider);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(coachmarkControllerProvider);
      expect(state.loaded, isTrue);
      expect(state.shouldShow(Coachmark.recipeMatch), isFalse);
      expect(state.shouldShow(Coachmark.pantrySwipe), isTrue);
    });

    test('markSeen persistiert und aktualisiert den State', () async {
      final store = _FakeCoachmarkStore();
      final container = _container(store);

      container.read(coachmarkControllerProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(coachmarkControllerProvider.notifier)
          .markSeen(Coachmark.pantrySwipe);

      expect(store.saved, contains(Coachmark.pantrySwipe));
      expect(
        container.read(coachmarkControllerProvider).shouldShow(
              Coachmark.pantrySwipe,
            ),
        isFalse,
      );
    });

    test('doppeltes markSeen schreibt nur einmal', () async {
      final store = _FakeCoachmarkStore({Coachmark.pantrySwipe});
      final container = _container(store);

      container.read(coachmarkControllerProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(coachmarkControllerProvider.notifier)
          .markSeen(Coachmark.pantrySwipe);

      expect(store.saved, isEmpty);
    });
  });
}
