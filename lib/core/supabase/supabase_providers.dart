import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// [SupabaseClient] als injizierbare Abhängigkeit (DIP) — in Tests per
/// Provider-Override durch einen Fake ersetzbar.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});
