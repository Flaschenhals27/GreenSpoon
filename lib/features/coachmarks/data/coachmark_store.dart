import 'package:shared_preferences/shared_preferences.dart';

import '../domain/coachmark.dart';

/// Persistenz der gesehenen Coachmarks. Als Abstraktion, damit der Controller
/// nicht an SharedPreferences gebunden ist und im Test ein Fake genügt.
abstract interface class CoachmarkStore {
  Future<Set<Coachmark>> loadSeen();

  Future<void> markSeen(Coachmark mark);
}

/// SharedPreferences-gestützte Umsetzung: ein Bool-Flag pro Coachmark.
class SharedPrefsCoachmarkStore implements CoachmarkStore {
  const SharedPrefsCoachmarkStore();

  @override
  Future<Set<Coachmark>> loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final mark in Coachmark.values)
        if (prefs.getBool(mark.storageKey) ?? false) mark,
    };
  }

  @override
  Future<void> markSeen(Coachmark mark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(mark.storageKey, true);
  }
}
