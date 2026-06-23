import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Stellt den initialisierten [SupabaseClient] als injizierbare Abhängigkeit
/// bereit.
///
/// Repositories und der Router hängen damit nicht mehr direkt am globalen
/// Singleton [SupabaseService.client], sondern bekommen den Client per
/// Provider gereicht (Dependency Inversion). In Tests lässt er sich über
/// `ProviderScope(overrides: [supabaseClientProvider.overrideWithValue(...)])`
/// durch einen Fake ersetzen.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});
