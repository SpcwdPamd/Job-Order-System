import 'dart:io';
import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SQL MIGRATION — run once in Supabase SQL editor before using this file:
//
//  CREATE TABLE IF NOT EXISTS public.team_monthly_logs (
//    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
//    team_id      uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
//    year         int  NOT NULL,
//    month        int  NOT NULL,           -- 1 = Jan … 12 = Dec
//    team_name    text,
//    foreman_id   uuid REFERENCES public.personnel(id) ON DELETE SET NULL,
//    driver_id    uuid REFERENCES public.personnel(id) ON DELETE SET NULL,
//    personnel_ids uuid[] DEFAULT '{}',
//    snapshot     jsonb,                   -- {teamName, leader, driver, members[]}
//    created_at   timestamptz DEFAULT now(),
//    UNIQUE (team_id, year, month)         -- one log row per team per month
//  );
//
//  -- Allow your admin session to read/write (adjust to your RLS policy):
//  ALTER TABLE public.team_monthly_logs ENABLE ROW LEVEL SECURITY;
//  CREATE POLICY "admin full access" ON public.team_monthly_logs
//    USING (true) WITH CHECK (true);
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
//  EditJobOrderScreen
// ─────────────────────────────────────────────────────────────────────────────
class EditJobOrderScreen extends StatefulWidget {
  const EditJobOrderScreen({super.key});

  @override
  State<EditJobOrderScreen> createState() => _EditJobOrderScreenState();
}

class _EditJobOrderScreenState extends State<EditJobOrderScreen>
    with SingleTickerProviderStateMixin {
  Tk get _tk => context.tk;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tk.bg,
      body: Column(children: [
        DsHeader(
          title: 'Edit J.O',
          subtitle: 'Manage teams & personnel • Admin only',
          icon: Icons.edit_note_rounded,
          accent: _tk.cyan,
        ),
        Container(
          color: _tk.surf,
          child: Column(children: [
            TabBar(
              controller: _tabController,
              labelColor: _tk.cyan,
              unselectedLabelColor: _tk.txtMuted,
              indicatorColor: _tk.cyan,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: const [Tab(text: 'Edit Teams'), Tab(text: 'Edit Personnel')],
            ),
            Divider(height: 1, color: _tk.bd),
          ]),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [EditTeamsTab(), EditPersonnelTab()],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Monthly Log Helper — writes/upserts a snapshot for the current month
// ─────────────────────────────────────────────────────────────────────────────
class _MonthlyLogHelper {
  static Future<void> upsertLog({
    required String teamId,
    required String teamName,
    required String? foremanId,
    required String? driverId,
    required List<String> personnelIds,
    required List<Map<String, dynamic>> allPersonnel,
  }) async {
    final now   = DateTime.now();
    final year  = now.year;
    final month = now.month;

    String _nameOf(String? id) {
      if (id == null) return '—';
      final p = allPersonnel.firstWhere(
            (p) => p['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      return p['name'] as String? ?? '—';
    }

    final snapshot = {
      'teamName': teamName,
      'leader'  : _nameOf(foremanId),
      'driver'  : _nameOf(driverId),
      'members' : personnelIds.map(_nameOf).toList(),
      'month'   : month,
      'year'    : year,
    };

    try {
      await Supabase.instance.client.from('team_monthly_logs').upsert(
        {
          'team_id'      : teamId,
          'year'         : year,
          'month'        : month,
          'team_name'    : teamName,
          'foreman_id'   : foremanId,
          'driver_id'    : driverId,
          'personnel_ids': personnelIds,
          'snapshot'     : snapshot,
        },
        onConflict: 'team_id,year,month',
      );
    } catch (e) {
// Non-fatal — log but don't crash the caller
// ignore: avoid_print
      print('[MonthlyLog] upsert failed: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EDIT TEAMS TAB
// ─────────────────────────────────────────────────────────────────────────────
class EditTeamsTab extends StatefulWidget {
  const EditTeamsTab({super.key});
  @override
  State<EditTeamsTab> createState() => _EditTeamsTabState();
}

class _EditTeamsTabState extends State<EditTeamsTab> {
  Tk get _tk => context.tk;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _filteredTeams = [];
  List<Map<String, dynamic>> _personnel = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterTeams);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final teamsRes = await Supabase.instance.client
          .from('teams')
          .select('id, team_name, foreman_id, driver_id, personnel_ids, foreman:foreman_id (name, profile_pic_url)')
          .order('team_name', ascending: true);
      final peopleRes = await Supabase.instance.client
          .from('personnel')
          .select('id, name, position, profile_pic_url');
      setState(() {
        _teams         = List<Map<String, dynamic>>.from(teamsRes);
        _filteredTeams = List.from(_teams);
        _personnel     = List<Map<String, dynamic>>.from(peopleRes);
        _isLoading     = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Error loading data: $e', error: true);
    }
  }

  void _filterTeams() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredTeams = q.isEmpty
          ? List.from(_teams)
          : _teams.where((t) {
        final name   = (t['team_name'] as String?)?.toLowerCase() ?? '';
        final leader = (t['foreman']?['name'] as String?)?.toLowerCase() ?? '';
        return name.contains(q) || leader.contains(q);
      }).toList();
    });
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? _tk.red : _tk.green));
  }

// ── Shared button widgets ────────────────────────────────────────────────
  Widget _outlineBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
          color: _tk.surf2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _tk.bd)),
      child: Center(
          child: Text(label,
              style: TextStyle(color: _tk.txt, fontSize: 13.5, fontWeight: FontWeight.w600))),
    ),
  );

  Widget _solidBtn(String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withOpacity(0.82)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [BoxShadow(color: color.withOpacity(0.30), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Center(
          child: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700))),
    ),
  );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Icon(icon, color: color, size: 16),
    ),
  );

  InputDecoration _dropDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: _tk.txtMuted, fontSize: 13),
    filled: true,
    fillColor: _tk.surf,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _tk.bd)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _tk.bd)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _tk.cyan, width: 1.5)),
  );

  Widget _sectionRow(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
            color: _tk.cyan.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _tk.cyan.withOpacity(0.22))),
        child: Icon(icon, color: _tk.cyan, size: 14),
      ),
      const SizedBox(width: 9),
      Text(title,
          style: TextStyle(color: _tk.txtHead, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _dialogHeader(String title, IconData icon, VoidCallback onClose) => Container(
    padding: const EdgeInsets.fromLTRB(24, 22, 20, 18),
    decoration: BoxDecoration(
      color: _tk.surf,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      border: Border(bottom: BorderSide(color: _tk.bd)),
    ),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
            color: _tk.cyan.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _tk.cyan.withOpacity(0.22))),
        child: Icon(icon, color: _tk.cyan, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
          child: Text(title,
              style: TextStyle(color: _tk.txtHead, fontSize: 15, fontWeight: FontWeight.w700))),
      GestureDetector(
        onTap: onClose,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: _tk.bd.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.close_rounded, color: _tk.txtMuted, size: 16),
        ),
      ),
    ]),
  );

  Future<bool?> _confirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _tk.surf,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), side: BorderSide(color: _tk.bd)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor.withOpacity(0.25))),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(color: _tk.txtHead, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(color: _tk.txtMuted, fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _outlineBtn('Cancel', () => Navigator.pop(ctx, false))),
              const SizedBox(width: 10),
              Expanded(child: _solidBtn(confirmLabel, confirmColor, () => Navigator.pop(ctx, true))),
            ]),
          ]),
        ),
      ),
    );
  }

// ── Delete team ──────────────────────────────────────────────────────────
  Future<void> _deleteTeam(Map<String, dynamic> team) async {
    final ok = await _confirmDialog(
      icon: Icons.delete_forever_rounded,
      iconColor: _tk.red,
      title: 'Delete Team?',
      body: 'Delete "${team['team_name']}"? This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: _tk.red,
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('teams').delete().eq('id', team['id']);
      if (!mounted) return;
      Navigator.pop(context);
      _loadData();
      _showSnack('Team deleted');
    } catch (e) {
      _showSnack('Error: $e', error: true);
    }
  }

// ── Create Team Dialog ───────────────────────────────────────────────────
  void _showCreateTeamDialog() {
    final nameCtrl      = TextEditingController();
    String? selectedLeaderId;
    String? selectedDriverId;
    List<String?> memberIds = [null, null, null];

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final assignedIds = <String>{};
          for (final t in _teams) {
            if (t['foreman_id'] != null) assignedIds.add(t['foreman_id'] as String);
            if (t['driver_id']  != null) assignedIds.add(t['driver_id']  as String);
            assignedIds.addAll((t['personnel_ids'] as List?)?.cast<String>() ?? []);
          }
          final available = _personnel.where((p) => !assignedIds.contains(p['id'])).toList();
          final leaders   = available.where((p) => p['position'] == 'Team Leader').toList();
          final drivers   = available.where((p) => p['position'] == 'Driver').toList();
          final members   = available.where((p) => p['position'] == 'Member').toList();

          return Dialog(
            backgroundColor: _tk.surf,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22), side: BorderSide(color: _tk.bd)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 820),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _dialogHeader('Create New Team', Icons.group_add_rounded, () => Navigator.pop(ctx)),
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

// Team Name
                    _sectionRow('Team Name', Icons.badge_rounded),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: _tk.txtHead, fontSize: 14),
                      decoration: _dropDeco('Team Name *'),
                    ),
                    const SizedBox(height: 20),

// Team Leader
                    _sectionRow('Team Leader', Icons.star_rounded),
                    DropdownButtonFormField<String?>(
                      value: selectedLeaderId,
                      isExpanded: true,
                      dropdownColor: _tk.surf,
                      style: TextStyle(color: _tk.txtHead, fontSize: 13.5),
                      decoration: _dropDeco('Select Leader'),
                      items: [
                        DropdownMenuItem(
                            value: null,
                            child: Text('— None —', style: TextStyle(color: _tk.txtMuted))),
                        ...leaders.map((p) => DropdownMenuItem(
                            value: p['id'] as String?, child: Text(p['name'] as String))),
                      ],
                      onChanged: (v) => setS(() => selectedLeaderId = v),
                    ),
                    const SizedBox(height: 20),

// Driver
                    _sectionRow('Driver', Icons.drive_eta_rounded),
                    DropdownButtonFormField<String?>(
                      value: selectedDriverId,
                      isExpanded: true,
                      dropdownColor: _tk.surf,
                      style: TextStyle(color: _tk.txtHead, fontSize: 13.5),
                      decoration: _dropDeco('Select Driver'),
                      items: [
                        DropdownMenuItem(
                            value: null,
                            child: Text('— None —', style: TextStyle(color: _tk.txtMuted))),
                        ...drivers.map((p) => DropdownMenuItem(
                          value: p['id'] as String?,
                          child: Row(children: [
                            Icon(Icons.drive_eta_rounded, size: 14, color: _tk.amber),
                            const SizedBox(width: 8),
                            Text(p['name'] as String),
                          ]),
                        )),
                      ],
                      onChanged: (v) => setS(() => selectedDriverId = v),
                    ),
                    const SizedBox(height: 20),

// Members
                    _sectionRow('Members (optional)', Icons.people_rounded),
                    ...List.generate(memberIds.length, (i) {
                      final cur   = memberIds[i];
                      final avail = members.where((p) {
                        return !memberIds.asMap().entries
                            .where((e) => e.key != i)
                            .map((e) => e.value)
                            .contains(p['id']);
                      }).toList();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: cur,
                              isExpanded: true,
                              dropdownColor: _tk.surf,
                              style: TextStyle(color: _tk.txtHead, fontSize: 13.5),
                              decoration: _dropDeco('Member ${i + 1}'),
                              items: [
                                DropdownMenuItem(
                                    value: null,
                                    child: Text('— None —', style: TextStyle(color: _tk.txtMuted))),
                                ...avail.map((p) => DropdownMenuItem(
                                    value: p['id'] as String?, child: Text(p['name'] as String))),
                                if (cur != null && !avail.any((p) => p['id'] == cur))
                                  DropdownMenuItem(
                                    value: cur,
                                    child: Text(
                                      _personnel.firstWhere((p) => p['id'] == cur,
                                          orElse: () => {'name': 'Unknown'})['name'] as String,
                                      style: TextStyle(color: _tk.txtMuted),
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setS(() => memberIds[i] = v),
                            ),
                          ),
                          if (i >= 3) ...[
                            const SizedBox(width: 8),
                            _iconBtn(Icons.remove_rounded, _tk.red,
                                    () => setS(() => memberIds.removeAt(i))),
                          ],
                        ]),
                      );
                    }),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setS(() => memberIds.add(null)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: _tk.blueBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _tk.blueBd)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_rounded, color: _tk.blue, size: 16),
                          const SizedBox(width: 6),
                          Text('Add Another Member',
                              style: TextStyle(
                                  color: _tk.blue, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                )),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: _tk.bd))),
                  child: Row(children: [
                    Expanded(child: _outlineBtn('Cancel', () => Navigator.pop(ctx))),
                    const SizedBox(width: 12),
                    Expanded(child: _solidBtn('Create Team', _tk.cyan, () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        _showSnack('Team name is required', error: true);
                        return;
                      }
                      try {
                        final res = await Supabase.instance.client.from('teams').insert({
                          'team_name'    : name,
                          'foreman_id'   : selectedLeaderId,
                          'driver_id'    : selectedDriverId,
                          'personnel_ids': memberIds.whereType<String>().toList(),
                        }).select('id').single();

                        await _MonthlyLogHelper.upsertLog(
                          teamId      : res['id'] as String,
                          teamName    : name,
                          foremanId   : selectedLeaderId,
                          driverId    : selectedDriverId,
                          personnelIds: memberIds.whereType<String>().toList(),
                          allPersonnel: _personnel,
                        );

                        Navigator.pop(ctx);
                        _loadData();
                        _showSnack('Team created');
                      } catch (e) {
                        _showSnack('Error: $e', error: true);
                      }
                    })),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

// ── Team Detail / Edit Dialog ────────────────────────────────────────────
  void _showTeamDetailDialog(Map<String, dynamic> team) {
    bool    isEditMode     = false;
    String  editedName     = team['team_name'] ?? 'Unnamed Team';
    String? editedLeaderId = team['foreman_id'];
    String? editedDriverId = team['driver_id'];
    List<String?> editedMemberIds =
    (team['personnel_ids'] as List<dynamic>? ?? []).cast<String?>().toList();
    while (editedMemberIds.length < 3) editedMemberIds.add(null);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final leader = _personnel.firstWhere(
                  (p) => p['id'] == editedLeaderId,
              orElse: () => {'name': 'Not assigned', 'profile_pic_url': null});
          final leaderPic  = leader['profile_pic_url'] as String?;
          final leaderName = leader['name'] as String? ?? 'Not assigned';

          final driver = _personnel.firstWhere(
                  (p) => p['id'] == editedDriverId,
              orElse: () => {'name': 'Not assigned', 'profile_pic_url': null});
          final driverPic  = driver['profile_pic_url'] as String?;
          final driverName = driver['name'] as String? ?? 'Not assigned';

          final possibleLeaders = _personnel.where((p) => p['position'] == 'Team Leader').toList();
          final possibleDrivers = _personnel.where((p) => p['position'] == 'Driver').toList();
          final possibleMembers = _personnel.where((p) => p['position'] == 'Member').toList();

          return Dialog(
            backgroundColor: _tk.surf,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22), side: BorderSide(color: _tk.bd)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 840),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

// ── Dialog header ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                  decoration: BoxDecoration(
                      color: _tk.surf,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      border: Border(bottom: BorderSide(color: _tk.bd))),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: _tk.cyan.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: _tk.cyan.withOpacity(0.22))),
                      child: Icon(Icons.groups_rounded, color: _tk.cyan, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isEditMode
                          ? TextField(
                        onChanged: (v) => editedName = v,
                        controller: TextEditingController(text: editedName)
                          ..selection = TextSelection.collapsed(offset: editedName.length),
                        style: TextStyle(
                            color: _tk.txtHead, fontSize: 15, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Team Name',
                            hintStyle: TextStyle(color: _tk.txtMuted)),
                      )
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(editedName,
                            style: TextStyle(
                                color: _tk.txtHead,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        Text('${editedMemberIds.whereType<String>().length} members',
                            style: TextStyle(color: _tk.txtMuted, fontSize: 12)),
                      ]),
                    ),
// Monthly logs button
                    if (!isEditMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _iconBtn(Icons.history_rounded, _tk.violet, () {
                          _showMonthlyLogsDialog(team['id'] as String, editedName);
                        }),
                      ),
                    if (!isEditMode)
                      _iconBtn(Icons.edit_rounded, _tk.blue, () => setS(() => isEditMode = true))
                    else ...[
                      _iconBtn(Icons.check_rounded, _tk.green, () async {
                        try {
                          await Supabase.instance.client.from('teams').update({
                            'team_name'    : editedName,
                            'foreman_id'   : editedLeaderId,
                            'driver_id'    : editedDriverId,
                            'personnel_ids': editedMemberIds.whereType<String>().toList(),
                          }).eq('id', team['id']);

                          await _MonthlyLogHelper.upsertLog(
                            teamId      : team['id'] as String,
                            teamName    : editedName,
                            foremanId   : editedLeaderId,
                            driverId    : editedDriverId,
                            personnelIds: editedMemberIds.whereType<String>().toList(),
                            allPersonnel: _personnel,
                          );

                          Navigator.pop(ctx);
                          _loadData();
                          _showSnack('Team updated');
                        } catch (e) {
                          _showSnack('Error: $e', error: true);
                        }
                      }),
                      const SizedBox(width: 6),
                      _iconBtn(Icons.close_rounded, _tk.txtMuted,
                              () => setS(() => isEditMode = false)),
                    ],
                    const SizedBox(width: 6),
                    _iconBtn(Icons.close_rounded, _tk.txtMuted, () => Navigator.pop(ctx)),
                  ]),
                ),

// ── Body ──────────────────────────────────────────────────
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!isEditMode) ...[

// View: Leader
                      _sectionRow('Team Leader', Icons.star_rounded),
                      _personTile(leaderName, leaderPic, _tk.blue, _tk.blueBg),
                      const SizedBox(height: 20),

// View: Driver
                      _sectionRow('Driver', Icons.drive_eta_rounded),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: editedDriverId != null ? _tk.amberBg : _tk.surf2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: editedDriverId != null
                                  ? _tk.amber.withOpacity(0.30)
                                  : _tk.bd),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: _tk.amberBg,
                            backgroundImage: driverPic != null ? NetworkImage(driverPic) : null,
                            child: driverPic == null
                                ? Icon(Icons.drive_eta_rounded,
                                color: editedDriverId != null ? _tk.amber : _tk.txtMuted,
                                size: 20)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(
                            editedDriverId != null ? driverName : 'No driver assigned',
                            style: TextStyle(
                              color: editedDriverId != null ? _tk.txtHead : _tk.txtMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          )),
                          if (editedDriverId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _tk.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _tk.amber.withOpacity(0.30)),
                              ),
                              child: Text('Driver',
                                  style: TextStyle(
                                      color: _tk.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 20),

// View: Members
                      _sectionRow('Members', Icons.people_rounded),
                      ...editedMemberIds.whereType<String>().map((id) {
                        final m = _personnel.firstWhere((p) => p['id'] == id,
                            orElse: () => {'name': 'Unknown', 'profile_pic_url': null});
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _personTile(
                            m['name'] as String? ?? '—',
                            m['profile_pic_url'] as String?,
                            _tk.blue, _tk.blueBg,
                            small: true,
                          ),
                        );
                      }),
                      if (editedMemberIds.whereType<String>().isEmpty)
                        Text('No members assigned.',
                            style: TextStyle(color: _tk.txtMuted, fontSize: 13.5)),

                    ] else ...[

// Edit: Leader
                      _sectionRow('Team Leader', Icons.star_rounded),
                      DropdownButtonFormField<String?>(
                        value: editedLeaderId,
                        isExpanded: true,
                        dropdownColor: _tk.surf,
                        style: TextStyle(color: _tk.txtHead, fontSize: 13.5),
                        decoration: _dropDeco('Select Leader'),
                        items: [
                          DropdownMenuItem(
                              value: null,
                              child: Text('— None —', style: TextStyle(color: _tk.txtMuted))),
                          if (editedLeaderId != null)
                            DropdownMenuItem(
                              value: editedLeaderId,
                              child: Text('${leader['name'] ?? 'Current'} (current)',
                                  style: TextStyle(color: _tk.cyan, fontWeight: FontWeight.w600)),
                            ),
                          ...possibleLeaders
                              .where((p) => p['id'] != editedLeaderId)
                              .map((p) => DropdownMenuItem(
                              value: p['id'] as String?, child: Text(p['name'] as String))),
                        ],
                        onChanged: (v) => setS(() => editedLeaderId = v),
                      ),
                      const SizedBox(height: 20),

// Edit: Driver
                      _sectionRow('Driver', Icons.drive_eta_rounded),
                      DropdownButtonFormField<String?>(
                        value: editedDriverId,
                        isExpanded: true,
                        dropdownColor: _tk.surf,
                        style: TextStyle(color: _tk.txtHead, fontSize: 13.5),
                        decoration: _dropDeco('Select Driver'),
                        items: [
                          DropdownMenuItem(
                              value: null,
                              child: Text('— None —', style: TextStyle(color: _tk.txtMuted))),
                          if (editedDriverId != null)
                            DropdownMenuItem(
                              value: editedDriverId,
                              child: Row(children: [
                                Icon(Icons.drive_eta_rounded, size: 14, color: _tk.amber),
                                const SizedBox(width: 8),
                                Text('${driver['name'] ?? 'Current'} (current)',
                                    style: TextStyle(
                                        color: _tk.amber, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ...possibleDrivers
                              .where((p) => p['id'] != editedDriverId)
                              .map((p) => DropdownMenuItem(
                            value: p['id'] as String?,
                            child: Row(children: [
                              Icon(Icons.drive_eta_rounded, size: 14, color: _tk.amber),
                              const SizedBox(width: 8),
                              Text(p['name'] as String),
                            ]),
                          )),
                        ],
                        onChanged: (v) => setS(() => editedDriverId = v),
                      ),
                      const SizedBox(height: 20),

// Edit: Members
                      _sectionRow('Members', Icons.people_rounded),
                      ...List.generate(editedMemberIds.length, (i) {
                        final cur   = editedMemberIds[i];
                        final avail = possibleMembers.where((p) {
                          return !editedMemberIds.asMap().entries
                              .where((e) => e.key != i)
                              .any((e) => e.value == p['id']);
                        }).toList();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: cur,
                                isExpanded: true,
                                dropdownColor: _tk.surf,
                                style: TextStyle(color: _tk.txtHead, fontSize: 13.5),
                                decoration: _dropDeco('Member ${i + 1}'),
                                items: [
                                  DropdownMenuItem(
                                      value: null,
                                      child:
                                      Text('— None —', style: TextStyle(color: _tk.txtMuted))),
                                  ...avail.map((p) => DropdownMenuItem(
                                      value: p['id'] as String?, child: Text(p['name'] as String))),
                                  if (cur != null && !avail.any((p) => p['id'] == cur))
                                    DropdownMenuItem(
                                      value: cur,
                                      child: Text(
                                        _personnel
                                            .firstWhere((p) => p['id'] == cur,
                                            orElse: () => {'name': 'Unknown (removed)'})['name']
                                        as String,
                                        style: TextStyle(color: _tk.txtMuted),
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setS(() => editedMemberIds[i] = v),
                              ),
                            ),
                            if (i >= 3) ...[
                              const SizedBox(width: 8),
                              _iconBtn(Icons.remove_rounded, _tk.red,
                                      () => setS(() => editedMemberIds.removeAt(i))),
                            ],
                          ]),
                        );
                      }),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => setS(() => editedMemberIds.add(null)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: _tk.blueBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _tk.blueBd)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_rounded, color: _tk.blue, size: 16),
                            const SizedBox(width: 6),
                            Text('Add Another Member',
                                style: TextStyle(
                                    color: _tk.blue, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                )),

// ── Footer ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: _tk.bd))),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => _deleteTeam(team),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: _tk.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _tk.red.withOpacity(0.25))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_rounded, color: _tk.red, size: 15),
                          const SizedBox(width: 6),
                          Text('Delete Team',
                              style: TextStyle(
                                  color: _tk.red, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                    const Spacer(),
                    _outlineBtn('Close', () => Navigator.pop(ctx)),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

// ── Small person tile widget ─────────────────────────────────────────────
  Widget _personTile(String name, String? picUrl, Color accent, Color bg,
      {bool small = false}) {
    final radius = small ? 18.0 : 22.0;
    return Container(
      padding: EdgeInsets.all(small ? 12.0 : 14.0),
      decoration: BoxDecoration(
          color: _tk.surf2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _tk.bd)),
      child: Row(children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: bg,
          backgroundImage: picUrl != null ? NetworkImage(picUrl) : null,
          child: picUrl == null
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: accent, fontWeight: FontWeight.w800))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(name,
                style: TextStyle(
                    color: _tk.txtHead,
                    fontSize: small ? 13.5 : 14,
                    fontWeight: FontWeight.w600))),
      ]),
    );
  }

// ─────────────────────────────────────────────────────────────────────────
//  MONTHLY LOGS DIALOG
// ─────────────────────────────────────────────────────────────────────────
  void _showMonthlyLogsDialog(String teamId, String teamName) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _MonthlyLogsDialog(
        teamId   : teamId,
        teamName : teamName,
        personnel: _personnel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const DsLoading()
        : Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        child: Row(children: [
          Expanded(
              child: DsSearchBar(
                  controller: _searchController,
                  hint: 'Search teams or leader…',
                  onClear: _filterTeams)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showCreateTeamDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_tk.cyan, _tk.cyan.withOpacity(0.82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: _tk.cyan.withOpacity(0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 17),
                const SizedBox(width: 7),
                const Text('Create Team',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _filteredTeams.isEmpty
            ? DsEmpty(
            message: _teams.isEmpty
                ? 'No teams yet.\nTap Create Team to add one.'
                : 'No matching teams.',
            icon: Icons.group_outlined)
            : RefreshIndicator(
          onRefresh: _loadData,
          color: _tk.cyan,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: _filteredTeams.length,
            itemBuilder: (ctx, i) {
              final team        = _filteredTeams[i];
              final leaderPic   = team['foreman']?['profile_pic_url'] as String?;
              final leaderName  = team['foreman']?['name'] as String? ?? 'No leader';
              final memberCount = (team['personnel_ids'] as List?)?.length ?? 0;
              final hasDriver   = team['driver_id'] != null;
              final initial =
              (team['team_name'] as String? ?? '?').substring(0, 1).toUpperCase();
              return GestureDetector(
                onTap: () => _showTeamDetailDialog(team),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _tk.surf,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _tk.bd),
                      boxShadow: _tk.shadowSm),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _tk.cyanBg,
                      backgroundImage:
                      leaderPic != null ? NetworkImage(leaderPic) : null,
                      child: leaderPic == null
                          ? Text(initial,
                          style: TextStyle(
                              color: _tk.cyan,
                              fontSize: 18,
                              fontWeight: FontWeight.w800))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(team['team_name'] ?? 'Unnamed Team',
                                  style: TextStyle(
                                      color: _tk.txtHead,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 3),
                              Row(children: [
                                Text(
                                    'Leader: $leaderName  •  $memberCount member${memberCount == 1 ? '' : 's'}',
                                    style: TextStyle(color: _tk.txtMuted, fontSize: 12.5)),
                                if (hasDriver) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.drive_eta_rounded,
                                      size: 12, color: _tk.amber),
                                ],
                              ]),
                            ])),
                    DsTag('$memberCount', _tk.cyan),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: _tk.bd2, size: 20),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MONTHLY LOGS DIALOG  — full-screen dialog with month timeline
// ─────────────────────────────────────────────────────────────────────────────
class _MonthlyLogsDialog extends StatefulWidget {
  final String                   teamId;
  final String                   teamName;
  final List<Map<String, dynamic>> personnel;

  const _MonthlyLogsDialog({
    required this.teamId,
    required this.teamName,
    required this.personnel,
  });

  @override
  State<_MonthlyLogsDialog> createState() => _MonthlyLogsDialogState();
}

class _MonthlyLogsDialogState extends State<_MonthlyLogsDialog> {
  Tk get _tk => context.tk;

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _error;

  late int _selectedYear;
  final List<int> _availableYears = [];

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await Supabase.instance.client
          .from('team_monthly_logs')
          .select()
          .eq('team_id', widget.teamId)
          .order('year',  ascending: false)
          .order('month', ascending: false);

      final logs = List<Map<String, dynamic>>.from(res);

      final years = logs.map((l) => l['year'] as int).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      if (!years.contains(_selectedYear)) {
        if (years.isNotEmpty) _selectedYear = years.first;
      }

      setState(() {
        _logs           = logs;
        _availableYears
          ..clear()
          ..addAll(years);
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filteredLogs =>
      _logs.where((l) => l['year'] == _selectedYear).toList()
        ..sort((a, b) => (b['month'] as int).compareTo(a['month'] as int));

  String _nameOf(String? id) {
    if (id == null) return '—';
    final p = widget.personnel.firstWhere(
          (p) => p['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    return p['name'] as String? ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 860),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Scaffold(
            backgroundColor: _tk.bg,
            body: Column(children: [

// ── Header ───────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_tk.violet, _tk.violet.withOpacity(0.78)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _LogDotPainter())),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.history_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 5),
                            Text('MONTHLY LINEUP LOGS',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2)),
                          ]),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: Colors.white.withOpacity(0.25)),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 17),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 16),

                      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: Colors.white.withOpacity(0.28)),
                          ),
                          child: const Icon(Icons.calendar_month_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.teamName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4)),
                          Text('Team lineup history by month',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.75), fontSize: 12)),
                        ])),
                        GestureDetector(
                          onTap: _fetchLogs,
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: Colors.white.withOpacity(0.25)),
                            ),
                            child: const Icon(Icons.refresh_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),

// ── Year tabs ─────────────────────────────────────────────────
              if (!_isLoading && _availableYears.isNotEmpty)
                Container(
                  color: _tk.surf,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Row(children: [
                    Text('Year:',
                        style: TextStyle(
                            color: _tk.txtMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _availableYears.map((y) {
                            final isSel = y == _selectedYear;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedYear = y),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSel ? _tk.violet : _tk.surf2,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: isSel ? _tk.violet : _tk.bd,
                                      width: isSel ? 0 : 1),
                                  boxShadow: isSel
                                      ? [BoxShadow(
                                      color: _tk.violet.withOpacity(0.30),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Text('$y',
                                    style: TextStyle(
                                        color: isSel ? Colors.white : _tk.txt,
                                        fontSize: 12.5,
                                        fontWeight: isSel
                                            ? FontWeight.w700
                                            : FontWeight.w500)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ]),
                ),

              if (!_isLoading && _availableYears.isNotEmpty)
                Divider(height: 1, color: _tk.bd),

// ── Content ───────────────────────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const DsLoading()
                    : _error != null
                    ? _buildError()
                    : _logs.isEmpty
                    ? _buildEmpty()
                    : _filteredLogs.isEmpty
                    ? _buildEmptyYear()
                    : _buildTimeline(),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, color: _tk.red, size: 52),
        const SizedBox(height: 14),
        Text('Failed to load logs', style: TextStyle(color: _tk.txtHead, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(_error!, textAlign: TextAlign.center,
            style: TextStyle(color: _tk.txtMuted, fontSize: 12.5)),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _fetchLogs,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              color: _tk.violet.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _tk.violet.withOpacity(0.30)),
            ),
            child: Text('Retry', style: TextStyle(color: _tk.violet, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _tk.violetBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.history_rounded, color: _tk.violet, size: 36),
        ),
        const SizedBox(height: 16),
        Text('No lineup logs yet',
            style: TextStyle(color: _tk.txtHead, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Logs are created automatically when a team\nis created or its lineup is updated.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _tk.txtMuted, fontSize: 13)),
      ]),
    ),
  );

  Widget _buildEmptyYear() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.event_busy_rounded, color: _tk.bd2, size: 48),
      const SizedBox(height: 12),
      Text('No records for $_selectedYear',
          style: TextStyle(color: _tk.txtMuted, fontSize: 14)),
    ]),
  );

  Widget _buildTimeline() {
    final logs = _filteredLogs;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: logs.length,
      itemBuilder: (_, i) {
        final log       = logs[i];
        final month     = log['month'] as int;
        final year      = log['year']  as int;
        final snapshot  = log['snapshot'] as Map<String, dynamic>?;
        final isLast    = i == logs.length - 1;
        final isFirst   = i == 0;

        final foremanId  = log['foreman_id'] as String?;
        final driverId   = log['driver_id']  as String?;
        final memberIds  = (log['personnel_ids'] as List<dynamic>?)
            ?.cast<String>() ?? [];

        final leaderName = snapshot?['leader'] as String? ?? _nameOf(foremanId);
        final driverName = snapshot?['driver'] as String? ?? _nameOf(driverId);
        final memberNames = snapshot?['members'] != null
            ? (snapshot!['members'] as List<dynamic>).cast<String>()
            : memberIds.map(_nameOf).toList();

        final monthLabel = '${_monthNames[month]} $year';
        final isCurrent  = month == DateTime.now().month && year == DateTime.now().year;

        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            SizedBox(
              width: 52,
              child: Column(children: [
                if (!isFirst)
                  Expanded(flex: 1, child: Center(
                    child: Container(width: 2, color: _tk.violet.withOpacity(0.25)),
                  ))
                else
                  const SizedBox(height: 8),

                Container(
                  width: isCurrent ? 44 : 38,
                  height: isCurrent ? 44 : 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent ? _tk.violet : _tk.violetBg,
                    border: Border.all(
                        color: isCurrent ? _tk.violet : _tk.violet.withOpacity(0.35),
                        width: isCurrent ? 0 : 1.5),
                    boxShadow: isCurrent
                        ? [BoxShadow(
                        color: _tk.violet.withOpacity(0.40),
                        blurRadius: 12,
                        offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${month.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: isCurrent ? Colors.white : _tk.violet,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                if (!isLast)
                  Expanded(flex: 3, child: Center(
                    child: Container(width: 2, color: _tk.violet.withOpacity(0.25)),
                  ))
                else
                  const SizedBox(height: 8),
              ]),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? _tk.violet.withOpacity(0.05)
                        : _tk.surf,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isCurrent
                            ? _tk.violet.withOpacity(0.30)
                            : _tk.bd,
                        width: isCurrent ? 1.5 : 1),
                    boxShadow: _tk.shadowSm,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? _tk.violet.withOpacity(0.08)
                            : _tk.surf2,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                        border: Border(bottom: BorderSide(color: _tk.bd)),
                      ),
                      child: Row(children: [
                        Text(monthLabel,
                            style: TextStyle(
                                color: _tk.txtHead,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800)),
                        const Spacer(),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _tk.violet,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(
                                  color: _tk.violet.withOpacity(0.40),
                                  blurRadius: 6)],
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.circle, size: 6, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Current',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                      ]),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        _logRow(Icons.star_rounded, 'Leader', leaderName, _tk.blue),
                        const SizedBox(height: 8),

                        _logRow(Icons.drive_eta_rounded, 'Driver',
                            driverName == '—' ? 'No driver' : driverName, _tk.amber),
                        const SizedBox(height: 8),

                        if (memberNames.isEmpty)
                          _logRow(Icons.people_rounded, 'Members', 'No members', _tk.txtMuted)
                        else ...[
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                  color: _tk.green.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(color: _tk.green.withOpacity(0.22))),
                              child: Icon(Icons.people_rounded, color: _tk.green, size: 13),
                            ),
                            const SizedBox(width: 9),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Members',
                                    style: TextStyle(
                                        color: _tk.txtMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: memberNames.map((name) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _tk.greenBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: _tk.green.withOpacity(0.22)),
                                    ),
                                    child: Text(name,
                                        style: TextStyle(
                                            color: _tk.green,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600)),
                                  )).toList(),
                                ),
                              ],
                            )),
                          ]),
                        ],
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _logRow(IconData icon, String label, String value, Color accent) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: accent.withOpacity(0.22))),
        child: Icon(icon, color: accent, size: 13),
      ),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: _tk.txtMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 1),
        Text(value,
            style: TextStyle(
                color: _tk.txtHead, fontSize: 13, fontWeight: FontWeight.w600)),
      ])),
    ],
  );
}

// ── Dot painter for log dialog header ────────────────────────────────────────
class _LogDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.fill;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
    final ring = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.3), 50, ring);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.9), 72, ring);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  EDIT PERSONNEL TAB
// ─────────────────────────────────────────────────────────────────────────────
class EditPersonnelTab extends StatefulWidget {
  const EditPersonnelTab({super.key});
  @override
  State<EditPersonnelTab> createState() => _EditPersonnelTabState();
}

class _EditPersonnelTabState extends State<EditPersonnelTab> {
  Tk get _tk => context.tk;
  List<Map<String, dynamic>> _personnel = [];
  List<Map<String, dynamic>> _filtered  = [];
  bool _isLoading = true;
  final _searchCtrl  = TextEditingController();
  final _nameCtrl    = TextEditingController();
// ── REMOVED: _contactCtrl and _addressCtrl ──
  String? _selectedPosition;
  File?   _selectedImage;
  final List<String> _positions = ['Team Leader', 'Member', 'Driver'];

  @override
  void initState() {
    super.initState();
    _fetchPersonnel();
    _searchCtrl.addListener(() => _filter(_searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
// ── REMOVED: _contactCtrl.dispose() and _addressCtrl.dispose() ──
    super.dispose();
  }

  Future<void> _fetchPersonnel() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('personnel')
          .select()
          .order('name', ascending: true);
      setState(() {
        _personnel = List<Map<String, dynamic>>.from(res);
        _filtered  = List.from(_personnel);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Error: $e', error: true);
    }
  }

  void _filter(String q) {
    setState(() {
      final l = q.toLowerCase();
      _filtered = l.isEmpty
          ? List.from(_personnel)
          : _personnel.where((p) => (p['name'] as String? ?? '').toLowerCase().contains(l)).toList();
    });
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: error ? _tk.red : _tk.green));
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: _tk.txtMuted, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, color: _tk.txtMuted, size: 18) : null,
    filled: true,
    fillColor: _tk.surf,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _tk.bd)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _tk.bd)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _tk.cyan, width: 1.5)),
  );

  Widget _outlineBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
          color: _tk.surf2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _tk.bd)),
      child: Center(
          child: Text(label,
              style: TextStyle(color: _tk.txt, fontSize: 13.5, fontWeight: FontWeight.w600))),
    ),
  );

  Widget _solidBtn(String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withOpacity(0.82)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [BoxShadow(color: color.withOpacity(0.30), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700))),
    ),
  );

  Future<bool?> _confirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _tk.surf,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), side: BorderSide(color: _tk.bd)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor.withOpacity(0.25))),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    color: _tk.txtHead, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(color: _tk.txtMuted, fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _outlineBtn('Cancel', () => Navigator.pop(ctx, false))),
              const SizedBox(width: 10),
              Expanded(
                  child: _solidBtn(confirmLabel, confirmColor, () => Navigator.pop(ctx, true))),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _deletePerson(Map<String, dynamic> p) async {
    final ok = await _confirmDialog(
      icon: Icons.person_remove_rounded, iconColor: _tk.red,
      title: 'Delete Personnel?',
      body: 'Delete "${p['name']}"? This cannot be undone.',
      confirmLabel: 'Delete', confirmColor: _tk.red,
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('personnel').delete().eq('id', p['id']);
      if (!mounted) return;
      Navigator.pop(context);
      _fetchPersonnel();
      _showSnack('Personnel deleted');
    } catch (e) {
      _showSnack('Error: $e', error: true);
    }
  }

  Future<void> _removePhoto(Map<String, dynamic> p, void Function(void Function()) setS) async {
    final ok = await _confirmDialog(
      icon: Icons.no_photography_rounded, iconColor: _tk.amber,
      title: 'Remove Photo?',
      body: 'Remove the profile photo of "${p['name']}"?',
      confirmLabel: 'Remove', confirmColor: _tk.amber,
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('personnel')
          .update({'profile_pic_url': null}).eq('id', p['id']);
      if (!mounted) return;
      setS(() => p['profile_pic_url'] = null);
      _fetchPersonnel();
      _showSnack('Photo removed');
    } catch (e) {
      _showSnack('Error: $e', error: true);
    }
  }

  Future<void> _pickImage() async {
    final pic = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pic != null) setState(() => _selectedImage = File(pic.path));
  }

  Future<String?> _uploadPhoto(File f, String name) async {
    try {
      final fn =
          '${name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.${f.path.split('.').last}';
      final mime = lookupMimeType(f.path) ?? 'image/jpeg';
      await Supabase.instance.client.storage
          .from('personnel-photos')
          .upload(fn, f, fileOptions: FileOptions(contentType: mime));
      return Supabase.instance.client.storage.from('personnel-photos').getPublicUrl(fn);
    } catch (e) {
      _showSnack('Upload failed: $e', error: true);
      return null;
    }
  }

  void _showPersonnelDialog({
    required String title,
    required String btnLabel,
    String? initialPicUrl,
    Map<String, dynamic>? person,
    required Future<void> Function() onSave,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: _tk.surf,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22), side: BorderSide(color: _tk.bd)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: ConstrainedBox(
// ── Reduced maxHeight since we now have fewer fields ──
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
// Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 20, 18),
                decoration: BoxDecoration(
                    color: _tk.surf,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border(bottom: BorderSide(color: _tk.bd))),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: _tk.cyan.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: _tk.cyan.withOpacity(0.22))),
                    child: Icon(Icons.person_rounded, color: _tk.cyan, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(title,
                          style: TextStyle(
                              color: _tk.txtHead, fontSize: 15, fontWeight: FontWeight.w700))),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                          color: _tk.bd.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close_rounded, color: _tk.txtMuted, size: 16),
                    ),
                  ),
                ]),
              ),

// Body
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
// Avatar picker
                  GestureDetector(
                    onTap: () async {
                      await _pickImage();
                      setS(() {});
                    },
                    child: Stack(alignment: Alignment.bottomRight, children: [
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _tk.bd, width: 2),
                            color: _tk.surf2),
                        child: ClipOval(
                          child: _selectedImage != null
                              ? Image.file(_selectedImage!, fit: BoxFit.cover)
                              : (initialPicUrl != null
                              ? Image.network(initialPicUrl, fit: BoxFit.cover)
                              : Icon(Icons.person_rounded, color: _tk.txtMuted, size: 44)),
                        ),
                      ),
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                            color: _tk.cyan,
                            shape: BoxShape.circle,
                            border: Border.all(color: _tk.surf, width: 2),
                            boxShadow: [
                              BoxShadow(color: _tk.cyan.withOpacity(0.35), blurRadius: 8)
                            ]),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
// ── Name only (contact & address removed) ──
                  TextField(
                      controller: _nameCtrl,
                      style: TextStyle(color: _tk.txtHead, fontSize: 14),
                      decoration: _inputDeco('Full Name *', icon: Icons.badge_outlined)),
                  const SizedBox(height: 14),
// ── Position dropdown ──
                  DropdownButtonFormField<String>(
                    value: _selectedPosition,
                    isExpanded: true,
                    dropdownColor: _tk.surf,
                    style: TextStyle(color: _tk.txtHead, fontSize: 13.5),
                    decoration: _inputDeco('Position *', icon: Icons.work_outline_rounded),
                    hint: Text('Select Position', style: TextStyle(color: _tk.txtMuted)),
                    items: _positions
                        .map((pos) => DropdownMenuItem(value: pos, child: Text(pos)))
                        .toList(),
                    onChanged: (v) => setS(() => _selectedPosition = v),
                  ),
                ]),
              )),

// Footer
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: _tk.bd))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (person != null) ...[
                    Row(children: [
                      Expanded(child: GestureDetector(
                        onTap: person['profile_pic_url'] != null
                            ? () => _removePhoto(person, setS)
                            : null,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                              color: person['profile_pic_url'] != null
                                  ? _tk.amber.withOpacity(0.08)
                                  : _tk.surf2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: person['profile_pic_url'] != null
                                      ? _tk.amber.withOpacity(0.25)
                                      : _tk.bd)),
                          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.no_photography_rounded,
                                color: person['profile_pic_url'] != null
                                    ? _tk.amber
                                    : _tk.bd2,
                                size: 14),
                            const SizedBox(width: 5),
                            Text('Remove Photo',
                                style: TextStyle(
                                    color: person['profile_pic_url'] != null
                                        ? _tk.amber
                                        : _tk.bd2,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ])),
                        ),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: GestureDetector(
                        onTap: () => _deletePerson(person),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                              color: _tk.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _tk.red.withOpacity(0.25))),
                          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.delete_rounded, color: _tk.red, size: 14),
                            const SizedBox(width: 5),
                            Text('Delete Person',
                                style: TextStyle(
                                    color: _tk.red, fontSize: 12, fontWeight: FontWeight.w600)),
                          ])),
                        ),
                      )),
                    ]),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    Expanded(child: _outlineBtn('Cancel', () => Navigator.pop(ctx))),
                    const SizedBox(width: 10),
                    Expanded(child: _solidBtn(btnLabel, _tk.cyan, onSave)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showAddDialog() {
    _nameCtrl.clear();
// ── REMOVED: _contactCtrl.clear() and _addressCtrl.clear() ──
    _selectedPosition = null;
    _selectedImage    = null;
    _showPersonnelDialog(
      title: 'Add New Personnel',
      btnLabel: 'Add',
      onSave: () async {
        final name = _nameCtrl.text.trim();
        if (name.isEmpty || _selectedPosition == null) {
          _showSnack('Name and Position are required', error: true);
          return;
        }
        String? url;
        if (_selectedImage != null) url = await _uploadPhoto(_selectedImage!, name);
        try {
          await Supabase.instance.client.from('personnel').insert({
            'name'           : name,
// ── REMOVED: contact_number and address fields ──
            'position'       : _selectedPosition,
            'profile_pic_url': url,
          });
          if (!mounted) return;
          Navigator.pop(context);
          _fetchPersonnel();
          _showSnack('Added successfully');
        } catch (e) {
          _showSnack('Error: $e', error: true);
        }
      },
    );
  }

  void _showEditDialog(Map<String, dynamic> p) {
    _nameCtrl.text    = p['name'] ?? '';
// ── REMOVED: _contactCtrl.text and _addressCtrl.text assignments ──
    final raw = (p['position'] as String? ?? '').trim().toLowerCase();
    _selectedPosition = raw.contains('leader')
        ? 'Team Leader'
        : raw.contains('driver')
        ? 'Driver'
        : 'Member';
    _selectedImage = null;
    final currentPicUrl = p['profile_pic_url'] as String?;

    _showPersonnelDialog(
      title: 'Edit ${p['name'] ?? 'Person'}',
      btnLabel: 'Save Changes',
      initialPicUrl: currentPicUrl,
      person: p,
      onSave: () async {
        final name = _nameCtrl.text.trim();
        if (name.isEmpty || _selectedPosition == null) {
          _showSnack('Name and Position are required', error: true);
          return;
        }
        String? newUrl = currentPicUrl;
        if (_selectedImage != null) newUrl = await _uploadPhoto(_selectedImage!, name);
        try {
          await Supabase.instance.client.from('personnel').update({
            'name'           : name,
// ── REMOVED: contact_number and address fields ──
            'position'       : _selectedPosition,
            'profile_pic_url': newUrl,
          }).eq('id', p['id']);
          if (!mounted) return;
          Navigator.pop(context);
          _fetchPersonnel();
          _showSnack('Updated successfully');
        } catch (e) {
          _showSnack('Error: $e', error: true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const DsLoading()
        : Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        child: Row(children: [
          Expanded(
              child: DsSearchBar(
                  controller: _searchCtrl,
                  hint: 'Search by name…',
                  onClear: () => _filter(''))),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showAddDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_tk.cyan, _tk.cyan.withOpacity(0.82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: _tk.cyan.withOpacity(0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person_add_rounded, color: Colors.white, size: 17),
                const SizedBox(width: 7),
                const Text('Add Person',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _filtered.isEmpty
            ? DsEmpty(
            message: _personnel.isEmpty
                ? 'No personnel yet.\nTap Add Person to start.'
                : 'No matching results.',
            icon: Icons.people_outlined)
            : RefreshIndicator(
          onRefresh: _fetchPersonnel,
          color: _tk.cyan,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) {
              final p        = _filtered[i];
              final pic      = p['profile_pic_url'] as String?;
              final name     = p['name'] as String? ?? 'Unknown';
              final pos      = p['position'] as String? ?? 'Member';
              final posLower = pos.toLowerCase();
              final isLeader = posLower.contains('leader');
              final isDriver = posLower.contains('driver');
              final avatarColor =
              isLeader ? _tk.violet : isDriver ? _tk.amber : _tk.blue;
              final avatarBg =
              isLeader ? _tk.violetBg : isDriver ? _tk.amberBg : _tk.blueBg;
              final tagLabel = isLeader ? 'Leader' : isDriver ? 'Driver' : 'Member';
              return GestureDetector(
                onTap: () => _showEditDialog(p),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _tk.surf,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _tk.bd),
                      boxShadow: _tk.shadowSm),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: avatarBg,
                      backgroundImage:
                      pic != null ? NetworkImage(pic) : null,
                      child: pic == null
                          ? Text(name[0].toUpperCase(),
                          style: TextStyle(
                              color: avatarColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: TextStyle(
                                      color: _tk.txtHead,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 3),
                              Text(pos,
                                  style:
                                  TextStyle(color: _tk.txtMuted, fontSize: 12.5)),
                            ])),
                    DsTag(tagLabel, avatarColor),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: _tk.bd2, size: 20),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }
}