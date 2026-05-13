// notification_helper.dart
//
// Shared utility used by the DESKTOP side (job_order_screen.dart and
// team_jobs_screen.dart) to write a row into `team_notifications` whenever
// a job is assigned to a team or marked as accomplished.
//
// Place this file anywhere in your project (e.g. lib/core/utils/) and import
// it in both screen files.

import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationHelper {
  NotificationHelper._();

  /// Call this right after you set team_id on a job_order (i.e. "assigned").
  static Future<void> notifyJobAssigned({
    required String teamId,
    required String joNumber,
    required String workTypeName,
    required String address,
  }) async {
    await _insert(
      teamId:       teamId,
      joNumber:     joNumber,
      workTypeName: workTypeName,
      address:      address,
      type:         'new_job',
      status:       'pending',
    );
  }

  /// Call this right after you set status = 'accomplished' on a job_order.
  static Future<void> notifyJobAccomplished({
    required String teamId,
    required String joNumber,
    required String workTypeName,
    required String address,
  }) async {
    await _insert(
      teamId:       teamId,
      joNumber:     joNumber,
      workTypeName: workTypeName,
      address:      address,
      type:         'accomplished',
      status:       'accomplished',
    );
  }

  // ── internal ──────────────────────────────────────────────────────────────
  static Future<void> _insert({
    required String teamId,
    required String joNumber,
    required String workTypeName,
    required String address,
    required String type,
    required String status,
  }) async {
    try {
      await Supabase.instance.client.from('team_notifications').insert({
        'team_id':        teamId,
        'jo_number':      joNumber,
        'work_type_name': workTypeName,
        'address':        address,
        'type':           type,
        'status':         status,
        'is_read':        false,
      });
    } catch (e) {
      // Log but never let a notification failure crash the caller
      // ignore: avoid_print
      print('[NotificationHelper] insert failed: $e');
    }
  }
}