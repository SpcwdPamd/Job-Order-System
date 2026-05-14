import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/session/session.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/data/admin_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class JobOrderScreen extends StatefulWidget {
  const JobOrderScreen({super.key});

  @override
  State<JobOrderScreen> createState() => _JobOrderScreenState();
}

class _JobOrderScreenState extends State<JobOrderScreen>
    with SingleTickerProviderStateMixin {
  Tk get _tk => context.tk;

  List<Map<String, dynamic>> _unassignedJobs = [];
  List<Map<String, dynamic>> _assignedJobs = [];

  bool _isLoading = true;

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryAnim;

  final TextEditingController _leftSearch = TextEditingController();
  final TextEditingController _rightSearch = TextEditingController();

  bool _hoverRefresh = false;
  bool _hoverNew = false;
  String? _hoveredAssignId;
  String? _hoveredCardId;
  String? _flashJoNumber;

  List<Map<String, dynamic>> get _filteredUnassigned {
    final q = _leftSearch.text.toLowerCase().trim();
    if (q.isEmpty) return _unassignedJobs;
    return _unassignedJobs.where((j) {
      final jo = (j['jo_number'] ?? '').toString().toLowerCase();
      final wt = (j['work_type_name'] ?? '').toString().toLowerCase();
      final addr = (j['address'] ?? '').toString().toLowerCase();
      return jo.contains(q) || wt.contains(q) || addr.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredAssigned {
    final q = _rightSearch.text.toLowerCase().trim();
    if (q.isEmpty) return _assignedJobs;
    return _assignedJobs.where((j) {
      final jo = (j['jo_number'] ?? '').toString().toLowerCase();
      final team = (j['team']?['team_name'] ?? '').toString().toLowerCase();
      final wt = (j['work_type_name'] ?? '').toString().toLowerCase();
      final addr = (j['address'] ?? '').toString().toLowerCase();
      return jo.contains(q) ||
          team.contains(q) ||
          wt.contains(q) ||
          addr.contains(q);
    }).toList();
  }

  final List<String> shiftTimes = [
    '6:00 AM – 2:00 PM',
    '8:00 AM – 5:00 PM',
    '2:00 PM – 10:00 PM',
  ];

  List<Map<String, String>> get workTypes => workTypesNotifier.items
      .map((e) => {'code': e.code, 'name': e.name})
      .toList();

  List<Map<String, String>> get damagedOptions => damageSpacesNotifier.items
      .map((e) => {'code': e.code, 'name': e.name})
      .toList();

  static const List<String> addresses = [
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

  static const _wtColors = <String, Color>{
    '101': Color(0xFF1D6FE8),
    '102': Color(0xFF0891B2),
    '103': Color(0xFF7C3AED),
    '104': Color(0xFFD97706),
    '201': Color(0xFF059669),
    '202': Color(0xFFDC2626),
    '203': Color(0xFF4338CA),
    '301': Color(0xFFDB2777),
  };

  Color _accentForCode(String? code) =>
      _wtColors[code] ?? const Color(0xFF1D6FE8);

  Map<String, int> get _workTypeCounts {
    final counts = <String, int>{};
    for (final j in _unassignedJobs) {
      final name = (j['work_type_name'] as String?)?.trim() ?? 'Other';
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  Map<int, int> get _diffCounts {
    final counts = {1: 0, 2: 0, 3: 0};
    for (final j in _unassignedJobs) {
      final lvl = j['difficulty_level'] as int? ?? 2;
      counts[lvl] = (counts[lvl] ?? 0) + 1;
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entryAnim =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _leftSearch.addListener(() => setState(() {}));
    _rightSearch.addListener(() => setState(() {}));
    _fetchAll();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _leftSearch.dispose();
    _rightSearch.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchUnassigned(), _fetchAssigned()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _entryCtrl.forward(from: 0);
    }
  }

  Future<void> _fetchUnassigned() async {
    try {
      final res = await Supabase.instance.client
          .from('job_orders')
          .select(
          'id, jo_number, work_type_code, work_type_name, difficulty_level, '
              'damaged_space_code, damaged_space_name, address, remarks, zone, '
              'created_at, status, team_id')
          .eq('status', 'pending')
          .filter('team_id', 'is', null)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _unassignedJobs = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      if (mounted) _snack('Error loading complaints: $e', error: true);
    }
  }

  Future<void> _fetchAssigned() async {
    try {
      final res = await Supabase.instance.client
          .from('job_orders')
          .select(
          'id, jo_number, shift_index, shift_time, team_id, '
              'team:team_id (team_name), '
              'work_type_code, work_type_name, difficulty_level, '
              'damaged_space_code, damaged_space_name, address, remarks, zone, '
              'created_at, status, created_by_user_id')
          .eq('status', 'pending')
          .not('team_id', 'is', null)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() => _assignedJobs = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      if (mounted) _snack('Error loading job orders: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _tk.red : _tk.green,
    ));
  }

  Future<String> _generateJoNumber() async {
    final year = DateTime.now().year;
    try {
      final res = await Supabase.instance.client
          .from('job_orders')
          .select('jo_number')
          .like('jo_number', '$year-%');

      int maxSeq = 0;
      for (final row in res as List) {
        final joNum = (row['jo_number'] as String?) ?? '';
        final parts = joNum.split('-');
        if (parts.length == 2) {
          final seq = int.tryParse(parts[1]) ?? 0;
          if (seq > maxSeq) maxSeq = seq;
        }
      }
      final next = maxSeq + 1;
      return '$year-${next.toString().padLeft(5, '0')}';
    } catch (_) {
      return '$year-00001';
    }
  }

  void _flashNewCard(String joNumber) {
    setState(() => _flashJoNumber = joNumber);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _flashJoNumber = null);
    });
  }

  List<BoxShadow> _glowShadow(Color color, {bool active = false}) {
    if (!active) return [];
    return [
      BoxShadow(
          color: color.withOpacity(0.45),
          blurRadius: 18,
          spreadRadius: 1,
          offset: Offset.zero),
      BoxShadow(
          color: color.withOpacity(0.20),
          blurRadius: 6,
          offset: Offset.zero),
    ];
  }

  // ── Create JO Dialog

  void _showCreateDialog() async {
    final generatedJoNum = await _generateJoNumber();
    if (!mounted) return;

    final joCtrl = TextEditingController(text: generatedJoNum);
    final remarksCtrl = TextEditingController();
    String? workTypeCode;
    int? difficultyLevel;
    String? damagedCode;
    String? selectedAddress;
    final addrSearchCtrl = TextEditingController();
    List<String> filteredAddresses = List.from(addresses);

    bool hoverClose = false;
    bool hoverCancel = false;
    bool hoverSave = false;
    int? hoverDiffLevel;

    // Hover states for dropdowns
    bool hoverWorkType = false;
    bool hoverDamagedSpace = false;

    // ── NEW: hover state for barangay list items ──
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
                  : addresses
                  .where((a) => a.toLowerCase().contains(lq))
                  .toList();
            });
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(maxWidth: 620, maxHeight: 880),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Scaffold(
                  backgroundColor: _tk.bg,
                  body: Column(children: [
                    // ── Hero header
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_tk.blue, _tk.blue.withOpacity(0.78)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(children: [
                        Positioned.fill(
                            child: CustomPaint(painter: _DotPainter())),
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(22, 22, 22, 20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color:
                                      Colors.white.withOpacity(0.18),
                                      borderRadius:
                                      BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.white
                                              .withOpacity(0.25)),
                                    ),
                                    child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.receipt_long_rounded,
                                              color: Colors.white,
                                              size: 12),
                                          SizedBox(width: 5),
                                          Text('NEW COMPLAINT',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.5,
                                                  fontWeight:
                                                  FontWeight.w800,
                                                  letterSpacing: 1.2)),
                                        ]),
                                  ),
                                  const Spacer(),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) =>
                                        setS(() => hoverClose = true),
                                    onExit: (_) =>
                                        setS(() => hoverClose = false),
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(ctx),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 150),
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: hoverClose
                                              ? Colors.red
                                              .withOpacity(0.35)
                                              : Colors.white
                                              .withOpacity(0.18),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          border: Border.all(
                                              color: hoverClose
                                                  ? Colors.red
                                                  .withOpacity(0.6)
                                                  : Colors.white
                                                  .withOpacity(0.25)),
                                          boxShadow: hoverClose
                                              ? [
                                            BoxShadow(
                                                color: Colors.red
                                                    .withOpacity(
                                                    0.45),
                                                blurRadius: 12,
                                                spreadRadius: 1)
                                          ]
                                              : [],
                                        ),
                                        child: const Icon(
                                            Icons.close_rounded,
                                            color: Colors.white,
                                            size: 17),
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 18),
                                Row(children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color:
                                      Colors.white.withOpacity(0.20),
                                      borderRadius:
                                      BorderRadius.circular(14),
                                      border: Border.all(
                                          color: Colors.white
                                              .withOpacity(0.28)),
                                    ),
                                    child: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: Colors.white,
                                        size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  const Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text('New Complaint',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 21,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.5)),
                                        SizedBox(height: 2),
                                        Text('Team will be assigned later',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12)),
                                      ]),
                                ]),
                              ]),
                        ),
                      ]),
                    ),

                    // Form body
                    Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(22),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('J.O. Number (Auto-generated)'),
                                TextField(
                                  controller: joCtrl,
                                  style: TextStyle(
                                    color: _tk.blue,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                  textCapitalization:
                                  TextCapitalization.characters,
                                  decoration: dsInputOf(context, '',
                                    hint: 'e.g. 2026-00339',
                                    icon: Icons.tag_rounded,
                                    suffix: Padding(
                                      padding:
                                      const EdgeInsets.only(right: 12),
                                      child: Center(
                                        widthFactor: 1,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _tk.blueBg,
                                            borderRadius:
                                            BorderRadius.circular(6),
                                            border: Border.all(
                                                color: _tk.blueBd),
                                          ),
                                          child: Text('AUTO',
                                              style: TextStyle(
                                                  color: _tk.blue,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _fieldLabel('Type of Work *'),
                                // ── Work Type dropdown with hover ────────────
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) =>
                                      setS(() => hoverWorkType = true),
                                  onExit: (_) =>
                                      setS(() => hoverWorkType = false),
                                  child: _dropdownTile(
                                    icon: Icons.build_rounded,
                                    label: workTypeCode == null
                                        ? 'Select type of work…'
                                        : workTypes
                                        .firstWhere(
                                            (e) => e['code'] == workTypeCode,
                                        orElse: () => {
                                          'name': workTypeCode ?? ''
                                        })['name']!,
                                    isSelected: workTypeCode != null,
                                    isHovered: hoverWorkType,
                                    accent: _tk.blue,
                                    onTap: () => _showWorkTypeSheet(
                                        ctx, workTypeCode, (code, name) {
                                      setS(() => workTypeCode = code);
                                    }),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _fieldLabel('Difficulty Level *'),
                                Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final entry in [
                                        [1, 'Minor'],
                                        [2, 'Moderate'],
                                        [3, 'Major']
                                      ] as List<List<Object>>)
                                        Builder(builder: (_) {
                                          final level = entry[0] as int;
                                          final lbl = entry[1] as String;
                                          final isSel =
                                              difficultyLevel == level;
                                          final isChipHovered =
                                              hoverDiffLevel == level;
                                          final chipColor = level == 1
                                              ? const Color(0xFF0891B2)
                                              : level == 2
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFFDC2626);
                                          return MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            onEnter: (_) => setS(
                                                    () => hoverDiffLevel = level),
                                            onExit: (_) => setS(
                                                    () => hoverDiffLevel = null),
                                            child: GestureDetector(
                                              onTap: () => setS(() =>
                                              difficultyLevel =
                                              isSel ? null : level),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 150),
                                                padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 18,
                                                    vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: isSel
                                                      ? chipColor
                                                      .withOpacity(0.13)
                                                      : isChipHovered
                                                      ? chipColor
                                                      .withOpacity(0.07)
                                                      : _tk.surf2,
                                                  borderRadius:
                                                  BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isSel
                                                        ? chipColor
                                                        .withOpacity(0.55)
                                                        : isChipHovered
                                                        ? chipColor
                                                        .withOpacity(0.40)
                                                        : _tk.bd,
                                                    width: (isSel ||
                                                        isChipHovered)
                                                        ? 1.5
                                                        : 1,
                                                  ),
                                                  boxShadow:
                                                  isChipHovered && !isSel
                                                      ? [
                                                    BoxShadow(
                                                        color: chipColor
                                                            .withOpacity(
                                                            0.22),
                                                        blurRadius: 10,
                                                        spreadRadius: 1)
                                                  ]
                                                      : [],
                                                ),
                                                child: Row(
                                                    mainAxisSize:
                                                    MainAxisSize.min,
                                                    children: [
                                                      if (isSel) ...[
                                                        Icon(
                                                            Icons.check_rounded,
                                                            color: chipColor,
                                                            size: 13),
                                                        const SizedBox(width: 5),
                                                      ] else if (isChipHovered) ...[
                                                        Icon(
                                                            Icons
                                                                .touch_app_rounded,
                                                            color: chipColor
                                                                .withOpacity(0.7),
                                                            size: 13),
                                                        const SizedBox(width: 5),
                                                      ],
                                                      Text(lbl,
                                                          style: TextStyle(
                                                            color: (isSel ||
                                                                isChipHovered)
                                                                ? chipColor
                                                                : _tk.txt,
                                                            fontSize: 13.5,
                                                            fontWeight: (isSel ||
                                                                isChipHovered)
                                                                ? FontWeight.w700
                                                                : FontWeight.w500,
                                                          )),
                                                    ]),
                                              ),
                                            ),
                                          );
                                        }),
                                    ]),
                                const SizedBox(height: 18),
                                _fieldLabel('Damaged Working Space *'),
                                // ── Damaged Space dropdown with hover ────────
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) =>
                                      setS(() => hoverDamagedSpace = true),
                                  onExit: (_) =>
                                      setS(() => hoverDamagedSpace = false),
                                  child: _dropdownTile(
                                    icon: Icons.foundation_rounded,
                                    label: damagedCode == null
                                        ? 'Select damaged space…'
                                        : damagedOptions
                                        .firstWhere(
                                            (e) => e['code'] == damagedCode,
                                        orElse: () => {
                                          'name': damagedCode ?? ''
                                        })['name']!,
                                    isSelected: damagedCode != null,
                                    isHovered: hoverDamagedSpace,
                                    accent: _tk.amber,
                                    onTap: () => _showDamagedSpaceSheet(
                                        ctx, damagedCode, (code, name) {
                                      setS(() => damagedCode = code);
                                    }),
                                  ),
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
                                    style: TextStyle(
                                        color: _tk.txtHead, fontSize: 13.5),
                                    onChanged: filterAddr,
                                    decoration: InputDecoration(
                                      hintText: 'Search barangay…',
                                      hintStyle: TextStyle(
                                          color: _tk.txtMuted, fontSize: 13.5),
                                      prefixIcon: Icon(Icons.search_rounded,
                                          color: _tk.txtMuted, size: 18),
                                      border: InputBorder.none,
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (selectedAddress != null)
                                  Container(
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
                                      Expanded(
                                          child: Text(selectedAddress!,
                                              style: TextStyle(
                                                  color: _tk.txtHead,
                                                  fontSize: 13,
                                                  fontWeight:
                                                  FontWeight.w600))),
                                      MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          onTap: () => setS(
                                                  () => selectedAddress = null),
                                          child: Icon(Icons.close_rounded,
                                              color: _tk.txtMuted, size: 15),
                                        ),
                                      ),
                                    ]),
                                  ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: _tk.surf,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _tk.bd),
                                  ),
                                  child: filteredAddresses.isEmpty
                                      ? Center(
                                      child: Text('No results',
                                          style: TextStyle(
                                              color: _tk.txtMuted,
                                              fontSize: 13)))
                                      : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    itemCount: filteredAddresses.length,
                                    itemBuilder: (_, i) {
                                      final addr = filteredAddresses[i];
                                      final isSel =
                                          selectedAddress == addr;
                                      // ── hover state for this barangay item ──
                                      final isAddrHovered =
                                          hoverAddr == addr;

                                      return MouseRegion(
                                        cursor:
                                        SystemMouseCursors.click,
                                        onEnter: (_) => setS(
                                                () => hoverAddr = addr),
                                        onExit: (_) => setS(
                                                () => hoverAddr = null),
                                        child: GestureDetector(
                                          onTap: () => setS(() =>
                                          selectedAddress = addr),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 130),
                                            margin:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2),
                                            padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isSel
                                                  ? _tk.blueBg
                                                  : isAddrHovered
                                                  ? _tk.blue
                                                  .withOpacity(0.05)
                                                  : Colors.transparent,
                                              borderRadius:
                                              BorderRadius.circular(9),
                                              border: Border.all(
                                                color: isSel
                                                    ? _tk.blueBd
                                                    : isAddrHovered
                                                    ? _tk.blue
                                                    .withOpacity(
                                                    0.28)
                                                    : Colors
                                                    .transparent,
                                                width: (isSel ||
                                                    isAddrHovered)
                                                    ? 1.5
                                                    : 1,
                                              ),
                                              boxShadow: isAddrHovered &&
                                                  !isSel
                                                  ? [
                                                BoxShadow(
                                                    color: _tk.blue
                                                        .withOpacity(
                                                        0.12),
                                                    blurRadius: 8,
                                                    spreadRadius:
                                                    1)
                                              ]
                                                  : [],
                                            ),
                                            child: Row(children: [
                                              Icon(
                                                isSel
                                                    ? Icons
                                                    .check_circle_rounded
                                                    : isAddrHovered
                                                    ? Icons
                                                    .location_on_rounded
                                                    : Icons
                                                    .location_on_outlined,
                                                color: isSel
                                                    ? _tk.blue
                                                    : isAddrHovered
                                                    ? _tk.blue
                                                    .withOpacity(
                                                    0.7)
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
                                                              ? FontWeight
                                                              .w600
                                                              : FontWeight
                                                              .w400))),
                                              // small arrow indicator on hover
                                              if (isAddrHovered && !isSel)
                                                Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  color: _tk.blue
                                                      .withOpacity(0.5),
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
                                _fieldLabel(
                                    'Remarks / Specific Location (optional)'),
                                TextField(
                                  controller: remarksCtrl,
                                  maxLines: 3,
                                  style: TextStyle(
                                      color: _tk.txtHead, fontSize: 13.5),
                                  decoration: dsInputOf(context, '',
                                      hint:
                                      'e.g. near the old market, beside the church',
                                      icon: Icons.notes_rounded),
                                ),
                                const SizedBox(height: 6),
                              ]),
                        )),

                    // ── Footer ───────────────────────────────────────────
                    Container(
                      padding:
                      const EdgeInsets.fromLTRB(22, 14, 22, 20),
                      decoration: BoxDecoration(
                        color: _tk.surf,
                        border: Border(top: BorderSide(color: _tk.bd)),
                      ),
                      child: Row(children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setS(() => hoverCancel = true),
                          onExit: (_) =>
                              setS(() => hoverCancel = false),
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 46,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              decoration: BoxDecoration(
                                color: hoverCancel
                                    ? const Color(0xFFFEE2E2)
                                    : _tk.surf2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: hoverCancel
                                        ? const Color(0xFFDC2626)
                                        : _tk.bd),
                                boxShadow: hoverCancel
                                    ? [
                                  BoxShadow(
                                      color: const Color(0xFFDC2626)
                                          .withOpacity(0.25),
                                      blurRadius: 10,
                                      spreadRadius: 1)
                                ]
                                    : [],
                              ),
                              child: Center(
                                  child: Text('Cancel',
                                      style: TextStyle(
                                          color: hoverCancel
                                              ? const Color(0xFF991B1B)
                                              : _tk.txt,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setS(() => hoverSave = true),
                              onExit: (_) => setS(() => hoverSave = false),
                              child: GestureDetector(
                                onTap: () async {
                                  if (workTypeCode == null ||
                                      difficultyLevel == null ||
                                      damagedCode == null ||
                                      selectedAddress == null) {
                                    _snack(
                                        'Please complete all required fields',
                                        error: true);
                                    return;
                                  }
                                  final wtName = workTypes
                                      .firstWhere(
                                          (e) => e['code'] == workTypeCode,
                                      orElse: () =>
                                      {'name': workTypeCode ?? ''})['name']!;
                                  final dmgName = damagedOptions
                                      .firstWhere(
                                          (e) => e['code'] == damagedCode,
                                      orElse: () =>
                                      {'name': damagedCode ?? ''})['name']!;
                                  try {
                                    await Supabase.instance.client
                                        .from('job_orders')
                                        .insert({
                                      'jo_number': joCtrl.text.trim(),
                                      'work_type_code': workTypeCode,
                                      'work_type_name': wtName,
                                      'difficulty_level': difficultyLevel,
                                      'damaged_space_code': damagedCode,
                                      'damaged_space_name': dmgName,
                                      'address': selectedAddress,
                                      'remarks':
                                      remarksCtrl.text.trim().isEmpty
                                          ? null
                                          : remarksCtrl.text.trim(),
                                      'created_at': DateTime.now()
                                          .toUtc()
                                          .toIso8601String(),
                                      'status': 'pending',
                                      'team_id': null,
                                      'created_by_user_id':
                                      AppSession.instance.userId,
                                    });
                                    final savedJo = joCtrl.text.trim();
                                    Navigator.pop(ctx);
                                    _snack('Complaint "$savedJo" created!');
                                    await _fetchAll();
                                    _flashNewCard(savedJo);
                                  } catch (e) {
                                    _snack('Error: $e', error: true);
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        hoverSave
                                            ? _tk.blue.withOpacity(0.85)
                                            : _tk.blue,
                                        _tk.blue.withOpacity(0.82),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                          color: _tk.blue.withOpacity(
                                              hoverSave ? 0.55 : 0.32),
                                          blurRadius: hoverSave ? 22 : 14,
                                          spreadRadius: hoverSave ? 2 : 0,
                                          offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: const Center(
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.save_rounded,
                                                color: Colors.white, size: 17),
                                            SizedBox(width: 7),
                                            Text('Save Complaint',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700)),
                                          ])),
                                ),
                              ),
                            )),
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

  // ── Assign Team Dialog ────────────────────────────────────────────────────

  void _showAssignTeamDialog(Map<String, dynamic> job) async {
    List<Map<String, dynamic>> teams = [];
    String? selectedTeamId;
    int selectedShiftIndex = 0;

    bool hoverClose = false;
    bool hoverCancel = false;
    bool hoverAssign = false;
    int? hoverShiftIndex;
    String? hoverTeamId;

    try {
      final teamsRes = await Supabase.instance.client
          .from('teams')
          .select(
          'id, team_name, foreman_id, personnel_ids, foreman:foreman_id (name, profile_pic_url)')
          .order('team_name');
      final teamsWithMembers = <Map<String, dynamic>>[];
      for (final team in teamsRes) {
        final membersRes = await Supabase.instance.client
            .from('personnel')
            .select('id, name, profile_pic_url')
            .inFilter('id', team['personnel_ids'] ?? []);
        teamsWithMembers.add({...team, 'members': membersRes});
      }
      teams = teamsWithMembers;
    } catch (e) {
      _snack('Error loading teams: $e', error: true);
      return;
    }

    if (!mounted) return;

    final accent = _accentForCode(job['work_type_code'] as String?);
    final remarks = (job['remarks'] as String?)?.trim() ?? '';

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(maxWidth: 560, maxHeight: 820),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Scaffold(
                  backgroundColor: _tk.bg,
                  body: Column(children: [
                    // ── Hero ─────────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withOpacity(0.78)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(children: [
                        Positioned.fill(
                            child: CustomPaint(painter: _DotPainter())),
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(22, 22, 22, 20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color:
                                      Colors.white.withOpacity(0.18),
                                      borderRadius:
                                      BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.white
                                              .withOpacity(0.25)),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.groups_rounded,
                                              color: Colors.white,
                                              size: 12),
                                          const SizedBox(width: 5),
                                          Text(job['jo_number'] ?? 'JO',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.5,
                                                  fontWeight:
                                                  FontWeight.w800,
                                                  letterSpacing: 1.2)),
                                        ]),
                                  ),
                                  const Spacer(),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) =>
                                        setS(() => hoverClose = true),
                                    onExit: (_) =>
                                        setS(() => hoverClose = false),
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(ctx),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 150),
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: hoverClose
                                              ? Colors.red
                                              .withOpacity(0.35)
                                              : Colors.white
                                              .withOpacity(0.18),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          border: Border.all(
                                              color: hoverClose
                                                  ? Colors.red
                                                  .withOpacity(0.6)
                                                  : Colors.white
                                                  .withOpacity(0.25)),
                                          boxShadow: hoverClose
                                              ? [
                                            BoxShadow(
                                                color: Colors.red
                                                    .withOpacity(
                                                    0.45),
                                                blurRadius: 12,
                                                spreadRadius: 1)
                                          ]
                                              : [],
                                        ),
                                        child: const Icon(
                                            Icons.close_rounded,
                                            color: Colors.white,
                                            size: 17),
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 16),
                                const Text('Assign Team',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5)),
                                const SizedBox(height: 4),
                                Text(
                                    '${job['work_type_name'] ?? '—'}  •  ${job['address'] ?? '—'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color:
                                        Colors.white.withOpacity(0.82),
                                        fontSize: 12)),
                              ]),
                        ),
                      ]),
                    ),

                    Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _tk.surf,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _tk.bd),
                                    boxShadow: _tk.shadowSm,
                                  ),
                                  child: Column(children: [
                                    _summaryRow(Icons.build_rounded, 'Work Type',
                                        job['work_type_name'] ?? '—'),
                                    _summaryRow(
                                        Icons.foundation_rounded,
                                        'Damaged Space',
                                        job['damaged_space_name'] ?? '—'),
                                    _summaryRow(
                                        Icons.location_on_rounded,
                                        'Address',
                                        job['address'] ?? '—'),
                                    _summaryRow(
                                        Icons.speed_rounded,
                                        'Difficulty',
                                        _diffLabel(
                                            job['difficulty_level'] as int?),
                                        last: remarks.isEmpty),
                                    if (remarks.isNotEmpty)
                                      _summaryRow(
                                        Icons.notes_rounded,
                                        'Remarks',
                                        remarks,
                                        last: true,
                                      ),
                                  ]),
                                ),
                                const SizedBox(height: 20),
                                _fieldLabel('Shift Time *'),
                                Column(
                                  children: List.generate(
                                      shiftTimes.length,
                                          (i) => MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        onEnter: (_) => setS(
                                                () => hoverShiftIndex = i),
                                        onExit: (_) => setS(
                                                () => hoverShiftIndex = null),
                                        child: GestureDetector(
                                          onTap: () => setS(
                                                  () => selectedShiftIndex = i),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 150),
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12),
                                            decoration: BoxDecoration(
                                              color: selectedShiftIndex == i
                                                  ? accent.withOpacity(0.08)
                                                  : hoverShiftIndex == i
                                                  ? accent
                                                  .withOpacity(0.04)
                                                  : _tk.surf2,
                                              borderRadius:
                                              BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: selectedShiftIndex ==
                                                      i
                                                      ? accent
                                                      .withOpacity(0.45)
                                                      : hoverShiftIndex == i
                                                      ? accent
                                                      .withOpacity(
                                                      0.30)
                                                      : _tk.bd,
                                                  width: selectedShiftIndex ==
                                                      i ||
                                                      hoverShiftIndex == i
                                                      ? 1.5
                                                      : 1),
                                              boxShadow:
                                              hoverShiftIndex == i &&
                                                  selectedShiftIndex !=
                                                      i
                                                  ? [
                                                BoxShadow(
                                                    color: accent
                                                        .withOpacity(
                                                        0.15),
                                                    blurRadius: 10,
                                                    spreadRadius: 1)
                                              ]
                                                  : [],
                                            ),
                                            child: Row(children: [
                                              Icon(Icons.schedule_rounded,
                                                  color: selectedShiftIndex ==
                                                      i
                                                      ? accent
                                                      : hoverShiftIndex == i
                                                      ? accent
                                                      .withOpacity(0.7)
                                                      : _tk.txtMuted,
                                                  size: 16),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                  child: Text(shiftTimes[i],
                                                      style: TextStyle(
                                                          color:
                                                          selectedShiftIndex ==
                                                              i
                                                              ? _tk.txtHead
                                                              : hoverShiftIndex ==
                                                              i
                                                              ? _tk
                                                              .txtHead
                                                              : _tk.txt,
                                                          fontSize: 13.5,
                                                          fontWeight:
                                                          selectedShiftIndex ==
                                                              i
                                                              ? FontWeight
                                                              .w700
                                                              : FontWeight
                                                              .w400))),
                                              if (selectedShiftIndex == i)
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: accent),
                                                  child: const Icon(
                                                      Icons.check_rounded,
                                                      color: Colors.white,
                                                      size: 12),
                                                ),
                                            ]),
                                          ),
                                        ),
                                      )),
                                ),
                                const SizedBox(height: 20),
                                _fieldLabel('Select Team *'),
                                if (teams.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                        color: _tk.surf2,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _tk.bd)),
                                    child: Center(
                                        child: Text('No teams available',
                                            style: TextStyle(
                                                color: _tk.txtMuted))),
                                  )
                                else
                                  ...teams.map((team) {
                                    final isSel = selectedTeamId == team['id'];
                                    final teamId =
                                        team['id']?.toString() ?? '';
                                    final isTeamHovered =
                                        hoverTeamId == teamId;
                                    final leader = team['foreman']
                                    as Map<String, dynamic>?;
                                    final members =
                                        team['members'] as List? ?? [];
                                    final leaderName =
                                        leader?['name'] as String? ??
                                            'No leader';
                                    final leaderPic =
                                    leader?['profile_pic_url'] as String?;
                                    final initial =
                                    (team['team_name'] as String? ??
                                        '?')[0]
                                        .toUpperCase();

                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      onEnter: (_) =>
                                          setS(() => hoverTeamId = teamId),
                                      onExit: (_) =>
                                          setS(() => hoverTeamId = null),
                                      child: GestureDetector(
                                        onTap: () => setS(() => selectedTeamId =
                                        isSel
                                            ? null
                                            : team['id'] as String?),
                                        child: AnimatedContainer(
                                          duration:
                                          const Duration(milliseconds: 160),
                                          margin:
                                          const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isSel
                                                ? accent.withOpacity(0.07)
                                                : isTeamHovered
                                                ? accent.withOpacity(0.03)
                                                : _tk.surf2,
                                            borderRadius:
                                            BorderRadius.circular(13),
                                            border: Border.all(
                                                color: isSel
                                                    ? accent.withOpacity(0.45)
                                                    : isTeamHovered
                                                    ? accent.withOpacity(0.28)
                                                    : _tk.bd,
                                                width:
                                                isSel || isTeamHovered
                                                    ? 1.5
                                                    : 1),
                                            boxShadow: isTeamHovered && !isSel
                                                ? [
                                              BoxShadow(
                                                  color: accent
                                                      .withOpacity(0.12),
                                                  blurRadius: 12,
                                                  spreadRadius: 1)
                                            ]
                                                : [],
                                          ),
                                          child: Row(children: [
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSel
                                                    ? accent.withOpacity(0.12)
                                                    : _tk.surf3,
                                                border: Border.all(
                                                    color: isSel
                                                        ? accent.withOpacity(0.35)
                                                        : _tk.bd,
                                                    width: 1.5),
                                              ),
                                              child: ClipOval(
                                                child: leaderPic != null
                                                    ? Image.network(leaderPic,
                                                    fit: BoxFit.cover)
                                                    : Center(
                                                    child: Text(initial,
                                                        style: TextStyle(
                                                            color: isSel
                                                                ? accent
                                                                : _tk.txtMuted,
                                                            fontSize: 15,
                                                            fontWeight:
                                                            FontWeight
                                                                .w800))),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                          team['team_name'] ??
                                                              'Unnamed',
                                                          style: TextStyle(
                                                              color: _tk.txtHead,
                                                              fontSize: 13,
                                                              fontWeight:
                                                              FontWeight.w700)),
                                                      Text(
                                                          '$leaderName  •  ${members.length} member${members.length == 1 ? '' : 's'}',
                                                          style: TextStyle(
                                                              color: _tk.txtMuted,
                                                              fontSize: 11.5)),
                                                    ])),
                                            AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 160),
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSel
                                                    ? accent
                                                    : Colors.transparent,
                                                border: Border.all(
                                                    color: isSel
                                                        ? accent
                                                        : _tk.bd2,
                                                    width: 1.5),
                                              ),
                                              child: isSel
                                                  ? const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 12)
                                                  : null,
                                            ),
                                          ]),
                                        ),
                                      ),
                                    );
                                  }),
                              ]),
                        )),

                    // ── Footer ───────────────────────────────────────────
                    Container(
                      padding:
                      const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      decoration: BoxDecoration(
                        color: _tk.surf,
                        border: Border(top: BorderSide(color: _tk.bd)),
                      ),
                      child: Row(children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setS(() => hoverCancel = true),
                          onExit: (_) =>
                              setS(() => hoverCancel = false),
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 46,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              decoration: BoxDecoration(
                                color: hoverCancel
                                    ? const Color(0xFFFEE2E2)
                                    : _tk.surf2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: hoverCancel
                                        ? const Color(0xFFDC2626)
                                        : _tk.bd),
                                boxShadow: hoverCancel
                                    ? [
                                  BoxShadow(
                                      color: const Color(0xFFDC2626)
                                          .withOpacity(0.25),
                                      blurRadius: 10,
                                      spreadRadius: 1)
                                ]
                                    : [],
                              ),
                              child: Center(
                                  child: Text('Cancel',
                                      style: TextStyle(
                                          color: hoverCancel
                                              ? const Color(0xFF991B1B)
                                              : _tk.txt,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: MouseRegion(
                              cursor: selectedTeamId != null
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.forbidden,
                              onEnter: (_) =>
                                  setS(() => hoverAssign = true),
                              onExit: (_) =>
                                  setS(() => hoverAssign = false),
                              child: GestureDetector(
                                onTap: selectedTeamId == null
                                    ? null
                                    : () async {
                                  try {
                                    await Supabase.instance.client
                                        .from('job_orders')
                                        .update({
                                      'team_id': selectedTeamId,
                                      'shift_time':
                                      shiftTimes[selectedShiftIndex],
                                      'shift_index': selectedShiftIndex,
                                    }).eq('id', job['id']);
                                    Navigator.pop(ctx);
                                    _snack(
                                        'Team assigned! Complaint moved to Job Orders.');
                                    _fetchAll();
                                  } catch (e) {
                                    _snack('Error: $e', error: true);
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: selectedTeamId != null
                                        ? LinearGradient(
                                      colors: [
                                        accent,
                                        accent.withOpacity(0.82)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                        : null,
                                    color: selectedTeamId == null
                                        ? _tk.bd
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: selectedTeamId != null &&
                                        hoverAssign
                                        ? [
                                      BoxShadow(
                                          color:
                                          accent.withOpacity(0.50),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 4))
                                    ]
                                        : selectedTeamId != null
                                        ? [
                                      BoxShadow(
                                          color:
                                          accent.withOpacity(0.28),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3))
                                    ]
                                        : [],
                                  ),
                                  child: Center(
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.groups_rounded,
                                                color: Colors.white, size: 17),
                                            const SizedBox(width: 7),
                                            Text(
                                                selectedTeamId == null
                                                    ? 'Select a team first'
                                                    : 'Assign & Create Job Order',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w700)),
                                          ])),
                                ),
                              ),
                            )),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tk.bg,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(28, 44, 28, 20),
          decoration: BoxDecoration(
            color: _tk.surf,
            border: Border(bottom: BorderSide(color: _tk.bd)),
            boxShadow: _tk.shadowSm,
          ),
          child: SafeArea(
            bottom: false,
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_tk.blue, _tk.blue.withOpacity(0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                        color: _tk.blue.withOpacity(0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Complaints',
                            style: TextStyle(
                                color: _tk.txtHead,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text(
                            'Left: unassigned complaints  •  Right: active job orders',
                            style: TextStyle(
                                color: _tk.txtMuted, fontSize: 12.5)),
                      ])),

              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoverRefresh = true),
                onExit: (_) => setState(() => _hoverRefresh = false),
                child: GestureDetector(
                  onTap: _fetchAll,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _hoverRefresh ? _tk.blueBg : _tk.surf2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                          _hoverRefresh ? _tk.blueBd : _tk.bd),
                      boxShadow:
                      _glowShadow(_tk.blue, active: _hoverRefresh),
                    ),
                    child: Icon(Icons.refresh_rounded,
                        color: _hoverRefresh ? _tk.blue : _tk.txtMuted,
                        size: 18),
                  ),
                ),
              ),

              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoverNew = true),
                onExit: (_) => setState(() => _hoverNew = false),
                child: GestureDetector(
                  onTap: _showCreateDialog,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [
                            _tk.blue,
                            _tk.blue.withOpacity(0.82)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                            color: _tk.blue.withOpacity(
                                _hoverNew ? 0.52 : 0.30),
                            blurRadius: _hoverNew ? 20 : 10,
                            spreadRadius: _hoverNew ? 2 : 0,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              color: Colors.white, size: 17),
                          SizedBox(width: 7),
                          Text('New Complaint',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ),
              ),
            ]),
          ),
        ),

        if (!_isLoading) _buildStatsBar(),

        Expanded(
          child: _isLoading
              ? const DsLoading()
              : FadeTransition(
            opacity: _entryAnim,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildLeftPanel()),
                VerticalDivider(
                    width: 1, thickness: 1, color: _tk.bd),
                Expanded(child: _buildRightPanel()),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Stats bar ─────────────────────────────────────────────────────────────

  Widget _buildStatsBar() {
    final total = _unassignedJobs.length;
    final assigned = _assignedJobs.length;
    final wtCounts = _workTypeCounts;
    final topWt = wtCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topWtEntry = topWt.isNotEmpty ? topWt.first : null;
    final diffs = _diffCounts;
    final diffTotal = total == 0 ? 1 : total;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _tk.surf,
        border: Border(bottom: BorderSide(color: _tk.bd)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _statChip(
              icon: Icons.inbox_rounded,
              label: 'Unassigned',
              value: '$total',
              accent: _tk.amber),
          const SizedBox(width: 8),
          _statChip(
              icon: Icons.work_history_rounded,
              label: 'Active J.O.',
              value: '$assigned',
              accent: _tk.blue),
          const SizedBox(width: 16),
          Container(width: 1, height: 34, color: _tk.bd),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('TOP WORK TYPE',
                    style: TextStyle(
                        color: _tk.txtMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4)),
                const SizedBox(height: 3),
                topWtEntry == null
                    ? Text('—',
                    style:
                    TextStyle(color: _tk.txtMuted, fontSize: 12))
                    : Row(children: [
                  Expanded(
                    child: Text(
                      topWtEntry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _tk.txtHead,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _tk.blueBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _tk.blueBd),
                    ),
                    child: Text('${topWtEntry.value}',
                        style: TextStyle(
                            color: _tk.blue,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 34, color: _tk.bd),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('DIFFICULTY',
                  style: TextStyle(
                      color: _tk.txtMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4)),
              const SizedBox(height: 5),
              Row(children: [
                _diffMiniBar(
                    label: 'Minor',
                    count: diffs[1] ?? 0,
                    total: diffTotal,
                    color: const Color(0xFF0891B2)),
                const SizedBox(width: 10),
                _diffMiniBar(
                    label: 'Moderate',
                    count: diffs[2] ?? 0,
                    total: diffTotal,
                    color: const Color(0xFFD97706)),
                const SizedBox(width: 10),
                _diffMiniBar(
                    label: 'Major',
                    count: diffs[3] ?? 0,
                    total: diffTotal,
                    color: const Color(0xFFDC2626)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: accent, size: 14),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1)),
          Text(label,
              style: TextStyle(
                  color: accent.withOpacity(0.75), fontSize: 9.5)),
        ]),
      ]),
    );
  }

  Widget _diffMiniBar({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final pct = total > 0 ? count / total : 0.0;
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(color: _tk.txtMuted, fontSize: 9.5)),
              Text('$count',
                  style: TextStyle(
                      color: _tk.txtHead,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ── LEFT PANEL ────────────────────────────────────────────────────────────

  Widget _buildLeftPanel() {
    final items = _filteredUnassigned;
    return Column(children: [
      _panelHeader(
        icon: Icons.inbox_rounded,
        label: 'Unassigned Complaints',
        count: _unassignedJobs.length,
        accent: _tk.amber,
        controller: _leftSearch,
        hint: 'Search complaints…',
      ),
      Expanded(
        child: items.isEmpty
            ? _buildEmptyPanel(
          icon: Icons.inbox_outlined,
          title: _leftSearch.text.isEmpty
              ? 'No unassigned complaints'
              : 'No matching complaints',
          subtitle: _leftSearch.text.isEmpty
              ? 'Tap "New Complaint" to add one'
              : 'Try different keywords',
          accent: _tk.amber,
        )
            : ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: items.length,
          itemBuilder: (_, i) => _buildComplaintCard(items[i]),
        ),
      ),
    ]);
  }

  Widget _buildComplaintCard(Map<String, dynamic> job) {
    final accent = _accentForCode(job['work_type_code'] as String?);
    final diff = job['difficulty_level'] as int? ?? 2;
    final diffColor = {
      1: const Color(0xFF0891B2),
      2: const Color(0xFFD97706),
      3: const Color(0xFFDC2626),
    }[diff]!;
    final createdAt = job['created_at'] as String?;
    final dateStr = createdAt != null
        ? DateFormat('MMM d, h:mm a')
        .format(DateTime.parse(createdAt).toLocal())
        : '—';

    final jobId = job['id']?.toString() ?? '';
    final joNum = job['jo_number']?.toString() ?? '';
    final isHovered = _hoveredAssignId == jobId;
    final isCardHovered = _hoveredCardId == jobId;
    final isFlashing = _flashJoNumber == joNum;

    return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredCardId = jobId),
        onExit: (_) => setState(() => _hoveredCardId = null),
        child: GestureDetector(
          onTap: () => _showAssignTeamDialog(job),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: isFlashing ? 1.0 : 0.0, end: 0.0),
            duration: const Duration(milliseconds: 900),
            builder: (_, flashVal, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color:
                  isCardHovered ? accent.withOpacity(0.04) : _tk.surf,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isFlashing
                          ? _tk.blue.withOpacity(flashVal)
                          : isCardHovered
                          ? accent.withOpacity(0.50)
                          : _tk.bd,
                      width: (isFlashing || isCardHovered) ? 1.5 : 1),
                  boxShadow: isFlashing && flashVal > 0
                      ? [
                    BoxShadow(
                        color: _tk.blue.withOpacity(flashVal * 0.35),
                        blurRadius: 16,
                        spreadRadius: 1)
                  ]
                      : isCardHovered
                      ? [
                    BoxShadow(
                        color: accent.withOpacity(0.20),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 4))
                  ]
                      : _tk.shadowSm,
                ),
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Row(children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                job['jo_number'] ?? 'No J.O#',
                                style: TextStyle(
                                    color: _tk.txtHead,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: diffColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: diffColor.withOpacity(0.28)),
                              ),
                              child: Text(_diffLabel(diff),
                                  style: TextStyle(
                                      color: diffColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(job['work_type_name'] ?? '—',
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if ((job['address'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(children: [
                              Icon(Icons.location_on_rounded,
                                  size: 10, color: _tk.txtMuted),
                              const SizedBox(width: 3),
                              Expanded(
                                  child: Text(job['address'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: _tk.txtMuted,
                                          fontSize: 11))),
                            ]),
                          ],
                          const SizedBox(height: 5),
                          Row(children: [
                            Icon(Icons.access_time_rounded,
                                size: 10, color: _tk.txtMuted),
                            const SizedBox(width: 3),
                            Text(dateStr,
                                style: TextStyle(
                                    color: _tk.txtMuted, fontSize: 10.5)),
                            const Spacer(),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setState(() => _hoveredAssignId = jobId),
                              onExit: (_) =>
                                  setState(() => _hoveredAssignId = null),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isHovered
                                      ? accent.withOpacity(0.18)
                                      : accent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: isHovered
                                          ? accent.withOpacity(0.55)
                                          : accent.withOpacity(0.25)),
                                  boxShadow: isHovered
                                      ? [
                                    BoxShadow(
                                        color:
                                        accent.withOpacity(0.30),
                                        blurRadius: 8,
                                        spreadRadius: 1)
                                  ]
                                      : [],
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.groups_rounded,
                                          color: accent, size: 10),
                                      const SizedBox(width: 4),
                                      Text('Assign',
                                          style: TextStyle(
                                              color: accent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700)),
                                    ]),
                              ),
                            ),
                          ]),
                        ]),
                  ),
                ),
              ]),
            ),
          ),
        ));
  }

  // ── RIGHT PANEL ───────────────────────────────────────────────────────────

  Widget _buildRightPanel() {
    final items = _filteredAssigned;
    return Column(children: [
      _panelHeader(
        icon: Icons.work_history_rounded,
        label: 'Pending Job Orders',
        count: _assignedJobs.length,
        accent: _tk.blue,
        controller: _rightSearch,
        hint: 'Search job orders…',
      ),
      Expanded(
        child: items.isEmpty
            ? _buildEmptyPanel(
          icon: Icons.work_outline_rounded,
          title: _rightSearch.text.isEmpty
              ? 'No active job orders'
              : 'No matching job orders',
          subtitle: _rightSearch.text.isEmpty
              ? 'Assign a team to a complaint to create one'
              : 'Try different keywords',
          accent: _tk.blue,
        )
            : ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: items.length,
          itemBuilder: (_, i) => _buildJobOrderCard(items[i]),
        ),
      ),
    ]);
  }

  Widget _buildJobOrderCard(Map<String, dynamic> job) {
    final accent = _accentForCode(job['work_type_code'] as String?);
    final teamName = job['team']?['team_name'] as String? ?? '—';
    final diff = job['difficulty_level'] as int? ?? 2;
    final diffColor = {
      1: const Color(0xFF0891B2),
      2: const Color(0xFFD97706),
      3: const Color(0xFFDC2626),
    }[diff]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _tk.surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tk.bd),
        boxShadow: _tk.shadowSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Row(children: [
          Container(width: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          job['jo_number'] ?? '—',
                          style: TextStyle(
                              color: _tk.txtHead,
                              fontSize: 13,
                              fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: diffColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: diffColor.withOpacity(0.28)),
                        ),
                        child: Text(_diffLabel(diff),
                            style: TextStyle(
                                color: diffColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.groups_rounded, size: 11, color: accent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(teamName,
                            style: TextStyle(
                                color: accent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(job['work_type_name'] ?? '—',
                        style:
                        TextStyle(color: _tk.txt, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if ((job['address'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.location_on_rounded,
                            size: 10, color: _tk.txtMuted),
                        const SizedBox(width: 3),
                        Expanded(
                            child: Text(job['address'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: _tk.txtMuted, fontSize: 11))),
                      ]),
                    ],
                    if ((job['shift_time'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.access_time_rounded,
                            size: 10, color: _tk.txtMuted),
                        const SizedBox(width: 3),
                        Text(job['shift_time'],
                            style: TextStyle(
                                color: _tk.txtMuted, fontSize: 10.5)),
                      ]),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _tk.amberBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _tk.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: _tk.amber,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text('Pending',
                                style: TextStyle(
                                    color: _tk.amber,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Panel header ──────────────────────────────────────────────────────────

  Widget _panelHeader({
    required IconData icon,
    required String label,
    required int count,
    required Color accent,
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: _tk.surf2,
        border: Border(bottom: BorderSide(color: _tk.bd)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withOpacity(0.22)),
            ),
            child: Icon(icon, color: accent, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: _tk.txtHead,
                      fontSize: 13,
                      fontWeight: FontWeight.w700))),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: _tk.surf,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _tk.bd),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(color: _tk.txtHead, fontSize: 12.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _tk.txtMuted, fontSize: 12.5),
              prefixIcon:
              Icon(Icons.search_rounded, color: _tk.txtMuted, size: 16),
              suffixIcon: controller.text.isNotEmpty
                  ? MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                    onTap: () {
                      controller.clear();
                      setState(() {});
                    },
                    child: Icon(Icons.close_rounded,
                        color: _tk.txtMuted, size: 14)),
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmptyPanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.18)),
            ),
            child:
            Icon(icon, color: accent.withOpacity(0.5), size: 26),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _tk.txtHead,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: _tk.txtMuted, fontSize: 12)),
        ]),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label,
        style: TextStyle(
            color: _tk.txtHead,
            fontSize: 13,
            fontWeight: FontWeight.w600)),
  );

  Widget _dropdownTile({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color accent,
    required VoidCallback onTap,
    bool isHovered = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withOpacity(_tk.dark ? 0.10 : 0.05)
                : isHovered
                ? accent.withOpacity(0.04)
                : _tk.surf,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected
                    ? accent.withOpacity(0.42)
                    : isHovered
                    ? accent.withOpacity(0.35)
                    : _tk.bd,
                width: (isSelected || isHovered) ? 1.5 : 1),
            boxShadow: isHovered && !isSelected
                ? [
              BoxShadow(
                  color: accent.withOpacity(0.15),
                  blurRadius: 10,
                  spreadRadius: 1)
            ]
                : isSelected
                ? [
              BoxShadow(
                  color: accent.withOpacity(0.10), blurRadius: 8)
            ]
                : _tk.shadowSm,
          ),
          child: Row(children: [
            Icon(icon,
                size: 17,
                color: (isSelected || isHovered) ? accent : _tk.txtMuted),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: (isSelected || isHovered)
                            ? _tk.txtHead
                            : _tk.txtMuted,
                        fontSize: 13.5,
                        fontWeight: (isSelected || isHovered)
                            ? FontWeight.w600
                            : FontWeight.w400))),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: (isSelected || isHovered) ? accent : _tk.txtMuted,
                size: 20),
          ]),
        ),
      );

  Widget _summaryRow(IconData icon, String label, String value,
      {bool last = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 12),
        child:
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: _tk.txtMuted),
          const SizedBox(width: 9),
          SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(color: _tk.txtMuted, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: _tk.txtHead,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600))),
        ]),
      );

  String _diffLabel(int? lvl) {
    switch (lvl) {
      case 1:
        return 'Minor';
      case 2:
        return 'Moderate';
      case 3:
        return 'Major';
      default:
        return '—';
    }
  }

  // ── Bottom sheets ─────────────────────────────────────────────────────────

  void _showWorkTypeSheet(BuildContext ctx, String? current,
      Function(String, String) onSelect) {
    // ── hover state lives here, rebuilt via StatefulBuilder ──
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
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                        color: _tk.bd2,
                        borderRadius: BorderRadius.circular(10))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: _tk.blueBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _tk.blueBd)),
                    child:
                    Icon(Icons.build_rounded, color: _tk.blue, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Text('Type of Work',
                      style: TextStyle(
                          color: _tk.txtHead,
                          fontSize: 16,
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
                      final wt = workTypes[i];
                      final isSel = current == wt['code'];
                      final isHov = hoverWtCode == wt['code'];
                      final accent = _accentForCode(wt['code']);

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) =>
                            setSheet(() => hoverWtCode = wt['code']),
                        onExit: (_) =>
                            setSheet(() => hoverWtCode = null),
                        child: GestureDetector(
                          onTap: () {
                            onSelect(wt['code']!, wt['name']!);
                            Navigator.pop(context);
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
                                  ? [
                                BoxShadow(
                                    color:
                                    accent.withOpacity(0.14),
                                    blurRadius: 10,
                                    spreadRadius: 1)
                              ]
                                  : [],
                            ),
                            child: Row(children: [
                              // ── Code badge animates on hover ──
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 36,
                                height: 36,
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
                                child: Center(
                                    child: Text(wt['code']!,
                                        style: TextStyle(
                                            color: isSel || isHov
                                                ? accent
                                                : _tk.txtMuted,
                                            fontSize: 10,
                                            fontWeight:
                                            FontWeight.w800))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(wt['name']!,
                                      style: TextStyle(
                                          color: isSel || isHov
                                              ? _tk.txtHead
                                              : _tk.txt,
                                          fontSize: 14,
                                          fontWeight: isSel || isHov
                                              ? FontWeight.w700
                                              : FontWeight.w400))),
                              // ── Trailing: check or arrow ──
                              if (isSel)
                                Icon(Icons.check_circle_rounded,
                                    color: accent, size: 20)
                              else if (isHov)
                                Icon(Icons.arrow_forward_ios_rounded,
                                    color: accent.withOpacity(0.6),
                                    size: 14),
                            ]),
                          ),
                        ),
                      );
                    },
                  )),
            ]),
          ),
        ),
      ),
    );
  }

  void _showDamagedSpaceSheet(BuildContext ctx, String? current,
      Function(String, String) onSelect) {
    // ── hover state lives here, rebuilt via StatefulBuilder ──
    String? hoverDmgCode;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (_, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.42,
          minChildSize: 0.32,
          maxChildSize: 0.68,
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
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                        color: _tk.bd2,
                        borderRadius: BorderRadius.circular(10))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: _tk.amberBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _tk.amberBd)),
                    child: Icon(Icons.foundation_rounded,
                        color: _tk.amber, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Text('Damaged Working Space',
                      style: TextStyle(
                          color: _tk.txtHead,
                          fontSize: 16,
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
                      final opt = damagedOptions[i];
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
                            onSelect(opt['code']!, opt['name']!);
                            Navigator.pop(context);
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
                                  ? [
                                BoxShadow(
                                    color: _tk.amber.withOpacity(0.14),
                                    blurRadius: 10,
                                    spreadRadius: 1)
                              ]
                                  : [],
                            ),
                            child: Row(children: [
                              // ── Code badge animates on hover ──
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 36,
                                height: 36,
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
                                          : _tk.bd),
                                ),
                                child: Center(
                                    child: Text(opt['code']!,
                                        style: TextStyle(
                                            color: isSel || isHov
                                                ? _tk.amber
                                                : _tk.txtMuted,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(opt['name']!,
                                      style: TextStyle(
                                          color: isSel || isHov
                                              ? _tk.txtHead
                                              : _tk.txt,
                                          fontSize: 14,
                                          fontWeight: isSel || isHov
                                              ? FontWeight.w700
                                              : FontWeight.w400))),
                              // ── Trailing: check or arrow ──
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
                  )),
            ]),
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
    canvas.drawCircle(
        Offset(size.width * 0.88, size.height * 0.18), 50, ring);
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.88), 74, ring);
  }

  @override
  bool shouldRepaint(_) => false;
}