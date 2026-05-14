// team_jobs_screen.dart
//
// Changes vs original:
//  • Day-separator timeline grouping (same pattern as accomplished_screen)
//  • Hover effect on job cards (_HoverCard wrapper)
//  • Import notification_helper.dart (unchanged from previous update)

import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/session/session.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/data/admin_data.dart';
import 'package:job_order/core/utils/notification_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TeamJobsScreen extends StatefulWidget {
  const TeamJobsScreen({super.key});

  @override
  State<TeamJobsScreen> createState() => _TeamJobsScreenState();
}

class _TeamJobsScreenState extends State<TeamJobsScreen> {
  Tk get _tk => context.tk;
  List<Map<String, dynamic>> _jobOrders         = [];
  List<Map<String, dynamic>> _filteredJobOrders = [];
  List<Map<String, dynamic>> _teams             = [];
  Map<int, Map<String, String>> _usersMap       = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, String>> get workTypes => workTypesNotifier.items
      .map((e) => {'code': e.code, 'name': e.name})
      .toList();

  List<Map<String, String>> get damagedOptions => damageSpacesNotifier.items
      .map((e) => {'code': e.code, 'name': e.name})
      .toList();

  String _workTypeName(String? code) {
    if (code == null) return '—';
    return workTypes.firstWhere((e) => e['code'] == code,
        orElse: () => {'code': code, 'name': code})['name']!;
  }

  String _damagedName(String? code) {
    if (code == null) return '—';
    return damagedOptions.firstWhere((e) => e['code'] == code,
        orElse: () => {'code': code, 'name': code})['name']!;
  }

  static const List<String> _shiftTimes = [
    '6:00 AM – 2:00 PM',
    '8:00 AM – 5:00 PM',
    '2:00 PM – 10:00 PM',
  ];

  final List<String> addresses = [
    'Bagong Bayan I-C', 'Bagong Pook VI-C',
    'Barangay I-A', 'Barangay I-B', 'Barangay II-A', 'Barangay II-B',
    'Barangay II-C', 'Barangay II-D', 'Barangay II-E', 'Barangay II-F',
    'Barangay III-A', 'Barangay III-B', 'Barangay III-C', 'Barangay III-D',
    'Barangay III-E', 'Barangay III-F', 'Barangay IV-A', 'Barangay IV-B',
    'Barangay IV-C', 'Barangay V-A', 'Barangay V-B', 'Barangay V-C',
    'Barangay V-D', 'Barangay VI-A', 'Barangay VI-B', 'Barangay VI-D',
    'Barangay VI-E', 'Barangay VII-A', 'Barangay VII-B', 'Barangay VII-C',
    'Barangay VII-D', 'Barangay VII-E', 'Bautista', 'Concepcion',
    'Del Remedio', 'Dolores', 'San Antonio I', 'San Antonio II',
    'San Bartolome', 'San Buenaventura', 'San Crispin', 'San Cristobal',
    'San Diego', 'San Francisco', 'San Gabriel', 'San Gregorio',
    'San Ignacio', 'San Isidro', 'San Joaquin', 'San Jose', 'San Juan',
    'San Lorenzo', 'San Lucas I', 'San Lucas II', 'San Marcos', 'San Mateo',
    'San Miguel', 'San Nicolas', 'San Pedro', 'San Rafael', 'San Roque',
    'San Vicente', 'Sta Ana', 'Sta Catalina', 'Sta Cruz', 'Sta Felomina',
    'Sta Isabel', 'Sta Ma. Magdalena', 'Sta Veronica', 'Santiago I',
    'Santiago II', 'Stmo. Rosario', 'Sto Angel', 'Sto Cristo', 'Sto Nino',
    'Soledad', 'Sta Monica', 'Sta Maria', 'Sta Elena',
    'Others / No Address Listed',
  ];

  @override
  void initState() {
    super.initState();
    _fetchJobOrders();
    _loadTeams();
    _loadUsers();
    _searchController.addListener(_filterJobOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('id, full_name, username');
      if (mounted) {
        final map = <int, Map<String, String>>{};
        for (final u in res as List<dynamic>) {
          map[u['id'] as int] = {
            'full_name': u['full_name'] as String? ?? '',
            'username':  u['username']  as String? ?? '',
          };
        }
        setState(() => _usersMap = map);
      }
    } catch (_) {}
  }

  Future<void> _loadTeams() async {
    try {
      final response = await Supabase.instance.client
          .from('teams')
          .select(
          'id, team_name, foreman_id, personnel_ids, '
              'foreman:foreman_id (name, profile_pic_url)')
          .order('team_name');
      final teamsWithMembers = <Map<String, dynamic>>[];
      for (final team in response) {
        final membersRes = await Supabase.instance.client
            .from('personnel')
            .select('id, name, profile_pic_url')
            .inFilter('id', team['personnel_ids'] ?? []);
        teamsWithMembers.add({...team, 'members': membersRes});
      }
      if (mounted) setState(() => _teams = teamsWithMembers);
    } catch (_) {}
  }

  Future<void> _fetchJobOrders() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('job_orders')
          .select('''
            id, jo_number, shift_index, shift_time, team_id,
            team:team_id (team_name),
            work_type_code, work_type_name, difficulty_level,
            damaged_space_code, damaged_space_name,
            address, remarks, zone,
            created_at, updated_at, status, created_by_user_id
          ''')
          .eq('status', 'pending')
          .not('team_id', 'is', null)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _jobOrders         = List<Map<String, dynamic>>.from(response);
          _filteredJobOrders = List.from(_jobOrders);
          _isLoading         = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error loading job orders: $e'),
            backgroundColor: _tk.red));
      }
    }
  }

  void _filterJobOrders() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filteredJobOrders = List.from(_jobOrders);
      } else {
        _filteredJobOrders = _jobOrders.where((job) {
          final jo    = job['jo_number']?.toString().toLowerCase()          ?? '';
          final team  = job['team']?['team_name']?.toString().toLowerCase() ?? '';
          final wt    = job['work_type_name']?.toString().toLowerCase()     ?? '';
          final shift = job['shift_time']?.toString().toLowerCase()         ?? '';
          final addr  = job['address']?.toString().toLowerCase()            ?? '';
          return jo.contains(q) || team.contains(q) || wt.contains(q) ||
              shift.contains(q) || addr.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _updateJobOrder(String jobId, Map<String, dynamic> updates) async {
    try {
      await Supabase.instance.client.from('job_orders').update(updates).eq('id', jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Job Order updated successfully'),
            backgroundColor: _tk.green));
      }
      _fetchJobOrders();
    } catch (e) {
      if (mounted) {
        String msg = 'Update failed: $e';
        if (e.toString().contains('unique constraint') ||
            e.toString().contains('duplicate key')) {
          msg = 'This J.O Number already exists. Please choose another.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: _tk.red));
      }
    }
  }

  Future<void> _markAsAccomplished(
      String jobId, {
        int? zone,
        required Map<String, dynamic> job,
      }) async {
    try {
      await Supabase.instance.client.from('job_orders').update({
        'status':       'accomplished',
        'completed_at': DateTime.now().toIso8601String(),
        'zone':         zone,
        'accomplished_by_user_id': AppSession.instance.userId,
      }).eq('id', jobId);

      final teamId = job['team_id']?.toString() ?? '';
      if (teamId.isNotEmpty) {
        await NotificationHelper.notifyJobAccomplished(
          teamId:       teamId,
          joNumber:     job['jo_number']?.toString()      ?? '',
          workTypeName: job['work_type_name']?.toString() ?? '',
          address:      job['address']?.toString()        ?? '',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Job marked as Accomplished!'),
            backgroundColor: _tk.green));
      }
      _fetchJobOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: _tk.red));
      }
    }
  }

  String _formatDate(dynamic ts, {bool showTime = true}) {
    if (ts == null) return '—';
    final date = DateTime.parse(ts.toString()).toLocal();
    return DateFormat(showTime ? 'MMM d, yyyy • h:mm a' : 'MMM d, yyyy').format(date);
  }

  // ── Timeline grouping ─────────────────────────────────────────────────────
  // Groups _filteredJobOrders by their created_at local calendar date and injects
  // date-separator maps between each group, identical in pattern to accomplished_screen.
  List<dynamic> _buildTimelineItems() {
    final items = <dynamic>[];
    String? lastDateKey;

    // Count jobs per day first so the separator can show the total
    final counts = <String, int>{};
    for (final job in _filteredJobOrders) {
      final ts = job['created_at'] as String?;
      if (ts == null) continue;
      final dt  = DateTime.parse(ts).toLocal();
      final key = DateFormat('yyyy-MM-dd').format(dt);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    for (final job in _filteredJobOrders) {
      final ts  = job['created_at'] as String?;
      final dt  = ts != null ? DateTime.parse(ts).toLocal() : null;
      final key = dt != null ? DateFormat('yyyy-MM-dd').format(dt) : '__null__';

      if (key != lastDateKey) {
        lastDateKey = key;
        final now       = DateTime.now();
        final today     = DateFormat('yyyy-MM-dd').format(now);
        final yesterday = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

        String label;
        if (dt == null) {
          label = 'Unknown Date';
        } else if (key == today) {
          label = 'Today — ${DateFormat('MMMM d, yyyy').format(dt)}';
        } else if (key == yesterday) {
          label = 'Yesterday — ${DateFormat('MMMM d, yyyy').format(dt)}';
        } else {
          label = DateFormat('MMMM d, yyyy').format(dt);
        }

        items.add({'_separator': true, 'label': label, 'count': counts[key] ?? 0});
      }
      items.add(job);
    }
    return items;
  }

  // Builds the ── May 14, 2026 · 3 jobs ── divider row
  Widget _buildDaySeparator(String label, int count) {
    final isDark = _tk.dark;
    final accent = _tk.blue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Row(children: [
        Expanded(
          child: Divider(
            height: 1, thickness: 1,
            color: isDark ? const Color(0xFF1E2E47) : const Color(0xFFE2E8F0),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101827) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF1E2E47) : const Color(0xFFDDE6F0),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: isDark ? const Color(0xFFAFC4DE) : const Color(0xFF475569),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            )),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text('· $count job${count == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF475F7E) : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            height: 1, thickness: 1,
            color: isDark ? const Color(0xFF1E2E47) : const Color(0xFFE2E8F0),
          ),
        ),
      ]),
    );
  }

  // ── Edit Dialog ───────────────────────────────────────────────────────────
  void _showEditJobOrderDialog(Map<String, dynamic> job) {
    final tk             = _tk;
    final joCtrl         = TextEditingController(text: job['jo_number'] ?? '');
    final remarksCtrl    = TextEditingController(text: job['remarks'] ?? '');
    final zoneCtrl       = TextEditingController(text: job['zone']?.toString() ?? '');
    final customAddrCtrl = TextEditingController();

    String? selectedTeamId  = job['team_id'] as String?;
    String? workTypeCode     = job['work_type_code'] as String?;
    int?    difficultyLevel  = job['difficulty_level'] as int?;
    String? damagedCode      = job['damaged_space_code'] as String?;

    final savedAddr = job['address'] as String?;
    String? selectedAddress =
    (savedAddr != null && addresses.contains(savedAddr)) ? savedAddr : null;
    bool showCustomAddress =
        savedAddr != null && savedAddr.isNotEmpty && !addresses.contains(savedAddr);
    if (showCustomAddress) customAddrCtrl.text = savedAddr!;

    int selectedShiftIndex = 0;
    final savedShift = job['shift_time'] as String?;
    if (savedShift != null) {
      final idx = _shiftTimes.indexOf(savedShift);
      if (idx >= 0) selectedShiftIndex = idx;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final teamItems = <DropdownMenuItem<String>>[
            ..._teams.map((t) => DropdownMenuItem<String>(
              value: t['id'] as String,
              child: Text(t['team_name'] ?? 'Unnamed',
                  style: TextStyle(color: tk.txtHead)),
            )),
          ];
          if (selectedTeamId != null &&
              !_teams.any((t) => t['id'] == selectedTeamId)) {
            teamItems.insert(0, DropdownMenuItem<String>(
              value: selectedTeamId,
              child: Text('Current Team', style: TextStyle(color: tk.txtMuted)),
            ));
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 860),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Scaffold(
                  backgroundColor: tk.bg,
                  body: Column(children: [

                    // Hero header
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tk.blue, tk.blue.withOpacity(0.78)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(children: [
                        Positioned.fill(child: CustomPaint(painter: _DotPainter())),
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
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.edit_note_rounded, color: Colors.white, size: 12),
                                  const SizedBox(width: 5),
                                  Text(job['jo_number'] ?? 'EDIT J.O.',
                                      style: const TextStyle(color: Colors.white, fontSize: 10.5,
                                          fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                                ]),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => Navigator.pop(ctx),
                                child: Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 17),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            Row(children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.20),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                                ),
                                child: const Icon(Icons.work_history_rounded,
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Edit Job Order',
                                    style: TextStyle(color: Colors.white, fontSize: 20,
                                        fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                                Text('Last updated: ${_formatDate(job['updated_at'])}',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.72), fontSize: 11.5)),
                              ])),
                            ]),
                          ]),
                        ),
                      ]),
                    ),

                    // Form body
                    Expanded(child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(22),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        _sectionLabel('J.O. Number'),
                        TextField(
                          controller: joCtrl,
                          style: TextStyle(color: tk.txtHead, fontSize: 14),
                          decoration: dsInputOf(context, '',
                              hint: 'e.g. JO-2025-001', icon: Icons.tag_rounded),
                        ),

                        const SizedBox(height: 18),

                        _sectionLabel('Assigned Team'),
                        Container(
                          decoration: BoxDecoration(
                            color: tk.surf,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: tk.bd),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedTeamId,
                              isExpanded: true,
                              dropdownColor: tk.surf,
                              style: TextStyle(color: tk.txtHead, fontSize: 14),
                              hint: Text('Select Team', style: TextStyle(color: tk.txtMuted)),
                              items: teamItems,
                              onChanged: (v) => setS(() => selectedTeamId = v),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        _sectionLabel('Shift Time'),
                        Column(children: List.generate(_shiftTimes.length, (i) {
                          final isSel = selectedShiftIndex == i;
                          return GestureDetector(
                            onTap: () => setS(() => selectedShiftIndex = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSel ? tk.blueBg : tk.surf2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isSel ? tk.blue.withOpacity(0.5) : tk.bd,
                                    width: isSel ? 1.5 : 1),
                              ),
                              child: Row(children: [
                                Icon(Icons.schedule_rounded,
                                    color: isSel ? tk.blue : tk.txtMuted, size: 16),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_shiftTimes[i],
                                    style: TextStyle(
                                        color: isSel ? tk.txtHead : tk.txt,
                                        fontSize: 13.5,
                                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w400))),
                                if (isSel)
                                  Container(
                                    width: 18, height: 18,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle, color: tk.blue),
                                    child: const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 11),
                                  ),
                              ]),
                            ),
                          );
                        })),

                        const SizedBox(height: 18),

                        _sectionLabel('Type of Work *'),
                        _dropdownTile(
                          icon: Icons.build_rounded,
                          label: workTypeCode == null
                              ? 'Select type of work…'
                              : _workTypeName(workTypeCode),
                          isSelected: workTypeCode != null,
                          accent: tk.blue,
                          onTap: () => _showWorkTypeSheet(ctx, workTypeCode, (code) {
                            setS(() => workTypeCode = code);
                          }),
                        ),

                        const SizedBox(height: 18),

                        _sectionLabel('Difficulty Level *'),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          for (final entry in [
                            [1, 'Minor', tk.cyan],
                            [2, 'Moderate', tk.amber],
                            [3, 'Major', tk.red],
                          ] as List<List<Object>>)
                            Builder(builder: (_) {
                              final level     = entry[0] as int;
                              final lbl       = entry[1] as String;
                              final chipColor = entry[2] as Color;
                              final isSel     = difficultyLevel == level;
                              return GestureDetector(
                                onTap: () => setS(() =>
                                difficultyLevel = isSel ? null : level),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? chipColor.withOpacity(0.10)
                                        : tk.surf2,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: isSel
                                            ? chipColor.withOpacity(0.50)
                                            : tk.bd,
                                        width: isSel ? 1.5 : 1),
                                    boxShadow: isSel
                                        ? [BoxShadow(
                                        color: chipColor.withOpacity(0.15),
                                        blurRadius: 8)]
                                        : null,
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    if (isSel) ...[
                                      Icon(Icons.check_rounded,
                                          color: chipColor, size: 13),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(lbl, style: TextStyle(
                                        color: isSel ? chipColor : tk.txt,
                                        fontSize: 13.5,
                                        fontWeight: isSel
                                            ? FontWeight.w700
                                            : FontWeight.w500)),
                                  ]),
                                ),
                              );
                            }),
                        ]),

                        const SizedBox(height: 18),

                        _sectionLabel('Damaged Working Space *'),
                        _dropdownTile(
                          icon: Icons.foundation_rounded,
                          label: damagedCode == null
                              ? 'Select damaged space…'
                              : _damagedName(damagedCode),
                          isSelected: damagedCode != null,
                          accent: tk.amber,
                          onTap: () => _showDamagedSpaceSheet(ctx, damagedCode, (code) {
                            setS(() => damagedCode = code);
                          }),
                        ),

                        const SizedBox(height: 18),

                        _sectionLabel('Address / Barangay *'),
                        if (selectedAddress != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: tk.blueBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: tk.blueBd),
                            ),
                            child: Row(children: [
                              Icon(Icons.location_on_rounded,
                                  color: tk.blue, size: 15),
                              const SizedBox(width: 8),
                              Expanded(child: Text(selectedAddress!,
                                  style: TextStyle(color: tk.txtHead,
                                      fontSize: 13, fontWeight: FontWeight.w600))),
                              GestureDetector(
                                onTap: () => setS(() => selectedAddress = null),
                                child: Icon(Icons.close_rounded,
                                    color: tk.txtMuted, size: 15),
                              ),
                            ]),
                          ),
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: tk.surf,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: tk.bd),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: addresses.length,
                            itemBuilder: (_, i) {
                              final addr  = addresses[i];
                              final isSel = selectedAddress == addr;
                              return GestureDetector(
                                onTap: () => setS(() {
                                  selectedAddress = addr;
                                  showCustomAddress =
                                      addr == 'Others / No Address Listed';
                                  if (!showCustomAddress) customAddrCtrl.clear();
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: isSel ? tk.blueBg : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: isSel ? tk.blueBd : Colors.transparent),
                                  ),
                                  child: Row(children: [
                                    Icon(
                                      isSel
                                          ? Icons.check_circle_rounded
                                          : Icons.location_on_outlined,
                                      color: isSel ? tk.blue : tk.txtMuted,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(addr,
                                        style: TextStyle(
                                            color: isSel ? tk.txtHead : tk.txt,
                                            fontSize: 12.5,
                                            fontWeight: isSel
                                                ? FontWeight.w600
                                                : FontWeight.w400))),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                        if (showCustomAddress) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: customAddrCtrl,
                            maxLines: 2,
                            style: TextStyle(color: tk.txtHead, fontSize: 13.5),
                            decoration: dsInputOf(context, '',
                                hint: 'Enter custom address…',
                                icon: Icons.edit_location_rounded),
                          ),
                        ],

                        const SizedBox(height: 18),

                        _sectionLabel('Remarks / Specific Location (optional)'),
                        TextField(
                          controller: remarksCtrl,
                          maxLines: 3,
                          style: TextStyle(color: tk.txtHead, fontSize: 13.5),
                          decoration: dsInputOf(context, '',
                              hint: 'e.g. near the old market',
                              icon: Icons.notes_rounded),
                        ),

                        const SizedBox(height: 18),

                        _sectionLabel('Zone (optional)'),
                        TextField(
                          controller: zoneCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: tk.txtHead, fontSize: 13.5),
                          decoration: dsInputOf(context, '',
                              hint: 'Enter zone number',
                              icon: Icons.pin_drop_outlined),
                        ),

                        const SizedBox(height: 8),
                      ]),
                    )),

                    // Footer
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                      decoration: BoxDecoration(
                        color: tk.surf,
                        border: Border(top: BorderSide(color: tk.bd)),
                      ),
                      child: Column(children: [

                        // Mark as Accomplished button
                        GestureDetector(
                          onTap: () {
                            final zoneNum = int.tryParse(zoneCtrl.text.trim());
                            showDialog(
                              context: ctx,
                              builder: (_) => Dialog(
                                backgroundColor: tk.surf,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(color: tk.bd)),
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      width: 52, height: 52,
                                      decoration: BoxDecoration(
                                        color: tk.greenBg,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: tk.green.withOpacity(0.3)),
                                      ),
                                      child: Icon(Icons.check_circle_rounded,
                                          color: tk.green, size: 26),
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Mark as Accomplished?',
                                        style: TextStyle(color: tk.txtHead,
                                            fontSize: 16, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 8),
                                    Text(
                                        zoneNum != null
                                            ? 'Zone: $zoneNum'
                                            : 'No zone specified',
                                        style: TextStyle(color: tk.txtMuted, fontSize: 13)),
                                    const SizedBox(height: 24),
                                    Row(children: [
                                      Expanded(child: GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                              color: tk.surf2,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: tk.bd)),
                                          child: Center(child: Text('Cancel',
                                              style: TextStyle(color: tk.txt,
                                                  fontWeight: FontWeight.w600))),
                                        ),
                                      )),
                                      const SizedBox(width: 10),
                                      Expanded(child: GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.pop(ctx);
                                          _markAsAccomplished(
                                            job['id'] as String,
                                            zone: zoneNum,
                                            job: job,
                                          );
                                        },
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                colors: [
                                                  tk.green,
                                                  tk.green.withOpacity(0.82)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight),
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [BoxShadow(
                                                color: tk.green.withOpacity(0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3))],
                                          ),
                                          child: const Center(
                                              child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.check_rounded,
                                                        color: Colors.white, size: 16),
                                                    SizedBox(width: 6),
                                                    Text('Confirm',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.w700)),
                                                  ])),
                                        ),
                                      )),
                                    ]),
                                  ]),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: tk.greenBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: tk.green.withOpacity(0.3)),
                            ),
                            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.task_alt_rounded, color: tk.green, size: 17),
                              const SizedBox(width: 7),
                              Text('Mark as Accomplished',
                                  style: TextStyle(color: tk.green,
                                      fontSize: 14, fontWeight: FontWeight.w700)),
                            ])),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: tk.surf2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tk.bd),
                              ),
                              child: Center(child: Text('Cancel',
                                  style: TextStyle(color: tk.txt,
                                      fontSize: 13.5, fontWeight: FontWeight.w600))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: GestureDetector(
                            onTap: () async {
                              final joNum = joCtrl.text.trim();
                              if (joNum.isEmpty || workTypeCode == null ||
                                  difficultyLevel == null || damagedCode == null ||
                                  (selectedAddress == null && !showCustomAddress)) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                    content: const Text(
                                        'Please complete all required fields'),
                                    backgroundColor: tk.red));
                                return;
                              }
                              final finalAddr = showCustomAddress
                                  ? (customAddrCtrl.text.trim().isNotEmpty
                                  ? customAddrCtrl.text.trim()
                                  : 'No address')
                                  : (selectedAddress ?? 'No address selected');

                              final updates = {
                                'jo_number':          joNum,
                                if (selectedTeamId != null)
                                  'team_id': selectedTeamId,
                                'shift_time':         _shiftTimes[selectedShiftIndex],
                                'shift_index':        selectedShiftIndex,
                                'work_type_code':     workTypeCode,
                                'work_type_name':     _workTypeName(workTypeCode),
                                'difficulty_level':   difficultyLevel,
                                'damaged_space_code': damagedCode,
                                'damaged_space_name': _damagedName(damagedCode),
                                'address':            finalAddr,
                                'remarks':
                                remarksCtrl.text.trim().isNotEmpty
                                    ? remarksCtrl.text.trim()
                                    : null,
                                'zone':
                                zoneCtrl.text.trim().isNotEmpty
                                    ? int.tryParse(zoneCtrl.text.trim())
                                    : null,
                                'edited_by_user_id':  AppSession.instance.userId,
                                'edited_at':
                                DateTime.now().toIso8601String(),
                              };
                              await _updateJobOrder(job['id'] as String, updates);
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [tk.blue, tk.blue.withOpacity(0.82)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(
                                    color: tk.blue.withOpacity(0.32),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4))],
                              ),
                              child: const Center(
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.save_rounded,
                                        color: Colors.white, size: 17),
                                    SizedBox(width: 7),
                                    Text('Save Changes',
                                        style: TextStyle(color: Colors.white,
                                            fontSize: 14, fontWeight: FontWeight.w700)),
                                  ])),
                            ),
                          )),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: TextStyle(color: _tk.txtHead, fontSize: 13,
            fontWeight: FontWeight.w600)),
  );

  Widget _dropdownTile({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final tk = _tk;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.06) : tk.surf,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? accent.withOpacity(0.45) : tk.bd,
              width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 8)]
              : tk.shadowSm,
        ),
        child: Row(children: [
          Icon(icon, size: 17, color: isSelected ? accent : tk.txtMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(label,
              style: TextStyle(
                  color: isSelected ? tk.txtHead : tk.txtMuted,
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: isSelected ? accent : tk.txtMuted, size: 20),
        ]),
      ),
    );
  }

  void _showWorkTypeSheet(
      BuildContext ctx, String? current, Function(String) onSelect) {
    final tk = _tk;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65, minChildSize: 0.5, maxChildSize: 0.92,
        expand: false,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
              color: tk.surf,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: tk.bd))),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                    width: 42, height: 5,
                    decoration: BoxDecoration(
                        color: tk.bd2,
                        borderRadius: BorderRadius.circular(10)))),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(children: [
                  Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: tk.blueBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tk.blueBd)),
                      child: Icon(Icons.build_rounded, color: tk.blue, size: 17)),
                  const SizedBox(width: 12),
                  Text('Type of Work', style: TextStyle(
                      color: tk.txtHead, fontSize: 16,
                      fontWeight: FontWeight.w800)),
                ])),
            Divider(height: 1, color: tk.bd),
            Expanded(child: workTypes.isEmpty
                ? Center(child: Text('No work types available',
                style: TextStyle(color: tk.txtMuted)))
                : ListView.builder(
              controller: sc,
              itemCount: workTypes.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (_, i) {
                final wt     = workTypes[i];
                final isSel  = current == wt['code'];
                final accent = _accentForWorkCode(wt['code']);
                return GestureDetector(
                  onTap: () {
                    onSelect(wt['code']!);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSel ? accent.withOpacity(0.07) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSel
                              ? accent.withOpacity(0.30)
                              : Colors.transparent),
                    ),
                    child: Row(children: [
                      Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                              color: isSel
                                  ? accent.withOpacity(0.14)
                                  : tk.surf2,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: isSel
                                      ? accent.withOpacity(0.28)
                                      : tk.bd)),
                          child: Center(child: Text(wt['code']!,
                              style: TextStyle(
                                  color: isSel ? accent : tk.txtMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(wt['name']!,
                          style: TextStyle(
                              color: isSel ? tk.txtHead : tk.txt,
                              fontSize: 14,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w400))),
                      if (isSel)
                        Icon(Icons.check_circle_rounded,
                            color: accent, size: 20),
                    ]),
                  ),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  void _showDamagedSpaceSheet(
      BuildContext ctx, String? current, Function(String) onSelect) {
    final tk = _tk;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45, minChildSize: 0.35, maxChildSize: 0.70,
        expand: false,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
              color: tk.surf,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: tk.bd))),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                    width: 42, height: 5,
                    decoration: BoxDecoration(
                        color: tk.bd2,
                        borderRadius: BorderRadius.circular(10)))),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(children: [
                  Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: tk.amberBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tk.amberBd)),
                      child: Icon(Icons.foundation_rounded,
                          color: tk.amber, size: 17)),
                  const SizedBox(width: 12),
                  Text('Damaged Working Space', style: TextStyle(
                      color: tk.txtHead, fontSize: 16,
                      fontWeight: FontWeight.w800)),
                ])),
            Divider(height: 1, color: tk.bd),
            Expanded(child: damagedOptions.isEmpty
                ? Center(child: Text('No options available',
                style: TextStyle(color: tk.txtMuted)))
                : ListView.builder(
              controller: sc,
              itemCount: damagedOptions.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (_, i) {
                final opt   = damagedOptions[i];
                final isSel = current == opt['code'];
                return GestureDetector(
                  onTap: () {
                    onSelect(opt['code']!);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSel ? tk.amberBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSel ? tk.amberBd : Colors.transparent),
                    ),
                    child: Row(children: [
                      Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                              color: isSel
                                  ? tk.amber.withOpacity(0.14)
                                  : tk.surf2,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: isSel
                                      ? tk.amber.withOpacity(0.28)
                                      : tk.bd)),
                          child: Center(child: Text(opt['code']!,
                              style: TextStyle(
                                  color: isSel ? tk.amber : tk.txtMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(opt['name']!,
                          style: TextStyle(
                              color: isSel ? tk.txtHead : tk.txt,
                              fontSize: 14,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w400))),
                      if (isSel)
                        Icon(Icons.check_circle_rounded,
                            color: tk.amber, size: 20),
                    ]),
                  ),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  Color _accentForWorkCode(String? code) {
    final tk = _tk;
    switch (code) {
      case '101': return tk.blue;
      case '102': return tk.cyan;
      case '103': return tk.violet;
      case '104': return tk.amber;
      case '201': return tk.green;
      case '202': return tk.red;
      case '203': return tk.indigo;
      case '301': return tk.pink;
      default:    return tk.txtMuted;
    }
  }

  Widget _buildCreatedByChip(dynamic userId) {
    if (userId == null) return const SizedBox.shrink();
    final id   = userId is int ? userId : int.tryParse(userId.toString());
    if (id == null) return const SizedBox.shrink();
    final user = _usersMap[id];
    if (user == null) return const SizedBox.shrink();
    final display = user['full_name']!.isNotEmpty
        ? user['full_name']!
        : '@${user['username']}';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.person_outline_rounded, size: 11, color: _tk.txtMuted),
      const SizedBox(width: 3),
      Text('by $display', style: TextStyle(
          fontSize: 11, color: _tk.txtMuted, fontWeight: FontWeight.w500)),
    ]);
  }

  // ── Job card (with hover effect) ──────────────────────────────────────────
  Widget _buildJobOrderCard(Map<String, dynamic> job) {
    final tk          = _tk;
    final displayTeam = job['team']?['team_name'] ?? '—';
    final workCode    = job['work_type_code'] as String?;
    final accent      = _accentForWorkCode(workCode);
    final diff        = job['difficulty_level'] as int? ?? 2;
    final diffLabel   = {1: 'Minor', 2: 'Moderate', 3: 'Major'}[diff] ?? '—';
    final diffColor   = {1: tk.cyan, 2: tk.amber, 3: tk.red}[diff] ?? tk.amber;

    return _HoverCard(
      accent: accent,
      onTap: () => _showEditJobOrderDialog(job),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Row(children: [
          // Left colored side strip
          Container(width: 5, color: accent),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              // J.O. number badge
              Container(
                width: 88,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [accent, accent.withOpacity(0.82)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [BoxShadow(
                      color: accent.withOpacity(0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2))],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(job['jo_number'] ?? '—',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 14),
              // Middle info column
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${job['shift_time'] ?? '—'} • $displayTeam',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tk.txtHead,
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('${workCode ?? '—'} – ${job['work_type_name'] ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tk.txtMuted, fontSize: 12.5)),
                    if ((job['address'] ?? '').toString().isNotEmpty)
                      Row(children: [
                        Icon(Icons.location_on_rounded,
                            size: 11, color: tk.txtMuted),
                        const SizedBox(width: 3),
                        Expanded(child: Text(job['address'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: tk.txtMuted, fontSize: 12))),
                      ]),
                    if ((job['remarks'] ?? '').toString().trim().isNotEmpty)
                      Text(job['remarks'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tk.txtMuted,
                              fontSize: 11.5, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    _buildCreatedByChip(job['created_by_user_id']),
                  ])),
              const SizedBox(width: 10),
              // Right badges + edit icon
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: diffColor.withOpacity(0.28)),
                  ),
                  child: Text(diffLabel,
                      style: TextStyle(color: diffColor,
                          fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tk.amberBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tk.amberBd),
                  ),
                  child: Text(job['damaged_space_code'] ?? '—',
                      style: TextStyle(color: tk.amber,
                          fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                      color: tk.blueBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tk.blueBd)),
                  child: Icon(Icons.edit_rounded, color: tk.blue, size: 15),
                ),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = _tk;
    return Scaffold(
      backgroundColor: tk.bg,
      body: Column(children: [
        DsHeader(
          title: 'Job Orders',
          subtitle: 'Assigned job orders by team • Tap to edit',
          icon: Icons.work_history_rounded,
          accent: tk.blue,
          actions: [
            GestureDetector(
              onTap: _fetchJobOrders,
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: tk.surf2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tk.bd)),
                child: Icon(Icons.refresh_rounded, color: tk.txtMuted, size: 18),
              ),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: DsSearchBar(
              controller: _searchController,
              hint: 'Search by J.O#, team, work type, shift, address…',
              onClear: () =>
                  setState(() => _filteredJobOrders = _jobOrders)),
        ),

        Expanded(
          child: _isLoading
              ? const DsLoading()
              : _filteredJobOrders.isEmpty
              ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.work_history_outlined, size: 80, color: tk.bd2),
                const SizedBox(height: 20),
                Text(
                    _searchController.text.isEmpty
                        ? 'No assigned job orders yet'
                        : 'No matching job orders',
                    style: TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w700, color: tk.txtMuted)),
                const SizedBox(height: 8),
                Text(
                    _searchController.text.isEmpty
                        ? 'Assign a team in Job Order tab first'
                        : 'Try a different search term',
                    style: TextStyle(color: tk.txtMuted, fontSize: 13.5)),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: _fetchJobOrders,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 13),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [tk.blue, tk.blue.withOpacity(0.82)]),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(
                            color: tk.blue.withOpacity(0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 4))]),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.refresh_rounded, color: Colors.white, size: 17),
                      SizedBox(width: 7),
                      Text('Refresh', style: TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]))
              : RefreshIndicator(
            onRefresh: _fetchJobOrders,
            color: tk.blue,
            child: Builder(builder: (context) {
              // Build flat list with date separators injected between day groups
              final timelineItems = _buildTimelineItems();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                itemCount: timelineItems.length,
                itemBuilder: (context, index) {
                  final item = timelineItems[index];
                  // Render a day-separator row for separator entries
                  if (item is Map && item['_separator'] == true) {
                    return _buildDaySeparator(
                      item['label'] as String,
                      item['count'] as int,
                    );
                  }
                  // Otherwise render a hoverable job card
                  return _buildJobOrderCard(item as Map<String, dynamic>);
                },
              );
            }),
          ),
        ),
      ]),
    );
  }
}

// ── Hover card wrapper ────────────────────────────────────────────────────────
// Uses MouseRegion + AnimatedContainer to lift and brighten the card on hover,
// and scales it very slightly for a satisfying desktop feel.
class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accent;

  const _HoverCard({
    required this.child,
    required this.onTap,
    required this.accent,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tk     = context.tk;
    final isDark = tk.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter:  (_) => setState(() => _hovered = true),
      onExit:   (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            // Slightly increase bottom gap on hover so the card visually "lifts"
            _hovered ? 14 : 10,
          ),
          // Transform is applied via a Transform widget below; AnimatedContainer
          // handles color + shadow changes here.
          decoration: BoxDecoration(
            color: _hovered
                ? (isDark
                ? const Color(0xFF162032)   // slightly lighter dark surface
                : Colors.white)
                : tk.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? widget.accent.withOpacity(isDark ? 0.45 : 0.35)
                  : tk.bd,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? [
              BoxShadow(
                color: widget.accent.withOpacity(isDark ? 0.18 : 0.14),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.30 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : tk.shadowSm,
          ),
          // Animate a tiny upward translate + scale for the "lift" feel
          child: AnimatedScale(
            scale: _hovered ? 1.008 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ── Dot painter ───────────────────────────────────────────────────────────────
class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.fill;
    const step = 26.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
    final ring = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.2), 52, ring);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.85), 72, ring);
  }

  @override
  bool shouldRepaint(_) => false;
}