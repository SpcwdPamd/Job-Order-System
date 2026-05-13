import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingUsersNotifier extends ValueNotifier<int> {
  PendingUsersNotifier() : super(0);

  /// Fetch the current pending count from Supabase and notify listeners.
  Future<void> refresh() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('status', 'pending');
      value = (res as List).length;
    } catch (_) {
      // Silently ignore — badge just won't show on error
    }
  }
}

/// Global singleton — count
final pendingUsersNotifier = PendingUsersNotifier();