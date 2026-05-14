import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/session/session.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/data/admin_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SkeletalTeamScreen extends StatefulWidget {
  const SkeletalTeamScreen({super.key});

  @override
  State<SkeletalTeamScreen> createState() => _SkeletalTeamScreenState();
}

class _SkeletalTeamScreenState extends State<SkeletalTeamScreen> {
  Tk get _tk => context.tk;

  List<Map<String, dynamic>> _jobs         = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  List<Map<String, dynamic>> _personnel    = [];
  Map<int, Map<String, String>> _usersMap  = {};
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  // ── Dynamic lists ─────────────────────────────────────────────────────────
  List<Map<String, String>> get workTypes => workTypesNotifier.items
      .map((e) => {'code': e.code, 'name': e.name})
      .toList();

  List<Map<String, String>> get damagedOptions => damageSpacesNotifier.items
      .map((e) => {'code': e.code, 'name': e.name})
      .toList();

  String _workTypeName(String? code) {
    if (code == null) return '—';
    return workTypes.firstWhere(
          (e) => e['code'] == code,
      orElse: () => {'code': code, 'name': code},
    )['name']!;
  }

  String _damagedName(String? code) {
    if (code == null) return '—';
    return damagedOptions.firstWhere(
          (e) => e['code'] == code,
      orElse: () => {'code': code, 'name': code},
    )['name']!;
  }

  final List<String> addresses = [
    'Bagong Bayan I-C', 'Bagong Pook VI-C', 'Barangay I-A', 'Barangay I-B',
    'Barangay II-A', 'Barangay II-B', 'Barangay II-C', 'Barangay II-D',
    'Barangay II-E', 'Barangay II-F', 'Barangay III-A', 'Barangay III-B',
    'Barangay III-C', 'Barangay III-D', 'Barangay III-E', 'Barangay III-F',
    'Barangay IV-A', 'Barangay IV-B', 'Barangay IV-C', 'Barangay V-A',
    'Barangay V-B', 'Barangay V-C', 'Barangay V-D', 'Barangay VI-A',
    'Barangay VI-B', 'Barangay VI-D', 'Barangay VI-E', 'Barangay VII-A',
    'Barangay VII-B', 'Barangay VII-C', 'Barangay VII-D', 'Barangay VII-E',
    'Bautista', 'Concepcion', 'Del Remedio', 'Dolores',
    'San Antonio I', 'San Antonio II', 'San Bartolome', 'San Buenaventura',
    'San Crispin', 'San Cristobal', 'San Diego', 'San Francisco',
    'San Gabriel', 'San Gregorio', 'San Ignacio', 'San Isidro',
    'San Joaquin', 'San Jose', 'San Juan', 'San Lorenzo',
    'San Lucas I', 'San Lucas II', 'San Marcos', 'San Mateo',
    'San Miguel', 'San Nicolas', 'San Pedro', 'San Rafael',
    'San Roque', 'San Vicente', 'Sta Ana', 'Sta Catalina',
    'Sta Cruz', 'Sta Felomina', 'Sta Isabel', 'Sta Ma. Magdalena',
    'Sta Veronica', 'Santiago I', 'Santiago II', 'Stmo. Rosario',
    'Sto Angel', 'Sto Cristo', 'Sto Nino', 'Soledad',
    'Sta Monica', 'Sta Maria', 'Sta Elena', 'Others / No Address Listed',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadPersonnel();
    _loadUsers();
    _fetchSkeletalJobs();
    _searchController.addListener(_filterJobs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loaders ──────────────────────────────────────────────────────────
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

  Future<void> _loadPersonnel() async {
    try {
      final res = await Supabase.instance.client
          .from('personnel')
          .select('id, name, position, profile_pic_url')
          .order('name');
      if (mounted) {
        setState(() => _personnel = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      _snack('Failed to load personnel: $e', error: true);
    }
  }

  Future<void> _fetchSkeletalJobs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final jobsRes = await Supabase.instance.client
          .from('skeletal_job')
          .select('''
            id, name, leader_id, member_ids, driver_id, created_at, updated_at,
            status, completed_at,
            work_type_code, work_type_name, difficulty_level,
            damaged_space_code, damaged_space_name, address, remarks, zone,
            created_by_user_id, edited_by_user_id, edited_at,
            accomplished_by_user_id,
            leader:leader_id (name, profile_pic_url)
          ''')
          .neq('status', 'completed')
          .neq('status', 'deleted')
          .order('created_at', ascending: false);

      final jobsWithData = <Map<String, dynamic>>[];
      for (final job in jobsRes) {
        final membersRes = await Supabase.instance.client
            .from('personnel')
            .select('id, name, profile_pic_url')
            .inFilter('id', job['member_ids'] ?? []);
        jobsWithData.add({...job, 'members': membersRes});
      }

      if (mounted) {
        setState(() {
          _jobs         = jobsWithData;
          _filteredJobs = List.from(_jobs);
          _isLoading    = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Failed to load skeletal jobs: $e', error: true);
      }
    }
  }

  void _filterJobs() {
    if (!mounted) return;
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredJobs = q.isEmpty
          ? List.from(_jobs)
          : _jobs.where((job) {
        final name   = (job['name']            ?? '').toString().toLowerCase();
        final leader = (job['leader']?['name'] ?? '').toString().toLowerCase();
        final addr   = (job['address']         ?? '').toString().toLowerCase();
        return name.contains(q) || leader.contains(q) || addr.contains(q);
      }).toList();
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _tk.red : _tk.green,
    ));
  }

  // ── Resolve user display name ─────────────────────────────────────────────
  String _resolveUser(dynamic userId) {
    if (userId == null) return '—';
    final id = userId is int ? userId : int.tryParse(userId.toString());
    if (id == null) return '—';
    final u = _usersMap[id];
    if (u == null) return '—';
    final name  = u['full_name']!.isNotEmpty ? u['full_name']! : u['username']!;
    final uname = u['username']!.isNotEmpty  ? ' (@${u['username']})' : '';
    return '$name$uname';
  }

  String _formatDate(dynamic ts, {bool showTime = true}) {
    if (ts == null) return '—';
    final date = DateTime.parse(ts.toString()).toLocal();
    return DateFormat(showTime ? 'MMM d, yyyy • h:mm a' : 'MMM d, yyyy').format(date);
  }

  // ── Create / Edit Dialog ──────────────────────────────────────────────────
  void _showSkeletalJobDialog({Map<String, dynamic>? existingJob}) {
    final isEdit = existingJob != null;
    final accent = Colors.orange.shade700;

    final jobNameCtrl    = TextEditingController(text: existingJob?['name'] ?? 'Skeletal Job ${DateFormat('MM-dd').format(DateTime.now())}');
    final remarksCtrl    = TextEditingController(text: existingJob?['remarks'] ?? '');
    final zoneCtrl       = TextEditingController(text: existingJob?['zone']?.toString() ?? '');
    final addrSearchCtrl = TextEditingController();

    String? leaderId         = existingJob?['leader_id']         as String?;
    String? driverId         = existingJob?['driver_id']         as String?;
    String? workTypeCode     = existingJob?['work_type_code']     as String?;
    String? damagedSpaceCode = existingJob?['damaged_space_code'] as String?;
    int     difficultyLevel  = (existingJob?['difficulty_level'] as int?) ?? 2;
    String? selectedAddress  = existingJob?['address']            as String?;

    final List<String?> memberIds = [];
    if (isEdit && existingJob!['member_ids'] != null) {
      for (final id in existingJob['member_ids'] as List) {
        memberIds.add(id as String?);
      }
    }

    List<String> filteredAddresses = List.from(addresses);

    // ── hover states for barangay list ──
    String? hoverAddr;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void filterAddr(String q) {
            final lq = q.toLowerCase();
            setS(() {
              filteredAddresses = q.isEmpty
                  ? List.from(addresses)
                  : addresses.where((a) => a.toLowerCase().contains(lq)).toList();
            });
          }

          Set<String> usedIds = {
            if (leaderId != null) leaderId!,
            if (driverId != null) driverId!,
            ...memberIds.whereType<String>(),
          };

          List<DropdownMenuItem<String?>> _personnelItems({String? currentId}) {
            return [
              const DropdownMenuItem(value: null, child: Text('— None —')),
              ..._personnel.where((p) {
                final pid = p['id'] as String;
                return pid == currentId || !usedIds.contains(pid);
              }).map((p) => DropdownMenuItem(
                value: p['id'] as String,
                child: Text(p['name'] as String),
              )),
            ];
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 900),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Scaffold(
                  backgroundColor: _tk.bg,
                  body: Column(children: [

                    // ── Hero header ──────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withOpacity(0.78)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
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
                                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 12),
                                  const SizedBox(width: 5),
                                  Text(isEdit ? 'EDIT SKELETAL JOB' : 'NEW SKELETAL JOB',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10.5,
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
                            const SizedBox(height: 18),
                            Row(children: [
                              Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.20),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                                ),
                                child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 25),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(isEdit ? 'Edit Skeletal Job' : 'Create Skeletal Job',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 20,
                                        fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                                const SizedBox(height: 2),
                                const Text('Assign personnel for this skeletal assignment',
                                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ])),
                            ]),
                          ]),
                        ),
                      ]),
                    ),

                    // ── Form body ────────────────────────────────────────
                    Expanded(child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(22),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        _fieldLabel('Job / Assignment Name'),
                        TextField(
                          controller: jobNameCtrl,
                          style: TextStyle(color: _tk.txtHead, fontSize: 14),
                          decoration: dsInputOf(context, '',
                              hint: 'e.g. Skeletal Job 05-20',
                              icon: Icons.assignment_rounded),
                        ),

                        const SizedBox(height: 20),

                        // ── Team Leader ──────────────────────────────────
                        _sectionHeader(Icons.star_rounded, 'Team Leader', accent),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: _tk.surf,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _tk.bd),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: leaderId,
                              isExpanded: true,
                              dropdownColor: _tk.surf,
                              style: TextStyle(color: _tk.txtHead, fontSize: 14),
                              hint: Text('Select Leader *', style: TextStyle(color: _tk.txtMuted)),
                              items: _personnelItems(currentId: leaderId),
                              onChanged: (v) => setS(() => leaderId = v),
                            ),
                          ),
                        ),
                        if (leaderId != null) ...[
                          const SizedBox(height: 8),
                          _personnelPreviewTile(leaderId!, accent),
                        ],

                        const SizedBox(height: 20),

                        // ── Driver ──────────────────────────────────────
                        _sectionHeader(Icons.local_shipping_rounded, 'Driver (optional)', _tk.blue),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: _tk.surf,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _tk.bd),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: driverId,
                              isExpanded: true,
                              dropdownColor: _tk.surf,
                              style: TextStyle(color: _tk.txtHead, fontSize: 14),
                              hint: Text('Select Driver', style: TextStyle(color: _tk.txtMuted)),
                              items: _personnelItems(currentId: driverId),
                              onChanged: (v) => setS(() => driverId = v),
                            ),
                          ),
                        ),
                        if (driverId != null) ...[
                          const SizedBox(height: 8),
                          _personnelPreviewTile(driverId!, _tk.blue),
                        ],

                        const SizedBox(height: 20),

                        // ── Members ──────────────────────────────────────
                        Row(children: [
                          _sectionHeader(Icons.groups_rounded, 'Members', _tk.green),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setS(() => memberIds.add(null)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _tk.greenBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _tk.green.withOpacity(0.3)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.add_rounded, color: _tk.green, size: 14),
                                const SizedBox(width: 4),
                                Text('Add Member', style: TextStyle(
                                    color: _tk.green, fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        if (memberIds.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _tk.surf2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _tk.bd),
                            ),
                            child: Center(child: Text(
                                'No members added yet. Tap "Add Member" above.',
                                style: TextStyle(color: _tk.txtMuted, fontSize: 12.5))),
                          )
                        else
                          ...List.generate(memberIds.length, (i) {
                            final mid = memberIds[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _tk.surf,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _tk.bd),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String?>(
                                          value: mid,
                                          isExpanded: true,
                                          dropdownColor: _tk.surf,
                                          style: TextStyle(color: _tk.txtHead, fontSize: 14),
                                          hint: Text('Member ${i + 1}',
                                              style: TextStyle(color: _tk.txtMuted)),
                                          items: _personnelItems(currentId: mid),
                                          onChanged: (v) => setS(() => memberIds[i] = v),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setS(() => memberIds.removeAt(i)),
                                    child: Container(
                                      width: 36, height: 44,
                                      decoration: BoxDecoration(
                                        color: _tk.surf2,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _tk.bd),
                                      ),
                                      child: Icon(Icons.remove_circle_outline_rounded,
                                          color: _tk.red, size: 18),
                                    ),
                                  ),
                                ]),
                                if (mid != null) ...[
                                  const SizedBox(height: 6),
                                  _personnelPreviewTile(mid, _tk.green),
                                ],
                              ]),
                            );
                          }),

                        const SizedBox(height: 20),
                        Divider(color: _tk.bd),
                        const SizedBox(height: 16),

                        // ── Job Details ──────────────────────────────────
                        _sectionHeader(Icons.assignment_turned_in_rounded, 'Job Details', accent),
                        const SizedBox(height: 14),

                        _fieldLabel('Type of Work *'),
                        _dropdownTile(
                          icon: Icons.build_rounded,
                          label: workTypeCode == null
                              ? 'Select type of work…'
                              : _workTypeName(workTypeCode),
                          isSelected: workTypeCode != null,
                          accent: _tk.blue,
                          onTap: () => _showWorkTypeSheet(ctx, workTypeCode, (code) {
                            setS(() => workTypeCode = code);
                          }),
                        ),

                        const SizedBox(height: 18),

                        _fieldLabel('Difficulty Level *'),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          for (final entry in [
                            [1, 'Minor',    _tk.cyan],
                            [2, 'Moderate', _tk.amber],
                            [3, 'Major',    _tk.red],
                          ] as List<List<Object>>)
                            Builder(builder: (_) {
                              final level     = entry[0] as int;
                              final lbl       = entry[1] as String;
                              final chipColor = entry[2] as Color;
                              final isSel     = difficultyLevel == level;
                              return GestureDetector(
                                onTap: () => setS(() => difficultyLevel = level),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? chipColor.withOpacity(0.10)
                                        : _tk.surf2,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: isSel
                                            ? chipColor.withOpacity(0.50)
                                            : _tk.bd,
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
                                        color: isSel ? chipColor : _tk.txt,
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

                        _fieldLabel('Damaged Working Space *'),
                        _dropdownTile(
                          icon: Icons.foundation_rounded,
                          label: damagedSpaceCode == null
                              ? 'Select damaged space…'
                              : _damagedName(damagedSpaceCode),
                          isSelected: damagedSpaceCode != null,
                          accent: _tk.amber,
                          onTap: () => _showDamagedSpaceSheet(ctx, damagedSpaceCode, (code) {
                            setS(() => damagedSpaceCode = code);
                          }),
                        ),

                        const SizedBox(height: 18),

                        _fieldLabel('Address / Barangay *'),
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: _tk.surf,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _tk.bd),
                          ),
                          child: TextField(
                            controller: addrSearchCtrl,
                            style: TextStyle(color: _tk.txtHead, fontSize: 13.5),
                            onChanged: filterAddr,
                            decoration: InputDecoration(
                              hintText: 'Search barangay…',
                              hintStyle: TextStyle(color: _tk.txtMuted, fontSize: 13.5),
                              prefixIcon: Icon(Icons.search_rounded,
                                  color: _tk.txtMuted, size: 18),
                              border: InputBorder.none,
                              contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (selectedAddress != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _tk.blueBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _tk.blueBd),
                            ),
                            child: Row(children: [
                              Icon(Icons.location_on_rounded,
                                  color: _tk.blue, size: 15),
                              const SizedBox(width: 8),
                              Expanded(child: Text(selectedAddress!,
                                  style: TextStyle(color: _tk.txtHead,
                                      fontSize: 13, fontWeight: FontWeight.w600))),
                              GestureDetector(
                                onTap: () => setS(() => selectedAddress = null),
                                child: Icon(Icons.close_rounded,
                                    color: _tk.txtMuted, size: 15),
                              ),
                            ]),
                          ),

                        // ── Barangay list with hover ──────────────────────
                        Container(
                          height: 190,
                          decoration: BoxDecoration(
                            color: _tk.surf,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _tk.bd),
                          ),
                          child: filteredAddresses.isEmpty
                              ? Center(child: Text('No results',
                              style: TextStyle(color: _tk.txtMuted, fontSize: 13)))
                              : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: filteredAddresses.length,
                            itemBuilder: (_, i) {
                              final addr         = filteredAddresses[i];
                              final isSel        = selectedAddress == addr;
                              final isAddrHovered = hoverAddr == addr;

                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) =>
                                    setS(() => hoverAddr = addr),
                                onExit: (_) =>
                                    setS(() => hoverAddr = null),
                                child: GestureDetector(
                                  onTap: () =>
                                      setS(() => selectedAddress = addr),
                                  child: AnimatedContainer(
                                    duration:
                                    const Duration(milliseconds: 130),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? _tk.blueBg
                                          : isAddrHovered
                                          ? _tk.blue.withOpacity(0.05)
                                          : Colors.transparent,
                                      borderRadius:
                                      BorderRadius.circular(9),
                                      border: Border.all(
                                        color: isSel
                                            ? _tk.blueBd
                                            : isAddrHovered
                                            ? _tk.blue.withOpacity(0.28)
                                            : Colors.transparent,
                                        width: (isSel || isAddrHovered)
                                            ? 1.5
                                            : 1,
                                      ),
                                      boxShadow:
                                      isAddrHovered && !isSel
                                          ? [
                                        BoxShadow(
                                            color: _tk.blue
                                                .withOpacity(0.12),
                                            blurRadius: 8,
                                            spreadRadius: 1)
                                      ]
                                          : [],
                                    ),
                                    child: Row(children: [
                                      Icon(
                                        isSel
                                            ? Icons.check_circle_rounded
                                            : isAddrHovered
                                            ? Icons.location_on_rounded
                                            : Icons.location_on_outlined,
                                        color: isSel
                                            ? _tk.blue
                                            : isAddrHovered
                                            ? _tk.blue.withOpacity(0.7)
                                            : _tk.txtMuted,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                          child: Text(addr,
                                              style: TextStyle(
                                                  color: isSel
                                                      ? _tk.txtHead
                                                      : isAddrHovered
                                                      ? _tk.txtHead
                                                      : _tk.txt,
                                                  fontSize: 13,
                                                  fontWeight: isSel ||
                                                      isAddrHovered
                                                      ? FontWeight.w600
                                                      : FontWeight.w400))),
                                      if (isAddrHovered && !isSel)
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color:
                                          _tk.blue.withOpacity(0.5),
                                          size: 11,
                                        ),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 18),

                        _fieldLabel('Zone (optional)'),
                        TextField(
                          controller: zoneCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: _tk.txtHead, fontSize: 13.5),
                          decoration: dsInputOf(context, '',
                              hint: 'Enter zone number',
                              icon: Icons.pin_drop_outlined),
                        ),

                        const SizedBox(height: 18),

                        _fieldLabel('Remarks / Specific Location (optional)'),
                        TextField(
                          controller: remarksCtrl,
                          maxLines: 3,
                          style: TextStyle(color: _tk.txtHead, fontSize: 13.5),
                          decoration: dsInputOf(context, '',
                              hint: 'e.g. near the old market, beside the church',
                              icon: Icons.notes_rounded),
                        ),

                        const SizedBox(height: 8),
                      ]),
                    )),

                    // ── Footer ───────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                      decoration: BoxDecoration(
                        color: _tk.surf,
                        border: Border(top: BorderSide(color: _tk.bd)),
                      ),
                      child: Column(children: [

                        if (isEdit) ...[
                          GestureDetector(
                            onTap: () {
                              final zoneNum = int.tryParse(zoneCtrl.text.trim());
                              showDialog(
                                context: ctx,
                                builder: (_) => Dialog(
                                  backgroundColor: _tk.surf,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(color: _tk.bd)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      Container(
                                        width: 52, height: 52,
                                        decoration: BoxDecoration(
                                          color: _tk.greenBg,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: _tk.green.withOpacity(0.3)),
                                        ),
                                        child: Icon(Icons.check_circle_rounded,
                                            color: _tk.green, size: 26),
                                      ),
                                      const SizedBox(height: 16),
                                      Text('Mark as Accomplished?',
                                          style: TextStyle(color: _tk.txtHead,
                                              fontSize: 16, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 8),
                                      Text(zoneNum != null
                                          ? 'Zone: $zoneNum'
                                          : 'No zone specified',
                                          style: TextStyle(
                                              color: _tk.txtMuted, fontSize: 13)),
                                      const SizedBox(height: 24),
                                      Row(children: [
                                        Expanded(child: GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            height: 44,
                                            decoration: BoxDecoration(
                                                color: _tk.surf2,
                                                borderRadius:
                                                BorderRadius.circular(10),
                                                border: Border.all(color: _tk.bd)),
                                            child: Center(child: Text('Cancel',
                                                style: TextStyle(color: _tk.txt,
                                                    fontWeight: FontWeight.w600))),
                                          ),
                                        )),
                                        const SizedBox(width: 10),
                                        Expanded(child: GestureDetector(
                                          onTap: () async {
                                            Navigator.pop(context);
                                            Navigator.pop(ctx);
                                            await _markAccomplished(
                                              existingJob!['id'] as String,
                                              zone: zoneNum,
                                            );
                                          },
                                          child: Container(
                                            height: 44,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                  colors: [
                                                    _tk.green,
                                                    _tk.green.withOpacity(0.82)
                                                  ]),
                                              borderRadius:
                                              BorderRadius.circular(10),
                                              boxShadow: [BoxShadow(
                                                  color: _tk.green.withOpacity(0.3),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3))],
                                            ),
                                            child: const Center(
                                                child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.check_rounded,
                                                          color: Colors.white,
                                                          size: 16),
                                                      SizedBox(width: 6),
                                                      Text('Confirm',
                                                          style: TextStyle(
                                                              color: Colors.white,
                                                              fontWeight:
                                                              FontWeight.w700)),
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
                                color: _tk.greenBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _tk.green.withOpacity(0.3)),
                              ),
                              child: Center(child: Row(
                                  mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.task_alt_rounded,
                                    color: _tk.green, size: 17),
                                const SizedBox(width: 7),
                                Text('Mark as Accomplished',
                                    style: TextStyle(color: _tk.green,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                              ])),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        Row(children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: _tk.surf2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _tk.bd),
                              ),
                              child: Center(child: Text('Cancel',
                                  style: TextStyle(color: _tk.txt,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: GestureDetector(
                            onTap: () async {
                              if (leaderId == null ||
                                  workTypeCode == null ||
                                  damagedSpaceCode == null ||
                                  selectedAddress == null) {
                                _snack('Please complete all required fields',
                                    error: true);
                                return;
                              }

                              final workName   = _workTypeName(workTypeCode);
                              final damageName = _damagedName(damagedSpaceCode);
                              final zoneNum    = int.tryParse(zoneCtrl.text.trim());

                              final data = <String, dynamic>{
                                'name': jobNameCtrl.text.trim().isEmpty
                                    ? 'Custom Skeletal Job'
                                    : jobNameCtrl.text.trim(),
                                'leader_id':          leaderId,
                                'driver_id':          driverId,
                                'member_ids':
                                memberIds.whereType<String>().toList(),
                                'work_type_code':     workTypeCode,
                                'work_type_name':     workName,
                                'difficulty_level':   difficultyLevel,
                                'damaged_space_code': damagedSpaceCode,
                                'damaged_space_name': damageName,
                                'address':            selectedAddress,
                                'remarks': remarksCtrl.text.trim().isNotEmpty
                                    ? remarksCtrl.text.trim()
                                    : null,
                                'zone':       zoneNum,
                                'updated_at': DateTime.now()
                                    .toUtc()
                                    .toIso8601String(),
                              };

                              if (isEdit) {
                                data['edited_by_user_id'] =
                                    AppSession.instance.userId;
                                data['edited_at'] =
                                    DateTime.now().toUtc().toIso8601String();
                              } else {
                                data['created_at'] =
                                    DateTime.now().toUtc().toIso8601String();
                                data['status']             = 'pending';
                                data['created_by_user_id'] =
                                    AppSession.instance.userId;
                              }

                              try {
                                if (isEdit) {
                                  await Supabase.instance.client
                                      .from('skeletal_job')
                                      .update(data)
                                      .eq('id', existingJob!['id']);
                                } else {
                                  await Supabase.instance.client
                                      .from('skeletal_job')
                                      .insert(data);
                                }
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  await _fetchSkeletalJobs();
                                  _snack(isEdit
                                      ? 'Job updated successfully'
                                      : 'Job created successfully');
                                }
                              } catch (e) {
                                if (mounted) _snack('Error: $e', error: true);
                              }
                            },
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                      accent,
                                      accent.withOpacity(0.82)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(
                                    color: accent.withOpacity(0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4))],
                              ),
                              child: Center(child: Row(
                                  mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.save_rounded,
                                    color: Colors.white, size: 17),
                                const SizedBox(width: 7),
                                Text(isEdit ? 'Save Changes' : 'Create Job',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
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

  // ── Mark as accomplished ──────────────────────────────────────────────────
  Future<void> _markAccomplished(String jobId, {int? zone}) async {
    try {
      await Supabase.instance.client.from('skeletal_job').update({
        'status':       'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at':   DateTime.now().toUtc().toIso8601String(),
        'zone':         zone,
        'accomplished_by_user_id': AppSession.instance.userId,
      }).eq('id', jobId);

      if (mounted) {
        await _fetchSkeletalJobs();
        _snack('Job marked as completed and moved to Accomplished');
      }
    } catch (e) {
      if (mounted) _snack('Error completing job: $e', error: true);
    }
  }

  // ── Personnel preview tile ────────────────────────────────────────────────
  Widget _personnelPreviewTile(String id, Color accent) {
    final p = _personnel.firstWhere(
            (p) => p['id'] == id,
        orElse: () => <String, dynamic>{});
    if (p.isEmpty) return const SizedBox.shrink();
    final picUrl = p['profile_pic_url'] as String?;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: accent.withOpacity(0.15),
          backgroundImage: picUrl != null ? NetworkImage(picUrl) : null,
          child: picUrl == null
              ? Icon(Icons.person_rounded, color: accent, size: 16)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(p['name'] as String? ?? '—',
            style: TextStyle(color: _tk.txtHead,
                fontSize: 13, fontWeight: FontWeight.w600))),
        if ((p['position'] as String? ?? '').isNotEmpty)
          Text(p['position'] as String,
              style: TextStyle(color: _tk.txtMuted, fontSize: 11.5)),
      ]),
    );
  }

  // ── Detail dialog ─────────────────────────────────────────────────────────
  void _showDetailDialog(Map<String, dynamic> job) {
    final accentA = Colors.orange.shade700;
    final accentB = Colors.orange.shade900;

    final leader     = job['leader'] as Map<String, dynamic>? ?? {};
    final members    = job['members'] as List? ?? [];
    final leaderName = leader['name'] as String? ?? '—';
    final leaderPic  = leader['profile_pic_url'] as String?;

    final driverId   = job['driver_id'] as String?;
    final driverData = driverId != null
        ? _personnel.firstWhere((p) => p['id'] == driverId,
        orElse: () => <String, dynamic>{})
        : null;

    final diffMap      = {1: 'Minor', 2: 'Moderate', 3: 'Major'};
    final diffColorMap = {1: _tk.cyan, 2: _tk.amber, 3: _tk.red};
    final diffLevel    = job['difficulty_level'] as int? ?? 2;
    final diffLabel    = diffMap[diffLevel] ?? 'Level $diffLevel';
    final diffColor    = diffColorMap[diffLevel] ?? _tk.amber;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 820),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: Column(children: [
                // Hero
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [accentA, accentB],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                  child: Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: _DotPainter())),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.25)),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded,
                                      color: Colors.white, size: 13),
                                  SizedBox(width: 5),
                                  Text('SKELETAL', style: TextStyle(
                                      color: Colors.white, fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2)),
                                ]),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showSkeletalJobDialog(existingJob: job);
                            },
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.25)),
                              ),
                              child: const Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 17),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.25)),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.assignment_rounded,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(job['name'] ?? 'Unnamed Job',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.schedule_rounded,
                                      color: Colors.white, size: 13),
                                  const SizedBox(width: 5),
                                  Text('Created ${_formatDate(job['created_at'])}',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.88),
                                          fontSize: 11.5)),
                                ]),
                              ])),
                        ]),
                        const SizedBox(height: 16),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _heroChip(Icons.location_on_rounded,
                              job['address'] ?? '—'),
                          if ((job['zone']?.toString() ?? '').isNotEmpty)
                            _heroChip(Icons.pin_drop_rounded,
                                'Zone ${job['zone']}'),
                          _heroChip(Icons.build_rounded,
                              job['work_type_name'] ?? '—'),
                        ]),
                      ]),
                    ),
                  ]),
                ),

                // Body
                Expanded(child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoCard(
                          icon: Icons.assignment_rounded,
                          title: 'Job Details',
                          accent: accentA,
                          children: [
                            _infoRow('Work Type',
                                job['work_type_name'] ?? '—',
                                Icons.build_rounded),
                            _infoRow('Address',
                                job['address'] ?? '—',
                                Icons.location_on_rounded),
                            _infoRow('Damaged Space',
                                job['damaged_space_name'] ?? '—',
                                Icons.foundation_rounded),
                            if (job['zone'] != null)
                              _infoRow('Zone',
                                  job['zone'].toString(),
                                  Icons.pin_drop_rounded),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(children: [
                                const Icon(Icons.speed_rounded,
                                    size: 15, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 10),
                                const SizedBox(width: 110,
                                    child: Text('Difficulty',
                                        style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13))),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: diffColor.withOpacity(0.10),
                                    borderRadius:
                                    BorderRadius.circular(20),
                                    border: Border.all(
                                        color: diffColor.withOpacity(0.30)),
                                  ),
                                  child: Text(diffLabel, style: TextStyle(
                                      color: diffColor, fontSize: 12.5,
                                      fontWeight: FontWeight.w700)),
                                ),
                              ]),
                            ),
                            if ((job['remarks'] ?? '').toString().trim()
                                .isNotEmpty)
                              _infoRow('Remarks',
                                  job['remarks'].toString(),
                                  Icons.notes_rounded),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _infoCard(
                          icon: Icons.groups_rounded,
                          title: 'Skeletal Team',
                          accent: accentA,
                          children: [
                            _memberRow(
                              label: 'Leader',
                              name: leaderName,
                              picUrl: leaderPic,
                              isLeader: true,
                              accent: accentA,
                            ),
                            if (driverData != null &&
                                (driverData as Map).isNotEmpty) ...[
                              const Padding(
                                padding:
                                EdgeInsets.only(top: 4, bottom: 12),
                                child: Divider(
                                    height: 1,
                                    color: Color(0xFFE2E8F0)),
                              ),
                              _memberRow(
                                label: 'Driver',
                                name: driverData['name'] as String? ?? '—',
                                picUrl: driverData['profile_pic_url']
                                as String?,
                                isLeader: false,
                                accent: _tk.blue,
                                roleIcon: Icons.local_shipping_rounded,
                                roleLabel: 'Driver',
                              ),
                            ],
                            if (members.isNotEmpty) ...[
                              const Padding(
                                padding:
                                EdgeInsets.only(top: 4, bottom: 12),
                                child: Divider(
                                    height: 1,
                                    color: Color(0xFFE2E8F0)),
                              ),
                              Text(
                                  'Members (${members.length})',
                                  style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                              const SizedBox(height: 12),
                              Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: (members as List).map((m) {
                                    final mp = m as Map<String, dynamic>;
                                    return _avatarChip(
                                        name: mp['name'] as String? ?? '—',
                                        picUrl: mp['profile_pic_url']
                                        as String?);
                                  }).toList()),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),

                        _infoCard(
                          icon: Icons.timeline_rounded,
                          title: 'Timeline',
                          accent: accentA,
                          children: [
                            _timelineRow('Created',
                                _formatDate(job['created_at']),
                                isFirst: true),
                            if (job['edited_at'] != null)
                              _timelineRow('Last Edited',
                                  _formatDate(job['edited_at'])),
                            _timelineRow(
                                'Status',
                                (job['status'] as String? ?? 'pending')
                                    .toUpperCase(),
                                isLast: true,
                                color: accentA),
                          ],
                        ),

                        const SizedBox(height: 16),

                        _infoCard(
                          icon: Icons.manage_accounts_rounded,
                          title: 'Activity',
                          accent: const Color(0xFF6366F1),
                          children: [
                            _infoRow('Created by',
                                _resolveUser(job['created_by_user_id']),
                                Icons.person_add_rounded),
                            if (job['edited_by_user_id'] != null)
                              _infoRow('Edited by',
                                  _resolveUser(job['edited_by_user_id']),
                                  Icons.edit_rounded),
                            if (job['accomplished_by_user_id'] != null)
                              _infoRow(
                                  'Accomplished by',
                                  _resolveUser(
                                      job['accomplished_by_user_id']),
                                  Icons.how_to_reg_rounded),
                          ],
                        ),

                        const SizedBox(height: 8),
                      ]),
                )),

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                        top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showSkeletalJobDialog(existingJob: job);
                      },
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2))],
                        ),
                        child: Center(child: Row(
                            mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_rounded, color: accentA, size: 15),
                          const SizedBox(width: 6),
                          Text('Edit', style: TextStyle(
                              color: accentA, fontSize: 13.5,
                              fontWeight: FontWeight.w600)),
                        ])),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: ctx,
                          builder: (_) => Dialog(
                            backgroundColor: const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(
                                    color: Color(0xFFE2E8F0))),
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56, height: 56,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD1FAE5),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF059669)
                                                .withOpacity(0.3)),
                                      ),
                                      child: const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF059669),
                                          size: 28),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Mark as Accomplished?',
                                        style: TextStyle(
                                            color: Color(0xFF1E293B),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    Text(job['name'] ?? 'This skeletal job',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13)),
                                    const SizedBox(height: 24),
                                    Row(children: [
                                      Expanded(child: GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                              BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: const Color(
                                                      0xFFE2E8F0))),
                                          child: const Center(
                                              child: Text('Cancel',
                                                  style: TextStyle(
                                                      color: Color(0xFF475569),
                                                      fontWeight:
                                                      FontWeight.w600))),
                                        ),
                                      )),
                                      const SizedBox(width: 10),
                                      Expanded(child: GestureDetector(
                                        onTap: () async {
                                          Navigator.pop(context);
                                          Navigator.pop(ctx);
                                          await _markAccomplished(
                                              job['id'] as String);
                                        },
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF059669),
                                                  Color(0xFF047857)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight),
                                            borderRadius:
                                            BorderRadius.circular(10),
                                            boxShadow: [BoxShadow(
                                                color: const Color(0xFF059669)
                                                    .withOpacity(0.35),
                                                blurRadius: 10,
                                                offset:
                                                const Offset(0, 3))],
                                          ),
                                          child: const Center(
                                              child: Row(
                                                  mainAxisSize:
                                                  MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.check_rounded,
                                                        color: Colors.white,
                                                        size: 16),
                                                    SizedBox(width: 6),
                                                    Text('Confirm',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                            FontWeight.w700)),
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
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF047857)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                              color: const Color(0xFF059669).withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4))],
                        ),
                        child: const Center(child: Row(
                            mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.task_alt_rounded,
                              color: Colors.white, size: 17),
                          SizedBox(width: 7),
                          Text('Mark as Accomplished',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ])),
                      ),
                    )),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared detail widgets ─────────────────────────────────────────────────
  Widget _heroChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.22)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 12),
      const SizedBox(width: 5),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11.5,
                fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  Widget _infoCard({
    required IconData icon,
    required String title,
    required Color accent,
    required List<Widget> children,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8EFF6)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 12, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: accent, size: 15),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: Color(0xFF1E293B),
            fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 16),
      const Divider(height: 1, color: Color(0xFFF1F5F9)),
      const SizedBox(height: 14),
      ...children,
    ]),
  );

  Widget _infoRow(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 10),
      SizedBox(width: 110, child: Text(label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))),
      Expanded(child: Text(value,
          style: const TextStyle(color: Color(0xFF1E293B),
              fontSize: 13.5, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _memberRow({
    required String label,
    required String name,
    required String? picUrl,
    bool isLeader = false,
    required Color accent,
    IconData? roleIcon,
    String? roleLabel,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Stack(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFE2E8F0),
          backgroundImage: picUrl != null ? NetworkImage(picUrl) : null,
          child: picUrl == null
              ? const Icon(Icons.person_rounded,
              color: Color(0xFF94A3B8), size: 22)
              : null,
        ),
        if (isLeader || roleIcon != null)
          Positioned(bottom: 0, right: 0, child: Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5)),
            child: Icon(roleIcon ?? Icons.star_rounded,
                color: Colors.white, size: 9),
          )),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
            color: Color(0xFF94A3B8), fontSize: 11.5)),
        Text(name, style: const TextStyle(color: Color(0xFF1E293B),
            fontSize: 14, fontWeight: FontWeight.w700)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Text(roleLabel ?? 'Leader',
            style: TextStyle(color: accent, fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
    ]),
  );

  Widget _avatarChip({required String name, required String? picUrl}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFFE2E8F0),
            backgroundImage: picUrl != null ? NetworkImage(picUrl) : null,
            child: picUrl == null
                ? const Icon(Icons.person_rounded,
                color: Color(0xFF94A3B8), size: 12)
                : null,
          ),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF1E293B),
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _timelineRow(String label, String time,
      {bool isFirst = false, bool isLast = false,
        Color color = const Color(0xFF94A3B8)}) =>
      IntrinsicHeight(
        child: Row(children: [
          SizedBox(width: 24, child: Column(children: [
            if (!isFirst) Expanded(
                child: Container(width: 2, color: const Color(0xFFE2E8F0))),
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: isLast ? color : const Color(0xFFCBD5E1),
                shape: BoxShape.circle,
                boxShadow: isLast
                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)]
                    : null,
              ),
            ),
            if (!isLast) Expanded(
                child: Container(width: 2, color: const Color(0xFFE2E8F0))),
          ])),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 11.5)),
                  Text(time, style: TextStyle(
                      color: isLast ? color : const Color(0xFF1E293B),
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
                ]),
          ),
        ]),
      );

  // ── Compact card ──────────────────────────────────────────────────────────
  Widget _buildJobCard(Map<String, dynamic> job) {
    final accent    = Colors.orange.shade700;
    final leader    = job['leader'] as Map<String, dynamic>? ?? {};
    final members   = job['members'] as List? ?? [];
    final diff      = job['difficulty_level'] as int? ?? 2;
    final diffLabel = {1: 'Minor', 2: 'Moderate', 3: 'Major'}[diff] ?? '?';
    final diffColor = {1: _tk.cyan, 2: _tk.amber, 3: _tk.red}[diff] ?? _tk.amber;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: _tk.dark ? 0 : 2,
      color: _tk.dark ? const Color(0xFF101827) : null,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: _tk.dark
                  ? const Color(0xFF1E2E47)
                  : Colors.transparent)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailDialog(job),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [accent, accent.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(
                  (job['name'] as String? ?? 'S')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(job['name'] ?? 'Unnamed Job',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _tk.txtHead, fontSize: 14.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.person_rounded, size: 12, color: _tk.txtMuted),
                const SizedBox(width: 4),
                Expanded(child: Text('Leader: ${leader['name'] ?? '—'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _tk.txtMuted, fontSize: 12.5))),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.groups_rounded, size: 12, color: _tk.txtMuted),
                const SizedBox(width: 4),
                Text('${members.length} member${members.length == 1 ? '' : 's'}',
                    style: TextStyle(color: _tk.txtMuted, fontSize: 12)),
                if ((job['address'] ?? '').toString().isNotEmpty) ...[
                  Text(' • ', style: TextStyle(color: _tk.bd2)),
                  Icon(Icons.location_on_rounded,
                      size: 12, color: _tk.txtMuted),
                  const SizedBox(width: 2),
                  Expanded(child: Text(job['address']!,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _tk.txtMuted, fontSize: 12))),
                ],
              ]),
            ])),
            const SizedBox(width: 10),
            Column(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: diffColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: diffColor.withOpacity(0.28)),
                    ),
                    child: Text(diffLabel, style: TextStyle(
                        color: diffColor, fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right_rounded, color: accent, size: 26),
                ]),
          ]),
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────
  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: TextStyle(color: _tk.txtHead,
        fontSize: 13, fontWeight: FontWeight.w600)),
  );

  Widget _sectionHeader(IconData icon, String title, Color accent) =>
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withOpacity(0.22))),
          child: Icon(icon, color: accent, size: 14),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: _tk.txtHead,
            fontSize: 13.5, fontWeight: FontWeight.w700)),
      ]);

  Widget _dropdownTile({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color accent,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withOpacity(_tk.dark ? 0.10 : 0.05)
                : _tk.surf,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected ? accent.withOpacity(0.42) : _tk.bd,
                width: isSelected ? 1.5 : 1),
            boxShadow: isSelected
                ? [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 8)]
                : _tk.shadowSm,
          ),
          child: Row(children: [
            Icon(icon, size: 17,
                color: isSelected ? accent : _tk.txtMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(
                color: isSelected ? _tk.txtHead : _tk.txtMuted,
                fontSize: 13.5,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400))),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: isSelected ? accent : _tk.txtMuted, size: 20),
          ]),
        ),
      );

  // ── Bottom sheets with hover ──────────────────────────────────────────────
  void _showWorkTypeSheet(
      BuildContext ctx, String? current, Function(String) onSelect) {
    // hover state lives here, rebuilt via StatefulBuilder
    String? hoverWtCode;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, sc) => Container(
            decoration: BoxDecoration(
              color: _tk.surf,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: _tk.bd)),
            ),
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                      width: 42, height: 5,
                      decoration: BoxDecoration(color: _tk.bd2,
                          borderRadius: BorderRadius.circular(10)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(children: [
                  Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _tk.blueBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _tk.blueBd)),
                      child: Icon(Icons.build_rounded,
                          color: _tk.blue, size: 17)),
                  const SizedBox(width: 12),
                  Text('Type of Work', style: TextStyle(
                      color: _tk.txtHead, fontSize: 16,
                      fontWeight: FontWeight.w800)),
                ]),
              ),
              Divider(height: 1, color: _tk.bd),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: workTypes.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (_, i) {
                    final wt    = workTypes[i];
                    final isSel = current == wt['code'];
                    final isHov = hoverWtCode == wt['code'];
                    final accent = _tk.blue;

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) =>
                          setSheet(() => hoverWtCode = wt['code']),
                      onExit: (_) =>
                          setSheet(() => hoverWtCode = null),
                      child: GestureDetector(
                        onTap: () {
                          onSelect(wt['code']!);
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: isSel
                                ? accent.withOpacity(0.08)
                                : isHov
                                ? accent.withOpacity(0.04)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel
                                  ? accent.withOpacity(0.30)
                                  : isHov
                                  ? accent.withOpacity(0.22)
                                  : Colors.transparent,
                              width: (isSel || isHov) ? 1.5 : 1,
                            ),
                            boxShadow: isHov && !isSel
                                ? [BoxShadow(
                                color: accent.withOpacity(0.14),
                                blurRadius: 10, spreadRadius: 1)]
                                : [],
                          ),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: isSel
                                    ? accent.withOpacity(0.15)
                                    : isHov
                                    ? accent.withOpacity(0.10)
                                    : _tk.surf2,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isSel || isHov
                                      ? accent.withOpacity(0.28)
                                      : _tk.bd,
                                ),
                              ),
                              child: Center(child: Text(wt['code']!,
                                  style: TextStyle(
                                      color: isSel || isHov
                                          ? accent
                                          : _tk.txtMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(wt['name']!,
                                style: TextStyle(
                                    color: isSel || isHov
                                        ? _tk.txtHead
                                        : _tk.txt,
                                    fontSize: 14,
                                    fontWeight: isSel || isHov
                                        ? FontWeight.w700
                                        : FontWeight.w400))),
                            if (isSel)
                              Icon(Icons.check_circle_rounded,
                                  color: accent, size: 20)
                            else if (isHov)
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: accent.withOpacity(0.6), size: 14),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showDamagedSpaceSheet(
      BuildContext ctx, String? current, Function(String) onSelect) {
    // hover state lives here, rebuilt via StatefulBuilder
    String? hoverDmgCode;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.35,
          maxChildSize: 0.70,
          expand: false,
          builder: (_, sc) => Container(
            decoration: BoxDecoration(
              color: _tk.surf,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: _tk.bd)),
            ),
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                      width: 42, height: 5,
                      decoration: BoxDecoration(color: _tk.bd2,
                          borderRadius: BorderRadius.circular(10)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(children: [
                  Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _tk.amberBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _tk.amberBd)),
                      child: Icon(Icons.foundation_rounded,
                          color: _tk.amber, size: 17)),
                  const SizedBox(width: 12),
                  Text('Damaged Working Space', style: TextStyle(
                      color: _tk.txtHead, fontSize: 16,
                      fontWeight: FontWeight.w800)),
                ]),
              ),
              Divider(height: 1, color: _tk.bd),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: damagedOptions.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (_, i) {
                    final opt   = damagedOptions[i];
                    final isSel = current == opt['code'];
                    final isHov = hoverDmgCode == opt['code'];

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) =>
                          setSheet(() => hoverDmgCode = opt['code']),
                      onExit: (_) =>
                          setSheet(() => hoverDmgCode = null),
                      child: GestureDetector(
                        onTap: () {
                          onSelect(opt['code']!);
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: isSel
                                ? _tk.amberBg
                                : isHov
                                ? _tk.amber.withOpacity(0.04)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel
                                  ? _tk.amberBd
                                  : isHov
                                  ? _tk.amber.withOpacity(0.22)
                                  : Colors.transparent,
                              width: (isSel || isHov) ? 1.5 : 1,
                            ),
                            boxShadow: isHov && !isSel
                                ? [BoxShadow(
                                color: _tk.amber.withOpacity(0.14),
                                blurRadius: 10, spreadRadius: 1)]
                                : [],
                          ),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: isSel
                                    ? _tk.amber.withOpacity(0.15)
                                    : isHov
                                    ? _tk.amber.withOpacity(0.10)
                                    : _tk.surf2,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isSel || isHov
                                      ? _tk.amber.withOpacity(0.28)
                                      : _tk.bd,
                                ),
                              ),
                              child: Center(child: Text(opt['code']!,
                                  style: TextStyle(
                                      color: isSel || isHov
                                          ? _tk.amber
                                          : _tk.txtMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(opt['name']!,
                                style: TextStyle(
                                    color: isSel || isHov
                                        ? _tk.txtHead
                                        : _tk.txt,
                                    fontSize: 14,
                                    fontWeight: isSel || isHov
                                        ? FontWeight.w700
                                        : FontWeight.w400))),
                            if (isSel)
                              Icon(Icons.check_circle_rounded,
                                  color: _tk.amber, size: 20)
                            else if (isHov)
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: _tk.amber.withOpacity(0.6),
                                  size: 14),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = Colors.orange.shade700;

    return Scaffold(
      backgroundColor: _tk.bg,
      body: Column(children: [
        DsHeader(
          title: 'Skeletal Jobs',
          subtitle: 'Manage custom skeletal assignments',
          icon: Icons.bolt_rounded,
          accent: _tk.amber,
          actions: [
            GestureDetector(
              onTap: _fetchSkeletalJobs,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _tk.surf2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _tk.bd)),
                child: Icon(Icons.refresh_rounded,
                    color: _tk.txtMuted, size: 18),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
          child: DsSearchBar(
              controller: _searchController,
              hint: 'Search by job name, leader, or address…',
              onClear: () => setState(() {})),
        ),

        Expanded(
          child: _isLoading
              ? const DsLoading()
              : _filteredJobs.isEmpty
              ? Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_outlined, size: 110,
                      color: _tk.amber.withOpacity(0.3)),
                  const SizedBox(height: 24),
                  Text(
                    _searchController.text.isEmpty
                        ? 'No skeletal jobs yet'
                        : 'No matching jobs',
                    style: TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w700, color: _tk.txt),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _searchController.text.isEmpty
                        ? 'Tap the button below to create one'
                        : 'Try different keywords',
                    style: TextStyle(fontSize: 16, color: _tk.txtMuted),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _fetchSkeletalJobs,
                  ),
                ]),
          )
              : RefreshIndicator(
            onRefresh: _fetchSkeletalJobs,
            color: accent,
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: _filteredJobs.length,
              itemBuilder: (_, i) => _buildJobCard(_filteredJobs[i]),
            ),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSkeletalJobDialog(),
        backgroundColor: accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Skeletal Job',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
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
    canvas.drawCircle(
        Offset(size.width * 0.88, size.height * 0.18), 52, ring);
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.88), 72, ring);
  }

  @override
  bool shouldRepaint(_) => false;
}