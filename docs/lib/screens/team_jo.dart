import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/data/admin_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// ── Accent palette ────────────────────────────────────────────────────────────
const _teamAccents = [
  Color(0xFF1D6FE8), Color(0xFF7C3AED), Color(0xFF059669),
  Color(0xFFDB2777), Color(0xFF0891B2), Color(0xFFD97706),
  Color(0xFF4338CA), Color(0xFFDC2626),
];

bool _isInMonth(dynamic ts, int year, int month) {
  if (ts == null) return false;
  try {
    final d = DateTime.parse(ts.toString()).toLocal();
    return d.year == year && d.month == month;
  } catch (_) {
    return false;
  }
}

class TeamJoScreen extends StatefulWidget {
  const TeamJoScreen({super.key});
  @override
  State<TeamJoScreen> createState() => _TeamJoScreenState();
}

class _TeamJoScreenState extends State<TeamJoScreen> {
  Tk get _tk => context.tk;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _filteredTeams = [];
  bool _isLoading = true;
  bool _showOverall = false;

  late int _selectedYear;
  late int _selectedMonth;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadTeams();
    _searchController.addListener(_filterTeams);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('teams')
          .select(
          'id, team_name, foreman_id, driver_id, personnel_ids, '
              'foreman:foreman_id (name, profile_pic_url)')
          .order('team_name');

      final teamsWithMembers = <Map<String, dynamic>>[];
      for (final team in response) {
        final membersRes = await Supabase.instance.client
            .from('personnel')
            .select('id, name, profile_pic_url, position')
            .inFilter(
            'id',
            (team['personnel_ids'] as List?)?.cast<dynamic>() ?? []);

        final allJobsRes = await Supabase.instance.client
            .from('job_orders')
            .select('id, status, created_at, completed_at')
            .eq('team_id', team['id']);

        Map<String, dynamic> driver = {};
        final driverId = team['driver_id'];
        if (driverId != null) {
          final driverRes = await Supabase.instance.client
              .from('personnel')
              .select('id, name, profile_pic_url')
              .eq('id', driverId)
              .maybeSingle();
          if (driverRes != null) {
            driver = Map<String, dynamic>.from(driverRes);
          }
        }

        teamsWithMembers.add({
          ...team,
          'members': List<Map<String, dynamic>>.from(membersRes),
          'all_jobs': List<Map<String, dynamic>>.from(allJobsRes),
          'driver': driver,
        });
      }

      if (mounted) {
        setState(() {
          _teams = teamsWithMembers;
          _filteredTeams = List.from(_teams);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: _tk.red));
      }
    }
  }

  void _filterTeams() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredTeams = _teams.where((t) {
        final tn = t['team_name']?.toLowerCase() ?? '';
        final fn = t['foreman']?['name']?.toLowerCase() ?? '';
        return tn.contains(q) || fn.contains(q);
      }).toList();
    });
  }

  _TeamCounts _countsFor(Map<String, dynamic> team) {
    final all = (team['all_jobs'] as List? ?? []).cast<Map<String, dynamic>>();
    final jobs = _showOverall
        ? all
        : all.where((j) {
      if (j['status'] == 'pending') {
        return _isInMonth(j['created_at'], _selectedYear, _selectedMonth);
      }
      if (j['status'] == 'accomplished') {
        return _isInMonth(j['completed_at'], _selectedYear, _selectedMonth);
      }
      return false;
    }).toList();
    final pending = jobs.where((j) => j['status'] == 'pending').length;
    final done = jobs.where((j) => j['status'] == 'accomplished').length;
    return _TeamCounts(pending: pending, done: done);
  }

  String get _monthLabel =>
      DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));

  Future<void> _pickMonthYear() async {
    int tempYear = _selectedYear;
    int tempMonth = _selectedMonth;

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final now = DateTime.now();
          return Dialog(
            backgroundColor: _tk.surf,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _tk.bd)),
            child: SizedBox(
              width: 300,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _tk.violet.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _tk.violet.withOpacity(0.22)),
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          color: _tk.violet, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text('Select Month & Year',
                        style: TextStyle(
                            color: _tk.txtHead,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Icon(Icons.close_rounded,
                          color: _tk.txtMuted, size: 16),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    GestureDetector(
                      onTap: () => setS(() => tempYear--),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: _tk.surf2,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: _tk.bd),
                        ),
                        child: Icon(Icons.chevron_left_rounded,
                            color: _tk.txtMuted, size: 16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('$tempYear',
                        style: TextStyle(
                            color: _tk.txtHead,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () {
                        if (tempYear < now.year) setS(() => tempYear++);
                      },
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: tempYear < now.year ? _tk.surf2 : _tk.bd,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: _tk.bd),
                        ),
                        child: Icon(Icons.chevron_right_rounded,
                            color: tempYear < now.year ? _tk.txtMuted : _tk.bd2,
                            size: 16),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 5,
                      crossAxisSpacing: 5,
                      mainAxisExtent: 32,
                    ),
                    itemCount: 12,
                    itemBuilder: (_, i) {
                      final mNum = i + 1;
                      final isSel = tempMonth == mNum;
                      final isFuture =
                          tempYear == now.year && mNum > now.month;
                      return GestureDetector(
                        onTap: isFuture
                            ? null
                            : () => setS(() => tempMonth = mNum),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          decoration: BoxDecoration(
                            color: isSel
                                ? _tk.violet
                                : isFuture
                                ? _tk.surf2.withOpacity(0.5)
                                : _tk.surf2,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: isSel
                                    ? _tk.violet
                                    : isFuture
                                    ? _tk.bd.withOpacity(0.4)
                                    : _tk.bd),
                          ),
                          child: Center(
                            child: Text(months[i],
                                style: TextStyle(
                                    color: isSel
                                        ? Colors.white
                                        : isFuture
                                        ? _tk.bd2
                                        : _tk.txt,
                                    fontSize: 11,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: 34,
                          decoration: BoxDecoration(
                              color: _tk.surf2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _tk.bd)),
                          child: Center(
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: _tk.txt,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [
                                  _tk.violet,
                                  _tk.violet.withOpacity(0.82)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                  color: _tk.violet.withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: const Center(
                              child: Text('Apply',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );

    if (result == true) {
      setState(() {
        _selectedYear = tempYear;
        _selectedMonth = tempMonth;
        _showOverall = false;
      });
    }
  }

  Widget _buildGalleryCard(Map<String, dynamic> team, int index) {
    final foreman = team['foreman'] ?? {};
    final members = team['members'] as List? ?? [];
    final counts = _countsFor(team);
    final pending = counts.pending;
    final done = counts.done;
    final total = pending + done;
    final rate = total > 0 ? (done / total * 100).round() : 0;
    final accent = _teamAccents[index % _teamAccents.length];
    final foremanName = foreman['name'] as String? ?? 'Leader';
    final teamName = team['team_name'] as String? ?? 'Team';
    final leaderPic = foreman['profile_pic_url'] as String?;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openTeamDetail(team, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _tk.surf,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _tk.bd),
            boxShadow: _tk.shadowSm,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withOpacity(0.72)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(children: [
                      Positioned.fill(
                          child: CustomPaint(painter: _CardDotPainter())),
                      Positioned(
                          top: -18,
                          right: -18,
                          child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.08)))),
                      Positioned(
                          bottom: -12,
                          left: -12,
                          child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.06)))),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(teamName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.3)),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Icon(Icons.people_rounded,
                                              color: Colors.white.withOpacity(0.8),
                                              size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                              '${members.length} member'
                                                  '${members.length == 1 ? '' : 's'}',
                                              style: TextStyle(
                                                  color: Colors.white.withOpacity(0.88),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500)),
                                        ]),
                                      ])),
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.55),
                                      width: 2),
                                  color: Colors.white.withOpacity(0.18),
                                ),
                                child: ClipOval(
                                  child: leaderPic != null
                                      ? Image.network(leaderPic,
                                      fit: BoxFit.cover)
                                      : Center(
                                      child: Text(
                                          foremanName[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17))),
                                ),
                              ),
                            ]),
                      ),
                    ]),
                  ),
                  Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.person_rounded,
                                    size: 12, color: _tk.txtMuted),
                                const SizedBox(width: 5),
                                Expanded(
                                    child: Text(foremanName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: _tk.txt,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600))),
                              ]),
                              const SizedBox(height: 10),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Completion',
                                        style: TextStyle(
                                            color: _tk.txtMuted,
                                            fontSize: 10)),
                                    Text('$rate%',
                                        style: TextStyle(
                                            color: accent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ]),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: total > 0 ? done / total : 0,
                                  backgroundColor: accent.withOpacity(0.10),
                                  valueColor: AlwaysStoppedAnimation(accent),
                                  minHeight: 5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(children: [
                                _statPill('Pending', pending, _tk.amber, _tk.amberBg),
                                const SizedBox(width: 6),
                                _statPill('Done', done, _tk.green, _tk.greenBg),
                              ]),
                            ]),
                      )),
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.05),
                      border: Border(top: BorderSide(color: _tk.bd)),
                    ),
                    child: Center(
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('View Details',
                                  style: TextStyle(
                                      color: accent,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  color: accent, size: 12),
                            ])),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _statPill(String label, int count, Color color, Color bg) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Column(children: [
            Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(
                    color: color.withOpacity(0.75), fontSize: 9.5)),
          ]),
        ),
      );

  void _openTeamDetail(Map<String, dynamic> team, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (_) => _TeamDetailDialog(
        team: team,
        accent: _teamAccents[index % _teamAccents.length],
        initialYear: _selectedYear,
        initialMonth: _selectedMonth,
        initialShowOverall: _showOverall,
      ),
    );
  }

  Widget _toggleBtn({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 13,
              color: active ? Colors.white : _tk.txtMuted),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: active ? Colors.white : _tk.txtMuted,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tk.bg,
      body: Column(children: [
        DsHeader(
          title: 'Teams Overview',
          subtitle: _showOverall
              ? 'All-time data • San Pablo City Water District'
              : '$_monthLabel • San Pablo City Water District',
          icon: Icons.groups_2_rounded,
          accent: _tk.violet,
          actions: [
            if (!_showOverall)
              GestureDetector(
                onTap: _pickMonthYear,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _tk.violet.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _tk.violet.withOpacity(0.28)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_month_rounded,
                        color: _tk.violet, size: 15),
                    const SizedBox(width: 6),
                    Text(_monthLabel,
                        style: TextStyle(
                            color: _tk.violet,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded,
                        color: _tk.violet, size: 16),
                  ]),
                ),
              ),

            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _tk.surf2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _tk.bd),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _toggleBtn(
                  label: 'Monthly',
                  icon: Icons.calendar_month_rounded,
                  active: !_showOverall,
                  activeColor: _tk.violet,
                  onTap: () => setState(() => _showOverall = false),
                ),
                _toggleBtn(
                  label: 'Overall',
                  icon: Icons.bar_chart_rounded,
                  active: _showOverall,
                  activeColor: _tk.blue,
                  onTap: () => setState(() => _showOverall = true),
                ),
              ]),
            ),

            GestureDetector(
              onTap: _loadTeams,
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _tk.surf2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _tk.bd),
                ),
                child: Icon(Icons.refresh_rounded,
                    color: _tk.txtMuted, size: 18),
              ),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: DsSearchBar(
              controller: _searchController,
              hint: 'Search teams or leader…',
              onClear: _filterTeams),
        ),

        Expanded(
          child: _isLoading
              ? const DsLoading()
              : _filteredTeams.isEmpty
              ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_outlined,
                        size: 80, color: _tk.bd2),
                    const SizedBox(height: 20),
                    Text(
                        _searchController.text.isEmpty
                            ? 'No teams found'
                            : 'No matching teams',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _tk.txt)),
                    const SizedBox(height: 8),
                    Text(
                        _searchController.text.isEmpty
                            ? 'Add teams in Admin → Edit Teams'
                            : 'Try different keywords',
                        style: TextStyle(
                            color: _tk.txtMuted,
                            fontSize: 14)),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _tk.violet,
                          side: BorderSide(color: _tk.violet),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30))),
                      onPressed: _loadTeams,
                    ),
                  ]))
              : RefreshIndicator(
            onRefresh: _loadTeams,
            color: _tk.violet,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              gridDelegate:
              const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                mainAxisExtent: 258,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: _filteredTeams.length,
              itemBuilder: (context, index) =>
                  _buildGalleryCard(_filteredTeams[index], index),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TeamCounts {
  final int pending, done;
  const _TeamCounts({required this.pending, required this.done});
}

class _DiffCounts {
  final int minor, moderate, major;
  const _DiffCounts(
      {required this.minor, required this.moderate, required this.major});
}

// ─────────────────────────────────────────────────────────────────────────────
//  Team Detail Dialog  ← SCROLLABLE via NestedScrollView
// ─────────────────────────────────────────────────────────────────────────────
class _TeamDetailDialog extends StatefulWidget {
  final Map<String, dynamic> team;
  final Color accent;
  final int initialYear;
  final int initialMonth;
  final bool initialShowOverall;

  const _TeamDetailDialog({
    required this.team,
    required this.accent,
    required this.initialYear,
    required this.initialMonth,
    required this.initialShowOverall,
  });

  @override
  State<_TeamDetailDialog> createState() => _TeamDetailDialogState();
}

class _TeamDetailDialogState extends State<_TeamDetailDialog>
    with SingleTickerProviderStateMixin {
  Tk get _tk => context.tk;
  late TabController _tab;

  List<Map<String, dynamic>> _allPending = [];
  List<Map<String, dynamic>> _allAccomplished = [];
  bool _isLoading = true;
  late bool _showOverall;
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _showOverall = widget.initialShowOverall;
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
    _tab = TabController(length: 2, vsync: this);
    _fetchJobs();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    try {
      final pendingRes = await Supabase.instance.client
          .from('job_orders')
          .select(
          'id, jo_number, shift_time, work_type_code, work_type_name, '
              'difficulty_level, damaged_space_code, damaged_space_name, '
              'address, remarks, created_at, status, completed_at')
          .eq('team_id', widget.team['id'])
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final accomplishedRes = await Supabase.instance.client
          .from('job_orders')
          .select(
          'id, jo_number, shift_time, work_type_code, work_type_name, '
              'difficulty_level, damaged_space_code, damaged_space_name, '
              'address, remarks, created_at, status, completed_at')
          .eq('team_id', widget.team['id'])
          .eq('status', 'accomplished')
          .order('completed_at', ascending: false);

      if (mounted) {
        setState(() {
          _allPending = List<Map<String, dynamic>>.from(pendingRes);
          _allAccomplished = List<Map<String, dynamic>>.from(accomplishedRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: _tk.red));
      }
    }
  }

  Future<void> _pickMonthYear() async {
    int tempYear = _selectedYear;
    int tempMonth = _selectedMonth;

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final now = DateTime.now();
          return Dialog(
            backgroundColor: _tk.surf,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _tk.bd)),
            child: SizedBox(
              width: 300,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: widget.accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: widget.accent.withOpacity(0.22)),
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          color: widget.accent, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text('Select Month & Year',
                        style: TextStyle(
                            color: _tk.txtHead,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Icon(Icons.close_rounded,
                          color: _tk.txtMuted, size: 16),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    GestureDetector(
                      onTap: () => setS(() => tempYear--),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: _tk.surf2,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: _tk.bd),
                        ),
                        child: Icon(Icons.chevron_left_rounded,
                            color: _tk.txtMuted, size: 16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('$tempYear',
                        style: TextStyle(
                            color: _tk.txtHead,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () {
                        if (tempYear < now.year) setS(() => tempYear++);
                      },
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: tempYear < now.year ? _tk.surf2 : _tk.bd,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: _tk.bd),
                        ),
                        child: Icon(Icons.chevron_right_rounded,
                            color: tempYear < now.year ? _tk.txtMuted : _tk.bd2,
                            size: 16),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 5,
                      crossAxisSpacing: 5,
                      mainAxisExtent: 32,
                    ),
                    itemCount: 12,
                    itemBuilder: (_, i) {
                      final mNum = i + 1;
                      final isSel = tempMonth == mNum;
                      final isFuture = tempYear == now.year && mNum > now.month;
                      return GestureDetector(
                        onTap: isFuture
                            ? null
                            : () => setS(() => tempMonth = mNum),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          decoration: BoxDecoration(
                            color: isSel
                                ? widget.accent
                                : isFuture
                                ? _tk.surf2.withOpacity(0.5)
                                : _tk.surf2,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: isSel
                                    ? widget.accent
                                    : isFuture
                                    ? _tk.bd.withOpacity(0.4)
                                    : _tk.bd),
                          ),
                          child: Center(
                            child: Text(months[i],
                                style: TextStyle(
                                    color: isSel
                                        ? Colors.white
                                        : isFuture
                                        ? _tk.bd2
                                        : _tk.txt,
                                    fontSize: 11,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: 34,
                          decoration: BoxDecoration(
                              color: _tk.surf2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _tk.bd)),
                          child: Center(
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: _tk.txt,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [
                                  widget.accent,
                                  widget.accent.withOpacity(0.82)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                  color: widget.accent.withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: const Center(
                              child: Text('Apply',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );

    if (result == true) {
      setState(() {
        _selectedYear = tempYear;
        _selectedMonth = tempMonth;
        _showOverall = false;
      });
    }
  }

  List<Map<String, dynamic>> get _pendingJobs => _showOverall
      ? _allPending
      : _allPending
      .where((j) =>
      _isInMonth(j['created_at'], _selectedYear, _selectedMonth))
      .toList();

  List<Map<String, dynamic>> get _accomplishedJobs => _showOverall
      ? _allAccomplished
      : _allAccomplished
      .where((j) =>
      _isInMonth(j['completed_at'], _selectedYear, _selectedMonth))
      .toList();

  _DiffCounts get _diffCounts {
    final all = [..._pendingJobs, ..._accomplishedJobs];
    int minor = 0, moderate = 0, major = 0;
    for (final j in all) {
      final d = j['difficulty_level'];
      final int level =
      d is int ? d : int.tryParse(d?.toString() ?? '') ?? 0;
      if (level == 1) minor++;
      else if (level == 2) moderate++;
      else if (level == 3) major++;
    }
    return _DiffCounts(minor: minor, moderate: moderate, major: major);
  }

  String _fmt(dynamic ts) {
    if (ts == null) return '—';
    try {
      return DateFormat('MMM d, yyyy • h:mm a')
          .format(DateTime.parse(ts.toString()).toLocal());
    } catch (_) {
      return ts.toString();
    }
  }

  String get _monthLabel =>
      DateFormat('MMMM yyyy')
          .format(DateTime(_selectedYear, _selectedMonth));

  // ── Builds the sliver header content (hero + strips) ──────────────────────
  Widget _buildSliverHeader() {
    final foreman = widget.team['foreman'] ?? {};
    final members = (widget.team['members'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final driver = (widget.team['driver'] as Map<String, dynamic>?) ?? {};
    final foremanName = foreman['name'] as String? ?? 'Foreman';
    final leaderPic = foreman['profile_pic_url'] as String?;
    final teamName = widget.team['team_name'] as String? ?? 'Team';
    final accent = widget.accent;
    final pending = _pendingJobs.length;
    final done = _accomplishedJobs.length;
    final total = pending + done;
    final diff = _diffCounts;

    return Column(children: [
      // ── Hero header ──────────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withOpacity(0.78)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _HeroDotPainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Top row
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
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.groups_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 5),
                        Text('TEAM OVERVIEW',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2)),
                      ]),
                    ),
                    const Spacer(),

                    if (!_showOverall)
                      GestureDetector(
                        onTap: _pickMonthYear,
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.calendar_month_rounded,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 5),
                            Text(_monthLabel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_drop_down_rounded,
                                color: Colors.white, size: 14),
                          ]),
                        ),
                      ),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _dialogToggle('Monthly', !_showOverall,
                                () => setState(() => _showOverall = false)),
                        _dialogToggle('Overall', _showOverall,
                                () => setState(() => _showOverall = true)),
                      ]),
                    ),

                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _fetchJobs,
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 17),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _showOverall ? 'All-time data' : _monthLabel,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2.5),
                        color: Colors.white.withOpacity(0.18),
                      ),
                      child: ClipOval(
                        child: leaderPic != null
                            ? Image.network(leaderPic, fit: BoxFit.cover)
                            : Center(
                            child: Text(
                                foremanName[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22))),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(teamName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5)),
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.star_rounded,
                                    color: Colors.white.withOpacity(0.85),
                                    size: 12),
                                const SizedBox(width: 4),
                                Text(foremanName,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.88),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500)),
                              ]),
                            ])),
                    if (total > 0)
                      _LabeledMiniPie(
                          pending: pending, done: done, total: total),
                  ]),

                  const SizedBox(height: 16),

                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _heroChip(Icons.people_rounded,
                        '${members.length} member'
                            '${members.length == 1 ? '' : 's'}'),
                    _heroChip(Icons.pending_actions_rounded, '$pending pending'),
                    _heroChip(Icons.task_alt_rounded, '$done done'),
                  ]),
                ]),
          ),
        ]),
      ),

      // ── Difficulty breakdown strip ───────────────────────────────────────
      if (!_isLoading)
        Container(
          color: _tk.surf,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(children: [
            _DifficultyDonut(
                minor: diff.minor,
                moderate: diff.moderate,
                major: diff.major,
                tk: _tk),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Difficulty Breakdown',
                        style: TextStyle(
                            color: _tk.txtHead,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    _diffLegendRow('Minor', diff.minor,
                        const Color(0xFF06B6D4), const Color(0xFFECF9FC)),
                    const SizedBox(height: 6),
                    _diffLegendRow('Moderate', diff.moderate,
                        const Color(0xFFF59E0B), const Color(0xFFFEF3C7)),
                    const SizedBox(height: 6),
                    _diffLegendRow('Major', diff.major,
                        const Color(0xFFEF4444), const Color(0xFFFEE2E2)),
                  ]),
            ),
          ]),
        ),

      // ── Members strip ───────────────────────────────────────────────────
      if (members.isNotEmpty || driver.isNotEmpty)
        Container(
          color: _tk.surf,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Divider(height: 1, color: _tk.bd),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.people_rounded, size: 12, color: _tk.txtMuted),
              const SizedBox(width: 6),
              Text('MEMBERS',
                  style: TextStyle(
                      color: _tk.txtMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                if (driver.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF7C3AED).withOpacity(0.55),
                                width: 1.5),
                            color: _tk.surf2,
                          ),
                          child: ClipOval(
                            child: driver['profile_pic_url'] != null
                                ? Image.network(
                                driver['profile_pic_url'] as String,
                                fit: BoxFit.cover)
                                : Center(
                                child: Text(
                                    (driver['name'] as String? ?? '?')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: Color(0xFF7C3AED),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15))),
                          ),
                        ),
                        Positioned(
                          bottom: -3, right: -4,
                          child: Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED),
                              shape: BoxShape.circle,
                              border: Border.all(color: _tk.surf, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFF7C3AED).withOpacity(0.4),
                                    blurRadius: 4)
                              ],
                            ),
                            child: const Icon(Icons.drive_eta_rounded,
                                color: Colors.white, size: 10),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 54,
                        child: Text(driver['name'] as String? ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _tk.txt,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500)),
                      ),
                      const Text('Driver',
                          style: TextStyle(
                              color: Color(0xFF7C3AED),
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],

                ...members.map<Widget>((m) {
                  final name = m['name'] as String? ?? '—';
                  final pic = m['profile_pic_url'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: widget.accent.withOpacity(0.40),
                              width: 1.5),
                          color: _tk.surf2,
                        ),
                        child: ClipOval(
                          child: pic != null
                              ? Image.network(pic, fit: BoxFit.cover)
                              : Center(
                              child: Text(name[0].toUpperCase(),
                                  style: TextStyle(
                                      color: widget.accent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15))),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 54,
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _tk.txt,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500)),
                      ),
                      Text('Member',
                          style: TextStyle(
                              color: widget.accent.withOpacity(0.75),
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
              ]),
            ),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingJobs.length;
    final done = _accomplishedJobs.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 920),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Scaffold(
            backgroundColor: _tk.bg,
            // ── NestedScrollView: header scrolls away, tab bar stays pinned ──
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(child: _buildSliverHeader()),

                // ── Sticky tab bar ───────────────────────────────────────
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _tk.surf,
                        border: Border(top: BorderSide(color: _tk.bd, width: 1)),
                      ),
                      child: TabBar(
                        controller: _tab,
                        labelColor: widget.accent,
                        unselectedLabelColor: _tk.txtMuted,
                        indicatorColor: widget.accent,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5),
                        tabs: [
                          Tab(text: 'Pending ($pending)'),
                          Tab(text: 'Accomplished ($done)'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // ── Tab content ─────────────────────────────────────────────
              body: _isLoading
                  ? const DsLoading()
                  : TabBarView(
                controller: _tab,
                children: [
                  _buildJobList(_pendingJobs, isPending: true, accent: widget.accent),
                  _buildJobList(_accomplishedJobs, isPending: false, accent: widget.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _dialogToggle(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.28) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.white.withOpacity(0.55),
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

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
      Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _diffLegendRow(String label, int count, Color color, Color bg) =>
      Row(children: [
        Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: _tk.txtMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.28)),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]);

  Widget _buildJobList(List<Map<String, dynamic>> jobs,
      {required bool isPending, required Color accent}) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isPending
              ? Icons.pending_actions_rounded
              : Icons.task_alt_rounded,
              size: 64, color: _tk.bd2),
          const SizedBox(height: 16),
          Text(isPending ? 'No pending jobs' : 'No accomplished jobs',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _tk.txt)),
          const SizedBox(height: 6),
          Text(
              _showOverall
                  ? 'This team has no jobs here yet.'
                  : 'No jobs for $_monthLabel.',
              style: TextStyle(color: _tk.txtMuted, fontSize: 13)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: jobs.length,
      itemBuilder: (_, i) =>
          _buildJobCard(jobs[i], isPending: isPending, accent: accent),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job,
      {required bool isPending, required Color accent}) {
    final joNum = job['jo_number'] as String? ?? '—';
    final shiftTime = job['shift_time'] as String? ?? '—';
    final workName = job['work_type_name'] as String? ?? '—';
    final workCode = job['work_type_code'] as String? ?? '—';
    final damagedName = job['damaged_space_name'] as String? ?? '—';
    final address = job['address'] as String? ?? '—';
    final remarks = job['remarks'] as String?;
    final diffLevel = job['difficulty_level'] is int
        ? job['difficulty_level'] as int
        : int.tryParse(job['difficulty_level']?.toString() ?? '') ?? 2;
    final diffLabel = {1: 'Minor', 2: 'Moderate', 3: 'Major'}[diffLevel] ?? '—';
    final diffColor = {
      1: _tk.cyan,
      2: _tk.amber,
      3: _tk.red
    }[diffLevel] ?? _tk.amber;
    final isAcc = !isPending;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _tk.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _tk.bd),
        boxShadow: _tk.shadowSm,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [accent, accent.withOpacity(0.80)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                    color: accent.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(joNum,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          title: Text(workName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _tk.txtHead,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(children: [
              Text(shiftTime,
                  style: TextStyle(color: _tk.txtMuted, fontSize: 11.5)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: diffColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: diffColor.withOpacity(0.28)),
                ),
                child: Text(diffLabel,
                    style: TextStyle(
                        color: diffColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isAcc ? _tk.greenBg : _tk.amberBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isAcc
                      ? _tk.green.withOpacity(0.30)
                      : _tk.amber.withOpacity(0.30)),
            ),
            child: Text(isAcc ? 'Done' : 'Pending',
                style: TextStyle(
                    color: isAcc ? _tk.green : _tk.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Divider(color: _tk.bd, height: 1),
            const SizedBox(height: 12),
            _infoCard(accent: accent, children: [
              _detailRow(Icons.build_rounded, 'Work Type',
                  '$workCode – $workName'),
              _detailRow(Icons.foundation_rounded, 'Damaged Space', damagedName),
              _detailRow(Icons.location_on_rounded, 'Address', address),
              _detailRow(Icons.speed_rounded, 'Difficulty', diffLabel,
                  valueColor: diffColor),
              if (remarks != null && remarks.trim().isNotEmpty)
                _detailRow(Icons.notes_rounded, 'Remarks', remarks),
              _detailRow(Icons.calendar_today_rounded, 'Created',
                  _fmt(job['created_at'])),
              if (isAcc)
                _detailRow(Icons.check_circle_rounded, 'Completed',
                    _fmt(job['completed_at']),
                    valueColor: _tk.green),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({required Color accent, required List<Widget> children}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _tk.surf2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _tk.bd),
        ),
        child: Column(children: children),
      );

  Widget _detailRow(IconData icon, String label, String value,
      {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: _tk.txtMuted),
          const SizedBox(width: 9),
          SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(color: _tk.txtMuted, fontSize: 12.5))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: valueColor ?? _tk.txtHead,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600))),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sticky tab bar delegate
// ─────────────────────────────────────────────────────────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyTabBarDelegate({required this.child});

  // TabBar intrinsic height — no separator added to layout
  @override double get minExtent => kTextTabBarHeight;
  @override double get maxExtent => kTextTabBarHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) => old.child != child;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Labeled mini pie
// ─────────────────────────────────────────────────────────────────────────────
class _LabeledMiniPie extends StatelessWidget {
  final int pending, done, total;
  const _LabeledMiniPie(
      {required this.pending, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _legendItem(const Color(0xFF059669), 'Accomplished'),
        const SizedBox(height: 6),
        _legendItem(const Color(0xFFD97706), 'Pending'),
      ]),
      const SizedBox(width: 10),
      SizedBox(
        width: 68, height: 68,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 20,
            startDegreeOffset: -90,
            sections: [
              PieChartSectionData(
                  value: done.toDouble(),
                  color: const Color(0xFF059669),
                  radius: 24, title: '', showTitle: false),
              PieChartSectionData(
                  value: pending.toDouble(),
                  color: const Color(0xFFD97706),
                  radius: 24, title: '', showTitle: false),
            ],
          )),
          Text('$total',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ]),
      ),
    ]);
  }

  Widget _legendItem(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Difficulty donut
// ─────────────────────────────────────────────────────────────────────────────
class _DifficultyDonut extends StatelessWidget {
  final int minor, moderate, major;
  final Tk tk;
  const _DifficultyDonut(
      {required this.minor,
        required this.moderate,
        required this.major,
        required this.tk});

  @override
  Widget build(BuildContext context) {
    final total = minor + moderate + major;
    const cyan = Color(0xFF06B6D4);
    const amber = Color(0xFFF59E0B);
    const red = Color(0xFFEF4444);
    const grey = Color(0xFFE5E7EB);

    return SizedBox(
      width: 80, height: 80,
      child: Stack(alignment: Alignment.center, children: [
        PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 24,
          startDegreeOffset: -90,
          sections: total == 0
              ? [
            PieChartSectionData(
                value: 1, color: grey, radius: 20, title: '', showTitle: false),
          ]
              : [
            if (minor > 0)
              PieChartSectionData(
                  value: minor.toDouble(), color: cyan,
                  radius: 20, title: '', showTitle: false),
            if (moderate > 0)
              PieChartSectionData(
                  value: moderate.toDouble(), color: amber,
                  radius: 20, title: '', showTitle: false),
            if (major > 0)
              PieChartSectionData(
                  value: major.toDouble(), color: red,
                  radius: 20, title: '', showTitle: false),
          ],
        )),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$total',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: tk.txtHead)),
          Text('jobs',
              style: TextStyle(
                  fontSize: 9,
                  color: tk.txtMuted,
                  fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dot painters
// ─────────────────────────────────────────────────────────────────────────────
class _HeroDotPainter extends CustomPainter {
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
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.2), 56, ring);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.85), 80, ring);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CardDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}