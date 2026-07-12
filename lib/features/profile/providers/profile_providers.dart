import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/domain/user_stats.dart';
import '../../pantry/providers/pantry_providers.dart';

/// User-Stats — lädt bei jeder Vorrats-Änderung neu (watch auf den Stream).
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  ref.watch(pantryStreamProvider);

  final repo = ref.watch(pantryRepositoryProvider);
  return repo.fetchStats();
});
