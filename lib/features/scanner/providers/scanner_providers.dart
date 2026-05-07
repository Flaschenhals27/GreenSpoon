import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/open_food_facts_service.dart';

final openFoodFactsProvider = Provider<OpenFoodFactsService>((ref) {
  final svc = OpenFoodFactsService();
  ref.onDispose(svc.dispose);
  return svc;
});