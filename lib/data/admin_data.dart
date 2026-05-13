// This file manages the work types and damage spaces that appear in
// the Job Order form dropdowns. Instead of hardcoding them, I store
// them in Supabase so admins can add/edit/delete without touching the code.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Data Models

// Represents one row in the 'work_types' table.
class WorkTypeItem {
  final String id;   // UUID from Supabase - used when updating or deleting
  String code;
  String name;
  WorkTypeItem({required this.id, required this.code, required this.name});

  // Builds a WorkTypeItem from a raw Supabase map response.
  factory WorkTypeItem.fromMap(Map<String, dynamic> m) =>
      WorkTypeItem(id: m['id'] as String, code: m['code'] as String, name: m['name'] as String);
}

// Represents one row in the 'damage_spaces' table.
// Same structure as WorkTypeItem — code like "A", name like "Concrete/Asphalt".
class DamageSpaceItem {
  final String id;
  String code;
  String name;
  DamageSpaceItem({required this.id, required this.code, required this.name});

  factory DamageSpaceItem.fromMap(Map<String, dynamic> m) =>
      DamageSpaceItem(id: m['id'] as String, code: m['code'] as String, name: m['name'] as String);
}


// Manages the full list of work types from Supabase.
// Any widget that shows a work type dropdown.
class WorkTypesNotifier extends ChangeNotifier {
  final List<WorkTypeItem> _items = [];
  bool isLoading = false;
  String? error;

  // Exposes a read-only copy of the list so nothing outside can modify it directly.
  List<WorkTypeItem> get items => List.unmodifiable(_items);

  // Fetches all work types from Supabase, ordered by sort_order then code.
  // I call this at app startup and every time an admin adds/edits/deletes an item.
  Future<void> fetch() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final res = await Supabase.instance.client
          .from('work_types')
          .select()
          .order('sort_order', ascending: true)
          .order('code', ascending: true);

      // Clear the old list and repopulate with fresh data from Supabase.
      _items
        ..clear()
        ..addAll((res as List).map((e) => WorkTypeItem.fromMap(e)));
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  // Inserts a new work type row into Supabase, then re-fetches to stay in sync.
  Future<void> add(String code, String name) async {
    await Supabase.instance.client
        .from('work_types')
        .insert({'code': code, 'name': name});
    await fetch();
  }

  // Updates an existing work type by its UUID, then re-fetches.
  Future<void> update(String id, String code, String name) async {
    await Supabase.instance.client
        .from('work_types')
        .update({'code': code, 'name': name})
        .eq('id', id);
    await fetch();
  }

  // Deletes a work type by its UUID, then re-fetches.
  Future<void> remove(String id) async {
    await Supabase.instance.client
        .from('work_types')
        .delete()
        .eq('id', id);
    await fetch();
  }
}



// Same structure as WorkTypesNotifier but for the 'damage_spaces' table.
// Manages the list of working surface options (Concrete, Sidewalk, Earth, etc.).
class DamageSpacesNotifier extends ChangeNotifier {
  final List<DamageSpaceItem> _items = [];
  bool isLoading = false;
  String? error;

  // Exposes a read-only copy so nothing can accidentally mutate the list.
  List<DamageSpaceItem> get items => List.unmodifiable(_items);

  // Fetches all damage space rows from Supabase, ordered by sort_order then code.
  Future<void> fetch() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final res = await Supabase.instance.client
          .from('damage_spaces')
          .select()
          .order('sort_order', ascending: true)
          .order('code', ascending: true);

      _items
        ..clear()
        ..addAll((res as List).map((e) => DamageSpaceItem.fromMap(e)));
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  // Inserts a new damage space and re-fetches the full list.
  Future<void> add(String code, String name) async {
    await Supabase.instance.client
        .from('damage_spaces')
        .insert({'code': code, 'name': name});
    await fetch();
  }

  // Updates an existing damage space by UUID and re-fetches.
  Future<void> update(String id, String code, String name) async {
    await Supabase.instance.client
        .from('damage_spaces')
        .update({'code': code, 'name': name})
        .eq('id', id);
    await fetch();
  }

  // Deletes a damage space by UUID and re-fetches.
  Future<void> remove(String id) async {
    await Supabase.instance.client
        .from('damage_spaces')
        .delete()
        .eq('id', id);
    await fetch();
  }
}


// These two are shared across the whole app.
// Import this file and reference these directly — no need to pass them around.
final workTypesNotifier    = WorkTypesNotifier();
final damageSpacesNotifier = DamageSpacesNotifier();

// Called once in main() right after Supabase.initialize().
// Loads both lists in parallel so the app is ready before the user opens any form.
Future<void> initAdminData() async {
  await Future.wait([
    workTypesNotifier.fetch(),
    damageSpacesNotifier.fetch(),
  ]);
}