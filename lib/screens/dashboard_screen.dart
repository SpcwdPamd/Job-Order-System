import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/data/admin_data.dart';

// Yung mga period options para sa trend chart — Days, Weeks, Months, Year
enum ChartPeriod { days, weeks, months, year }

//color pallette
const _cBlue   = Color(0xFF1D6FE8);
const _cBlue2  = Color(0xFF3B82F6);
const _cCyan   = Color(0xFF0891B2);
const _cGreen  = Color(0xFF059669);
const _cAmber  = Color(0xFFD97706);
const _cViolet = Color(0xFF7C3AED);
const _cPink   = Color(0xFFDB2777);
const _cRed    = Color(0xFFDC2626);
// Itong palette na ito ginagamit ko sa mga chart na maraming categories
const _chartPalette = [_cBlue, _cCyan, _cGreen, _cAmber, _cViolet, _cPink, _cRed, _cBlue2];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // Shortcut para sa theme tokens — hindi ko na kailangan i-type ng buo every time
  Tk get _tk => context.tk;

  // Loading state at yung mga counter ng pending at accomplished jobs
  bool _isLoading = true;
  int  _pending = 0, _accomplished = 0;

  // Kung anong period ang naka-select sa trend chart
  ChartPeriod _trendPeriod = ChartPeriod.days;

  // Yung mga data list para sa bawat chart section
  List<Map<String, dynamic>> _trendData  = [];
  List<Map<String, dynamic>> _comboData  = [];
  List<Map<String, dynamic>> _addressG1  = [];
  List<Map<String, dynamic>> _addressG2  = [];
  List<Map<String, dynamic>> _addressG3  = [];
  List<Map<String, dynamic>> _addressG4  = [];

  // Work distribution — hindi kasama yung Restoration (203) dito, hiwalay kasi siya
  Map<String, int> _workDist       = {};
  // Lahat ng damage para sa combo chart
  Map<String, int> _damageDist     = {};
  // Damage distribution pero para lang sa Restoration jobs
  Map<String, int> _restDamageDist = {};
  int              _restTotal      = 0;

  // Lahat ng jobs — ginagamit ko ito para sa filtering
  List<dynamic>   _allJobs         = [];

  // Hover indices para sa bawat chart — iba-iba para hindi mag-interfere
  int? _hovPie;       // Para sa work type pie ONLY
  int? _hovPieDmg;    // Hiwalay para sa damaged space pie
  int? _hovPieRest;   // Hiwalay para sa restoration pie
  int? _hovTrend;
  int? _hovCombo;
  int? _hovAddr;
  int? _hovSurfAddr;

  // Surface → address breakdown — A=Concrete, B=Sidewalk, C=Earth
  Map<String, List<Map<String, dynamic>>> _surfaceAddrData = {
    'A': [], 'B': [], 'C': [],
  };
  // Default na selected surface — Concrete/Asphalt muna
  String _selectedSurface = 'A';

  // ── Filter state — null = lahat ng records (overall) ─────────────────────
  int? _filterYear;   // null = overall (all time)
  int? _filterMonth;  // null = buong taon, 1-12 = specific month
  List<dynamic> _filteredJobs = [];

  // Para sa entrance animation ng dashboard
  late final AnimationController _entryCtrl;
  late final Animation<double>   _entryAnim;

  // Kukunin ko ang dynamic lists mula sa admin notifiers na Supabase-backed
  List<Map<String, String>> get workTypes => workTypesNotifier.items
      .map((e) => {'code': e.code, 'name': e.name}).toList();
  List<Map<String, String>> get damagedOptions => damageSpacesNotifier.items
      .map((e) => {'code': e.code, 'name': e.name}).toList();

  // Hard-coded colors para sa work types — mas maganda kesa random palette
  final _workColors = <String, Color>{
    'Service Lines/Fittings': _cBlue,
    'Meter Stand': _cGreen,
    'Distribution/Transmission Lines': _cViolet,
    'Appurtenances (Gate valve, ARV, etc.)': _cAmber,
    'Flushing': _cCyan,
    'Valving': _cRed,
    'Relocation': _cPink,
  };

  // Kulay para sa damaged space options — specific lang kasi apat lang naman sila
  final _damageColors = <String, Color>{
    'Concrete/Asphalt': _cBlue,
    'Sidewalk/Gutter': _cCyan,
    'Earth': _cAmber,
    'None/Others': Color(0xFF94A3B8),
  };

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    themeNotifier.addListener(_onThemeChange);
    _load();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() { if (mounted) setState(() {}); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final sb = Supabase.instance.client;

      final pendRes = await sb.from('job_orders').select('id').eq('status', 'pending').count();
      if (!mounted) return;

      final skelPendRes = await sb.from('skeletal_job').select('id').eq('status', 'pending').count();
      if (!mounted) return;
      _pending = (pendRes.count ?? 0) + (skelPendRes.count ?? 0);

      final accRes = await sb
          .from('job_orders')
          .select('completed_at, work_type_code, work_type_name, damaged_space_code, damaged_space_name, address')
          .eq('status', 'accomplished')
          .not('completed_at', 'is', null)
          .order('completed_at', ascending: true);
      if (!mounted) return;

      final skelAccRes = await sb
          .from('skeletal_job')
          .select('completed_at, work_type_code, work_type_name, damaged_space_code, damaged_space_name, address')
          .eq('status', 'completed')
          .not('completed_at', 'is', null)
          .order('completed_at', ascending: true);
      if (!mounted) return;

      final mergedAcc = [
        ...List<Map<String, dynamic>>.from(accRes),
        ...List<Map<String, dynamic>>.from(skelAccRes),
      ]..sort((a, b) {
        final at = a['completed_at'] as String? ?? '';
        final bt = b['completed_at'] as String? ?? '';
        return at.compareTo(bt);
      });
      _accomplished = mergedAcc.length;
      _allJobs = mergedAcc;

      final Map<String, int> wMap = {}, dMap = {}, rdMap = {},
          ag1 = {}, ag2 = {}, ag3 = {}, ag4 = {};
      int restCount = 0;

      for (final j in accRes) {
        final wc = j['work_type_code'] as String? ?? '301';
        final wn = j['work_type_name'] as String? ?? 'Relocation';
        final dn = j['damaged_space_name'] as String? ?? 'None/Others';
        final addr = (j['address'] as String?)?.trim() ?? 'Unknown';

        if (wc == '203') {
          restCount++;
          rdMap.update(dn, (v) => v + 1, ifAbsent: () => 1);
        } else {
          wMap.update(wn, (v) => v + 1, ifAbsent: () => 1);
        }
        dMap.update(dn, (v) => v + 1, ifAbsent: () => 1);

        if (['101','102','103','104'].contains(wc)) ag1.update(addr, (v) => v+1, ifAbsent: () => 1);
        else if (wc == '201') ag2.update(addr, (v) => v+1, ifAbsent: () => 1);
        else if (wc == '202') ag3.update(addr, (v) => v+1, ifAbsent: () => 1);
        else if (wc == '203') ag4.update(addr, (v) => v+1, ifAbsent: () => 1);
      }

      void proc(Map<String, int> src, List<Map<String, dynamic>> dest) {
        final sorted = src.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        if (!mounted) return;
        setState(() { dest.clear(); dest.addAll(sorted.map((e) => {'label': e.key, 'value': e.value.toDouble()})); });
      }
      proc(ag1, _addressG1); proc(ag2, _addressG2); proc(ag3, _addressG3); proc(ag4, _addressG4);

      _filteredJobs = List.from(accRes);
      _applyFilter();
      if (!mounted) return;
      setState(() {
        _workDist = wMap;
        _damageDist = dMap;
        _restDamageDist = rdMap;
        _restTotal = restCount;
        _isLoading = false;
      });
      _entryCtrl.forward(from: 0);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _cRed),
        );
      }
    }
  }

  void _updateTrend(List<dynamic> jobs) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> trend = [];

    if (_trendPeriod == ChartPeriod.days) {
      final Map<String, int> dc = {};
      for (int i = 13; i >= 0; i--) {
        dc[DateFormat('MMM d').format(now.subtract(Duration(days: i)))] = 0;
      }
      for (final r in jobs) {
        final s = r['completed_at'] as String?; if (s == null) continue;
        final dt = DateTime.parse(s).toLocal();
        if (dt.isBefore(now.subtract(const Duration(days: 13)))) continue;
        dc.update(DateFormat('MMM d').format(dt), (v) => v + 1, ifAbsent: () => 1);
      }
      trend.addAll(dc.entries.map((e) => {'label': e.key, 'value': e.value.toDouble()}));
    } else if (_trendPeriod == ChartPeriod.weeks) {
      final days = DateTime(now.year, now.month + 1, 0).day;
      final Map<String, int> wc = {};
      for (int w = 1; w <= (days / 7).ceil(); w++) wc['Wk $w'] = 0;
      for (final r in jobs) {
        final s = r['completed_at'] as String?; if (s == null) continue;
        final dt = DateTime.parse(s).toLocal();
        if (dt.year != now.year || dt.month != now.month) continue;
        wc.update('Wk ${((dt.day - 1) ~/ 7) + 1}', (v) => v + 1, ifAbsent: () => 1);
      }
      trend.addAll(wc.entries.map((e) => {'label': e.key, 'value': e.value.toDouble()}));
    } else if (_trendPeriod == ChartPeriod.months) {
      final Map<String, int> mc = {};
      for (int m = 1; m <= 12; m++) mc[DateFormat('MMM').format(DateTime(now.year, m))] = 0;
      for (final r in jobs) {
        final s = r['completed_at'] as String?; if (s == null) continue;
        final dt = DateTime.parse(s).toLocal(); if (dt.year != now.year) continue;
        mc.update(DateFormat('MMM').format(dt), (v) => v + 1, ifAbsent: () => 1);
      }
      trend.addAll(mc.entries.map((e) => {'label': e.key, 'value': e.value.toDouble()}));
    } else {
      final Map<String, int> yc = {};
      for (final y in [2026, 2027, 2028, 2029, 2030]) yc[y.toString()] = 0;
      for (final r in jobs) {
        final s = r['completed_at'] as String?; if (s == null) continue;
        final yr = DateTime.parse(s).toLocal().year.toString();
        if (yc.containsKey(yr)) yc.update(yr, (v) => v + 1);
      }
      trend.addAll(yc.entries.map((e) => {'label': e.key, 'value': e.value.toDouble()}));
    }
    if (mounted) setState(() => _trendData = trend);
  }

  void _updateCombo(List<dynamic> jobs) {
    final Map<String, int> cm = {};
    for (final j in jobs) {
      final wc = j['work_type_code'] as String? ?? '301';
      final dc = j['damaged_space_code'] as String? ?? 'D';
      cm.update('$dc$wc', (v) => v + 1, ifAbsent: () => 1);
    }
    final sorted = cm.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (mounted) setState(() => _comboData = sorted.take(10)
        .map<Map<String, dynamic>>((e) => {'label': e.key, 'value': e.value.toDouble()}).toList());
  }

  void _applyFilter() {
    List<dynamic> jobs;

    if (_filterYear == null) {
      jobs = List.from(_allJobs);
    } else if (_filterMonth == null) {
      jobs = _allJobs.where((j) {
        final s = j['completed_at'] as String?; if (s == null) return false;
        return DateTime.parse(s).toLocal().year == _filterYear;
      }).toList();
    } else {
      jobs = _allJobs.where((j) {
        final s = j['completed_at'] as String?; if (s == null) return false;
        final dt = DateTime.parse(s).toLocal();
        return dt.year == _filterYear && dt.month == _filterMonth;
      }).toList();
    }
    _filteredJobs = jobs;

    final Map<String, int> wMap = {}, dMap = {}, rdMap = {},
        ag1 = {}, ag2 = {}, ag3 = {}, ag4 = {};
    int restCount = 0;

    for (final j in jobs) {
      final wc = j['work_type_code'] as String? ?? '301';
      final wn = j['work_type_name'] as String? ?? 'Relocation';
      final dn = j['damaged_space_name'] as String? ?? 'None/Others';
      final addr = (j['address'] as String?)?.trim() ?? 'Unknown';

      if (wc == '203') {
        restCount++;
        rdMap.update(dn, (v) => v + 1, ifAbsent: () => 1);
      } else {
        wMap.update(wn, (v) => v + 1, ifAbsent: () => 1);
      }
      dMap.update(dn, (v) => v + 1, ifAbsent: () => 1);

      if (['101','102','103','104'].contains(wc)) ag1.update(addr, (v) => v+1, ifAbsent: () => 1);
      else if (wc == '201') ag2.update(addr, (v) => v+1, ifAbsent: () => 1);
      else if (wc == '202') ag3.update(addr, (v) => v+1, ifAbsent: () => 1);
      else if (wc == '203') ag4.update(addr, (v) => v+1, ifAbsent: () => 1);
    }

    void proc(Map<String, int> src, List<Map<String, dynamic>> dest) {
      final sorted = src.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      dest.clear();
      dest.addAll(sorted.map((e) => {'label': e.key, 'value': e.value.toDouble()}));
    }
    proc(ag1, _addressG1); proc(ag2, _addressG2); proc(ag3, _addressG3); proc(ag4, _addressG4);

    final Map<String, Map<String, int>> surfAddr = {'A': {}, 'B': {}, 'C': {}};
    for (final j in jobs) {
      final dc = j['damaged_space_code'] as String? ?? 'D';
      final addr = (j['address'] as String?)?.trim() ?? 'Unknown';
      if (surfAddr.containsKey(dc)) {
        surfAddr[dc]!.update(addr, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final newSurfData = <String, List<Map<String, dynamic>>>{};
    for (final entry in surfAddr.entries) {
      final sorted2 = entry.value.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      newSurfData[entry.key] = sorted2.map((e) => {'label': e.key, 'value': e.value.toDouble()}).toList();
    }

    if (mounted) setState(() {
      _accomplished = jobs.length;
      _workDist = wMap;
      _damageDist = dMap;
      _restDamageDist = rdMap;
      _restTotal = restCount;
      _surfaceAddrData = newSurfData;
    });
    _updateTrend(jobs);
    _updateCombo(jobs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tk.bg,
      body: _isLoading
          ? _loadingView()
          : Column(children: [
        _topHero(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: _cBlue,
            backgroundColor: _tk.surf,
            child: FadeTransition(
              opacity: _entryAnim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(_entryAnim),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statsRow(),
                          const SizedBox(height: 24),
                          _trendCard(),
                          const SizedBox(height: 20),
                          _pieRow(),
                          const SizedBox(height: 20),
                          _comboCard(),
                          const SizedBox(height: 20),
                          _surfaceAddressCard(),
                          const SizedBox(height: 20),
                          _addressSection(),
                        ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _loadingView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 2.5, color: _cBlue)),
    const SizedBox(height: 20),
    Text('Loading dashboard…', style: TextStyle(color: _tk.txtMuted, fontSize: 14, fontWeight: FontWeight.w500)),
  ]));

  Widget _topHero() {
    final now = DateFormat('EEE, MMM d y').format(DateTime.now());
    final isDark = _tk.dark;
    final nowDt = DateTime.now();
    final filterLabel = _filterYear == null
        ? 'Overall'
        : _filterMonth != null
        ? DateFormat('MMM yyyy').format(DateTime(_filterYear!, _filterMonth!))
        : DateFormat('MMM yyyy').format(nowDt);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1220) : Colors.white,
        border: Border(bottom: BorderSide(color: _tk.bd, width: 1)),
        boxShadow: isDark
            ? [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4)),
          BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 4)),
        ]
            : [
          BoxShadow(color: _cBlue.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]
                        : [const Color(0xFF1D6FE8), const Color(0xFF1554C4)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [BoxShadow(color: _cBlue.withOpacity(isDark ? 0.5 : 0.3), blurRadius: isDark ? 16 : 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text('Operations Dashboard', style: TextStyle(
                    color: _tk.txtHead, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F2040) : _cBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _cBlue.withOpacity(isDark ? 0.4 : 0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 5, height: 5, margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF22D3EE) : const Color(0xFF059669),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: (isDark ? const Color(0xFF22D3EE) : const Color(0xFF059669)).withOpacity(0.6),
                          blurRadius: 4,
                        )],
                      ),
                    ),
                    Text('Live', style: TextStyle(
                      color: isDark ? const Color(0xFF60A5FA) : _cBlue,
                      fontSize: 10.5, fontWeight: FontWeight.w700,
                    )),
                  ]),
                ),
                const Spacer(),
                Text(now, style: TextStyle(color: _tk.txtMuted, fontSize: 11.5)),
              ])),
              const SizedBox(width: 12),
              _DarkModeToggle(isDark: isDark, onToggle: () => themeNotifier.toggle()),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _load,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _tk.blueBg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _tk.blueBd),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, color: _tk.blue, size: 15),
                    const SizedBox(width: 6),
                    Text('Refresh', style: TextStyle(color: _tk.blue, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0C1E3D) : const Color(0xFFEBF3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF1A3869) : const Color(0xFFBDD6FF)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.filter_list_rounded, size: 13, color: isDark ? const Color(0xFF60A5FA) : _cBlue),
                  const SizedBox(width: 5),
                  Text('Showing: ', style: TextStyle(color: _tk.txtMuted, fontSize: 11.5)),
                  Text(filterLabel, style: TextStyle(
                    color: isDark ? const Color(0xFF60A5FA) : _cBlue,
                    fontSize: 11.5, fontWeight: FontWeight.w700,
                  )),
                ]),
              ),
              const SizedBox(width: 10),
              _FilterChip(
                label: 'Overall',
                isSelected: _filterYear == null,
                isDark: isDark,
                icon: Icons.public_rounded,
                accent: _cBlue,
                onTap: () {
                  setState(() { _filterYear = null; _filterMonth = null; });
                  _applyFilter();
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: (() {
                  final now2 = DateTime.now();
                  return DateFormat('MMM yyyy').format(now2);
                })(),
                isSelected: (() {
                  final now2 = DateTime.now();
                  return _filterYear == now2.year && _filterMonth == now2.month;
                })(),
                isDark: isDark,
                icon: Icons.today_rounded,
                accent: _cViolet,
                onTap: () {
                  final now2 = DateTime.now();
                  setState(() { _filterYear = now2.year; _filterMonth = now2.month; });
                  _applyFilter();
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: (_filterYear != null && _filterMonth != null &&
                    !(_filterMonth == DateTime.now().month && _filterYear == DateTime.now().year))
                    ? '${DateFormat('MMM').format(DateTime(_filterYear!, _filterMonth!))} $_filterYear'
                    : 'Pick Month',
                isSelected: (_filterYear != null && _filterMonth != null &&
                    !(_filterMonth == DateTime.now().month && _filterYear == DateTime.now().year)),
                isDark: isDark,
                icon: Icons.calendar_today_rounded,
                accent: _cGreen,
                onTap: () => _showMonthYearPicker(),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showMonthYearPicker() {
    final isDark = _tk.dark;
    final currentYear = DateTime.now().year;
    int selectedYear  = _filterYear ?? currentYear;
    int selectedMonth = _filterMonth ?? DateTime.now().month;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final surfColor  = isDark ? const Color(0xFF101827) : Colors.white;
          final surf2Color = isDark ? const Color(0xFF161F30) : const Color(0xFFF7FAFD);
          final bdColor    = isDark ? const Color(0xFF1E2E47) : const Color(0xFFDDE6F0);
          final txtHead    = isDark ? const Color(0xFFEDF2FF) : const Color(0xFF0D1F3C);
          final txtMuted   = isDark ? const Color(0xFF475F7E) : const Color(0xFF7A93B4);
          final txtNorm    = isDark ? const Color(0xFFAFC4DE) : const Color(0xFF2D4263);

          return Dialog(
            backgroundColor: surfColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            elevation: 24,
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_cGreen, Color(0xFF047857)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [BoxShadow(color: _cGreen.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Pick Month & Year', style: TextStyle(color: txtHead, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('Filter dashboard data', style: TextStyle(color: txtMuted, fontSize: 11.5)),
                  ])),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: bdColor, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close_rounded, color: txtMuted, size: 16),
                    ),
                  ),
                ]),
                const SizedBox(height: 22),
                Text('YEAR', style: TextStyle(color: txtMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: surf2Color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: bdColor),
                  ),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => setModal(() => selectedYear--),
                      child: Container(
                        width: 44, height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(11),
                            bottomLeft: Radius.circular(11),
                          ),
                        ),
                        child: Center(child: Icon(
                          Icons.chevron_left_rounded,
                          color: selectedYear > 2026 ? _cBlue : bdColor,
                          size: 22,
                        )),
                      ),
                    ),
                    Container(width: 1, height: 28, color: bdColor),
                    Expanded(child: Center(child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        '$selectedYear',
                        key: ValueKey(selectedYear),
                        style: TextStyle(
                          color: txtHead,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ))),
                    Container(width: 1, height: 28, color: bdColor),
                    GestureDetector(
                      onTap: () => setModal(() => selectedYear++),
                      child: Container(
                        width: 44, height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(11),
                            bottomRight: Radius.circular(11),
                          ),
                        ),
                        child: Center(child: Icon(Icons.chevron_right_rounded, color: _cBlue, size: 22)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                Text('MONTH', style: TextStyle(color: txtMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.1,
                  children: List.generate(12, (i) {
                    final month  = i + 1;
                    final label  = DateFormat('MMM').format(DateTime(2000, month));
                    final isSel  = month == selectedMonth;
                    return GestureDetector(
                      onTap: () => setModal(() => selectedMonth = month),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        decoration: BoxDecoration(
                          gradient: isSel
                              ? const LinearGradient(
                            colors: [_cGreen, Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : null,
                          color: isSel ? null : surf2Color,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: isSel ? _cGreen : bdColor, width: isSel ? 0 : 1),
                          boxShadow: isSel
                              ? [BoxShadow(color: _cGreen.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Center(child: Text(
                          label,
                          style: TextStyle(
                            color: isSel ? Colors.white : txtNorm,
                            fontSize: 12.5,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          ),
                        )),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: surf2Color,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: bdColor),
                      ),
                      child: Center(child: Text(
                        'Cancel',
                        style: TextStyle(color: txtNorm, fontSize: 13.5, fontWeight: FontWeight.w600),
                      )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() { _filterYear = selectedYear; _filterMonth = selectedMonth; });
                      _applyFilter();
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_cGreen, Color(0xFF047857)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [BoxShadow(color: _cGreen.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4))],
                      ),
                      child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Apply Filter',
                          style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                      ])),
                    ),
                  )),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _statsRow() {
    final total = _accomplished + _pending;
    final rate  = total == 0 ? 0 : ((_accomplished / total) * 100).round();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(children: [
        Expanded(child: _statCard('Pending',      _pending,      Icons.schedule_rounded,    _cAmber, 'Awaiting action', index: 0)),
        const SizedBox(width: 14),
        Expanded(child: _statCard('Accomplished', _accomplished, Icons.task_alt_rounded,    _cGreen, 'Completed',       index: 1)),
        const SizedBox(width: 14),
        Expanded(child: _statCard('Rate',         rate,          Icons.donut_large_rounded, _cBlue,  'Completion %',    index: 2, suffix: '%')),
      ]),
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color accent, String sub,
      {String suffix = '', required int index}) {
    final isDark = _tk.dark;
    final glowColors = [_cAmber, _cGreen, _cBlue];
    final glow = glowColors[index];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? Color.lerp(_tk.surf, glow, 0.04)! : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? glow.withOpacity(0.45) : glow.withOpacity(0.22),
          width: isDark ? 1.5 : 1.2,
        ),
        boxShadow: isDark
            ? [
          BoxShadow(color: glow.withOpacity(0.28), blurRadius: 22, spreadRadius: 0, offset: const Offset(0, 4)),
          BoxShadow(color: glow.withOpacity(0.12), blurRadius: 40, spreadRadius: 4, offset: const Offset(0, 0)),
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
        ]
            : [
          BoxShadow(color: glow.withOpacity(0.18), blurRadius: 16, spreadRadius: -2, offset: const Offset(0, 4)),
          BoxShadow(color: glow.withOpacity(0.10), blurRadius: 30, spreadRadius: 0, offset: const Offset(0, 0)),
          BoxShadow(color: const Color(0xFF0D1F3C).withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: isDark ? glow.withOpacity(0.15) : glow.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: glow.withOpacity(isDark ? 0.4 : 0.2)),
              boxShadow: isDark ? [BoxShadow(color: glow.withOpacity(0.3), blurRadius: 12)] : null,
            ),
            child: Icon(icon, color: glow, size: 20),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 28, height: 3,
              decoration: BoxDecoration(
                color: glow.withOpacity(isDark ? 0.7 : 0.3),
                borderRadius: BorderRadius.circular(2),
                boxShadow: isDark ? [BoxShadow(color: glow.withOpacity(0.5), blurRadius: 6)] : null,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 18, height: 3,
              decoration: BoxDecoration(
                color: glow.withOpacity(isDark ? 0.4 : 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ]),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '$value',
            style: TextStyle(
              color: _tk.txtHead,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          if (suffix.isNotEmpty) Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 2),
            child: Text(suffix, style: TextStyle(color: glow, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 5),
        Text(title, style: TextStyle(color: _tk.txtHead, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Row(children: [
          Container(
            width: 6, height: 6, margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: glow, shape: BoxShape.circle,
              boxShadow: isDark ? [BoxShadow(color: glow.withOpacity(0.6), blurRadius: 4)] : null,
            ),
          ),
          Text(sub, style: TextStyle(color: _tk.txtMuted, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _cardShell({required String title, required String sub, required Widget child,
    double? height, List<Widget> actions = const []}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _tk.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _tk.bd),
        boxShadow: _tk.shadowSm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 16, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: _tk.txtHead, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(color: _tk.txtMuted, fontSize: 11.5)),
            ])),
            ...actions,
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(child: child),
      ]),
    );
  }

  Widget _trendCard() {
    final String sub;
    switch (_trendPeriod) {
      case ChartPeriod.days:   sub = 'Last 14 days'; break;
      case ChartPeriod.weeks:  sub = 'Current month by week'; break;
      case ChartPeriod.months: sub = 'Current year by month'; break;
      case ChartPeriod.year:   sub = '2026 – 2030'; break;
    }
    final maxY = _trendData.isEmpty ? 10.0
        : (_trendData.map((e) => e['value'] as double).reduce(math.max) + 3).ceilToDouble();
    final tabs = [
      ['Days', ChartPeriod.days],
      ['Weeks', ChartPeriod.weeks],
      ['Months', ChartPeriod.months],
      ['Year', ChartPeriod.year],
    ];
    return SizedBox(
      height: 360,
      child: _cardShell(
        title: 'Job Order Accomplishment ', sub: sub,
        actions: [
          Container(
            decoration: BoxDecoration(
              color: _tk.surf2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _tk.bd),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: tabs.map((t) {
              final sel = _trendPeriod == t[1];
              return GestureDetector(
                onTap: () {
                  setState(() => _trendPeriod = t[1] as ChartPeriod);
                  _updateTrend(_allJobs);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? _cBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    t[0] as String,
                    style: TextStyle(
                      color: sel ? Colors.white : _tk.txtMuted,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList()),
          ),
          const SizedBox(width: 6),
        ],
        child: _trendData.isEmpty ? _emptyState('No data yet') : Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 20, 16),
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barGroups: _trendData.asMap().entries.map((e) {
              final isHov = _hovTrend == e.key;
              return BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: e.value['value'],
                  width: isHov ? 22 : 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: LinearGradient(
                    colors: [_cBlue, _cBlue.withOpacity(0.4)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ]);
            }).toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _trendData.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_trendData[i]['label'], style: TextStyle(color: _tk.txtMuted, fontSize: 9.5)),
                  );
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(color: _tk.txtMuted, fontSize: 9.5)),
              )),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: _tk.bd, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => _tk.surf,
                getTooltipItem: (grp, gi, rod, _) => BarTooltipItem(
                  '${_trendData[gi]['label']}\n',
                  TextStyle(color: _tk.txtMuted, fontSize: 11),
                  children: [TextSpan(
                    text: rod.toY.toInt().toString(),
                    style: TextStyle(color: _tk.txtHead, fontSize: 18, fontWeight: FontWeight.w800),
                  )],
                ),
              ),
              touchCallback: (event, res) {
                if (!mounted) return;
                setState(() => _hovTrend = (event is FlPointerHoverEvent || event is FlTapUpEvent)
                    ? res?.spot?.touchedBarGroupIndex : null);
              },
            ),
          )),
        ),
      ),
    );
  }

  Widget _pieRow() {
    return LayoutBuilder(builder: (_, c) {
      final wide = c.maxWidth > 700;
      if (!wide) {
        return Column(children: [
          _workPieCard(),
          const SizedBox(height: 16),
          _damageSpacePieCard(),
          const SizedBox(height: 16),
          _restPieCard(),
        ]);
      }
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _workPieCard()),
          const SizedBox(width: 16),
          Expanded(child: Column(children: [
            _damageSpacePieCard(),
            const SizedBox(height: 16),
            Expanded(child: _restPieCard()),
          ])),
        ]),
      );
    });
  }

  Widget _damageSpacePieCard() {
    final total   = _damageDist.values.fold(0, (a, b) => a + b);
    final entries = _damageDist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _tk.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _tk.bd),
        boxShadow: _tk.shadowSm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Damaged Space Distribution',
          style: TextStyle(color: _tk.txtHead, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text('All accomplished jobs', style: TextStyle(color: _tk.txtMuted, fontSize: 11)),
        const SizedBox(height: 14),
        if (_damageDist.isEmpty) _emptyState('No data yet') else ...[
          SizedBox(
            height: 160,
            child: PieChart(PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 28,
              sections: entries.asMap().entries.map((e) {
                final isHov = _hovPieDmg == e.key;
                final name  = e.value.key;
                final count = e.value.value;
                final pct   = total > 0 ? count / total * 100 : 0.0;
                final color = _damageColors[name] ?? _chartPalette[e.key % _chartPalette.length];
                return PieChartSectionData(
                  value: count.toDouble(),
                  color: color,
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: isHov ? 76 : 64,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
              pieTouchData: PieTouchData(touchCallback: (ev, res) {
                if (!mounted) return;
                setState(() => _hovPieDmg = (ev is FlPointerHoverEvent || ev is FlTapUpEvent)
                    ? res?.touchedSection?.touchedSectionIndex
                    : null);
              }),
            )),
          ),
          const SizedBox(height: 12),
          ...entries.asMap().entries.map((e) {
            final isHov = _hovPieDmg == e.key;
            final name  = e.value.key;
            final count = e.value.value;
            final pct   = total > 0 ? count / total * 100 : 0.0;
            final color = _damageColors[name] ?? _chartPalette[e.key % _chartPalette.length];
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 7),
              padding: EdgeInsets.symmetric(
                horizontal: isHov ? 8 : 0,
                vertical: isHov ? 5 : 0,
              ),
              decoration: BoxDecoration(
                color: isHov ? color.withOpacity(0.06) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isHov ? Border.all(color: color.withOpacity(0.2)) : null,
              ),
              child: Row(children: [
                Container(
                  width: 9, height: 9,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  name,
                  style: TextStyle(
                    color: _tk.txt,
                    fontSize: 11.5,
                    fontWeight: isHov ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: 6),
                Text('$count', style: TextStyle(color: _tk.txtHead, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  Widget _restPieCard() {
    final total   = _restDamageDist.values.fold(0, (a, b) => a + b);
    final entries = _restDamageDist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    const accent  = Color(0xFF7C3AED);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _tk.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _tk.bd),
        boxShadow: _tk.shadowSm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Restoration Surface Breakdown',
              style: TextStyle(color: _tk.txtHead, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text('Damage types for code 203', style: TextStyle(color: _tk.txtMuted, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'Restoration = ',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                '$_restTotal',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        if (_restDamageDist.isEmpty) _emptyState('No restoration data') else ...[
          SizedBox(height: 160, child: Stack(alignment: Alignment.center, children: [
            PieChart(PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 38,
              sections: entries.asMap().entries.map((e) {
                final isHov = _hovPieRest == e.key;
                final name  = e.value.key;
                final count = e.value.value;
                final pct   = total > 0 ? count / total * 100 : 0.0;
                final color = _damageColors[name] ?? _chartPalette[e.key % _chartPalette.length];
                return PieChartSectionData(
                  value: count.toDouble(),
                  color: color,
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: isHov ? 72 : 60,
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                );
              }).toList(),
              pieTouchData: PieTouchData(touchCallback: (ev, res) {
                if (!mounted) return;
                setState(() => _hovPieRest = (ev is FlPointerHoverEvent || ev is FlTapUpEvent)
                    ? res?.touchedSection?.touchedSectionIndex
                    : null);
              }),
            )),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '$total',
                style: const TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1),
              ),
              Text('jobs', style: TextStyle(color: _tk.txtMuted, fontSize: 9.5, fontWeight: FontWeight.w500)),
            ]),
          ])),
          const SizedBox(height: 12),
          ...entries.asMap().entries.map((e) {
            final isHov = _hovPieRest == e.key;
            final name  = e.value.key;
            final count = e.value.value;
            final pct   = total > 0 ? count / total * 100 : 0.0;
            final color = _damageColors[name] ?? _chartPalette[e.key % _chartPalette.length];
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 7),
              padding: EdgeInsets.symmetric(horizontal: isHov ? 8 : 0, vertical: isHov ? 5 : 0),
              decoration: BoxDecoration(
                color: isHov ? color.withOpacity(0.06) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isHov ? Border.all(color: color.withOpacity(0.2)) : null,
              ),
              child: Row(children: [
                Container(
                  width: 9, height: 9,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  name,
                  style: TextStyle(color: _tk.txt, fontSize: 11.5, fontWeight: isHov ? FontWeight.w700 : FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: 6),
                Text('$count', style: TextStyle(color: _tk.txtHead, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                  child: Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w600)),
                ),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  Widget _workPieCard() {
    final total   = _workDist.values.fold(0, (a, b) => a + b);
    final entries = _workDist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _tk.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _tk.bd),
        boxShadow: _tk.shadowSm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Work Type Distribution',
          style: TextStyle(color: _tk.txtHead, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        const SizedBox(height: 3),
        Text('Excludes Restoration (203)', style: TextStyle(color: _tk.txtMuted, fontSize: 12)),
        const SizedBox(height: 24),
        if (_workDist.isEmpty) _emptyState('No data yet') else ...[
          SizedBox(height: 260, child: PieChart(PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: 0,
            sections: entries.asMap().entries.map((e) {
              final isHov = _hovPie == e.key;
              final name  = e.value.key;
              final count = e.value.value;
              final pct   = total > 0 ? count / total * 100 : 0.0;
              final color = _workColors[name] ?? _chartPalette[e.key % _chartPalette.length];
              return PieChartSectionData(
                value: count.toDouble(),
                color: color,
                title: '${pct.toStringAsFixed(0)}%',
                radius: isHov ? 135 : 124,
                titleStyle: TextStyle(
                  color: Colors.white,
                  fontSize: isHov ? 14 : 12,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
            pieTouchData: PieTouchData(touchCallback: (ev, res) {
              if (!mounted) return;
              setState(() => _hovPie = (ev is FlPointerHoverEvent || ev is FlTapUpEvent)
                  ? res?.touchedSection?.touchedSectionIndex
                  : null);
            }),
          ))),
          const SizedBox(height: 24),
          ...entries.asMap().entries.map((e) {
            final name  = e.value.key;
            final count = e.value.value;
            final pct   = total > 0 ? count / total * 100 : 0.0;
            final color = _workColors[name] ?? _chartPalette[e.key % _chartPalette.length];
            final isHov = _hovPie == e.key;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.symmetric(horizontal: isHov ? 10 : 0, vertical: isHov ? 6 : 0),
              decoration: BoxDecoration(
                color: isHov ? color.withOpacity(0.06) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isHov ? Border.all(color: color.withOpacity(0.2)) : null,
              ),
              child: Row(children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  name,
                  style: TextStyle(color: _tk.txt, fontSize: 13, fontWeight: isHov ? FontWeight.w700 : FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: 8),
                Text('$count', style: TextStyle(color: _tk.txtHead, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  Widget _comboCard() {
    final maxY = _comboData.isEmpty ? 10.0
        : (_comboData.map((e) => e['value'] as double).reduce(math.max) + 3).ceilToDouble();
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: _tk.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _tk.bd),
        boxShadow: _tk.shadowSm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Work + Surface Combinations', style: TextStyle(color: _tk.txtHead, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Top 10 most frequent job-surface pairs', style: TextStyle(color: _tk.txtMuted, fontSize: 11.5)),
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(child: _comboData.isEmpty ? _emptyState('No data yet') : Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 20, 16),
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barGroups: _comboData.asMap().entries.map((e) {
              final isHov = _hovCombo == e.key;
              final color = _chartPalette[e.key % _chartPalette.length];
              return BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: e.value['value'],
                  width: isHov ? 36 : 28,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.35)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
              ]);
            }).toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _comboData.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_comboData[i]['label'], style: TextStyle(color: _tk.txtMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                  );
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(color: _tk.txtMuted, fontSize: 9.5)),
              )),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: _tk.bd, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => _tk.surf,
                getTooltipItem: (grp, gi, rod, _) {
                  final code = _comboData[gi]['label'] as String;
                  final dc = code.substring(0, 1);
                  final wc = code.substring(1);
                  final dn = damagedOptions.firstWhere((o) => o['code'] == dc, orElse: () => {'name': dc})['name']!;
                  final wn = workTypes.firstWhere((o) => o['code'] == wc, orElse: () => {'name': wc})['name']!;
                  return BarTooltipItem(
                    '$code  •  ${rod.toY.toInt()}\n',
                    TextStyle(color: _tk.txtHead, fontSize: 13, fontWeight: FontWeight.w700),
                    children: [TextSpan(text: '$dn\n$wn', style: TextStyle(color: _tk.txtMuted, fontSize: 10))],
                  );
                },
              ),
              touchCallback: (ev, res) {
                if (!mounted) return;
                setState(() => _hovCombo = (ev is FlPointerHoverEvent || ev is FlTapUpEvent)
                    ? res?.spot?.touchedBarGroupIndex : null);
              },
            ),
          )),
        )),
      ]),
    );
  }

  Widget _surfaceAddressCard() {
    const surfaces = [
      {'code': 'A', 'label': 'Concrete/Asphalt', 'short': 'Concrete'},
      {'code': 'B', 'label': 'Sidewalk/Gutter',  'short': 'Sidewalk'},
      {'code': 'C', 'label': 'Earth',             'short': 'Earth'},
    ];
    final surfColors = {'A': _cBlue, 'B': _cCyan, 'C': _cAmber};
    final data = _surfaceAddrData[_selectedSurface] ?? [];
    final selSurf = surfaces.firstWhere((s) => s['code'] == _selectedSurface);
    final accent  = surfColors[_selectedSurface] ?? _cBlue;

    return Container(
      decoration: BoxDecoration(
        color: _tk.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _tk.bd),
        boxShadow: _tk.shadowSm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 16, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Surface Type by Address', style: TextStyle(color: _tk.txtHead, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                'Accomplished jobs in ${selSurf['label']} areas by barangay',
                style: TextStyle(color: _tk.txtMuted, fontSize: 11.5),
              ),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withOpacity(0.25)),
              ),
              child: Text('${data.length} barangays', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: _tk.surf2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _tk.bd),
            ),
            child: Row(children: surfaces.map((s) {
              final isSel  = s['code'] == _selectedSurface;
              final sColor = surfColors[s['code']] ?? _cBlue;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() { _selectedSurface = s['code']!; _hovSurfAddr = null; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isSel ? sColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: isSel
                          ? [BoxShadow(color: sColor.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 7, height: 7, margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: isSel ? Colors.white : sColor),
                        ),
                        Text(
                          s['short']!,
                          style: TextStyle(
                            color: isSel ? Colors.white : _tk.txtMuted,
                            fontSize: 12.5,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }).toList()),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 340,
          child: data.isEmpty
              ? _emptyState('No jobs with ${selSurf['label']} surface')
              : _surfaceAddrBarChart(data, accent),
        ),
        const SizedBox(height: 4),
      ]),
    );
  }

  // ── FIX: Removed ClipRect wrapper — tooltips were being clipped on tall bars.
  // clipBehavior: Clip.none on SingleChildScrollView lets the tooltip layer
  // paint freely above the chart while horizontal scrolling still works correctly.
  Widget _surfaceAddrBarChart(List<Map<String, dynamic>> data, Color accent) {
    final maxY = (data.map((e) => e['value'] as double).reduce(math.max) + 2).ceilToDouble();
    final contentW = (data.length * 88.0 + 60).clamp(300.0, double.infinity);
    final sc = ScrollController();
    return Scrollbar(
      controller: sc,
      thumbVisibility: true,
      thickness: 4,
      radius: const Radius.circular(6),
      child: SingleChildScrollView(
        controller: sc,
        scrollDirection: Axis.horizontal,
        // ✅ Clip.none lets the fl_chart tooltip render above the bar
        // even when the bar reaches the very top of the chart area.
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: contentW,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 22, 24),
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barGroups: data.asMap().entries.map((e) {
                final isHov = _hovSurfAddr == e.key;
                return BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: e.value['value'],
                    width: isHov ? 28 : 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: LinearGradient(
                      colors: [accent, accent.withOpacity(0.30)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                ]);
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 70,
                        child: Text(data[i]['label'], style: TextStyle(color: _tk.txtMuted, fontSize: 9), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    );
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(color: _tk.txtMuted, fontSize: 9)),
                )),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: _tk.bd, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => _tk.surf,
                  getTooltipItem: (grp, gi, rod, _) => BarTooltipItem(
                    '${data[gi]['label']}\n',
                    TextStyle(color: _tk.txtMuted, fontSize: 10),
                    children: [TextSpan(
                      text: rod.toY.toInt().toString(),
                      style: TextStyle(color: _tk.txtHead, fontSize: 18, fontWeight: FontWeight.w800),
                    )],
                  ),
                ),
                touchCallback: (ev, res) {
                  if (!mounted) return;
                  setState(() => _hovSurfAddr = (ev is FlPointerHoverEvent || ev is FlTapUpEvent)
                      ? res?.spot?.touchedBarGroupIndex : null);
                },
              ),
            )),
          ),
        ),
      ),
    );
  }

  Widget _addressSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Address Breakdown', style: TextStyle(color: _tk.txtHead, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
    const SizedBox(height: 3),
    Text('Accomplished jobs per location by category', style: TextStyle(color: _tk.txtMuted, fontSize: 12.5)),
    const SizedBox(height: 16),
    _addrChart(_addressG1, 'Service & Infrastructure', '101 · 102 · 103 · 104'),
    const SizedBox(height: 16),
    _addrChart(_addressG2, 'Flushing', '201'),
    const SizedBox(height: 16),
    _addrChart(_addressG3, 'Valving', '202'),
    const SizedBox(height: 16),
    _addrChart(_addressG4, 'Restoration', '203'),
  ]);

  Widget _addrChart(List<Map<String, dynamic>> data, String title, String codes) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: _tk.surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _tk.bd),
        boxShadow: _tk.shadowSm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: _tk.txtHead, fontSize: 14.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Work codes: $codes', style: TextStyle(color: _tk.txtMuted, fontSize: 11.5)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _tk.blueBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _tk.blueBd),
              ),
              child: Text('${data.length} locations', style: TextStyle(color: _tk.blue, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(child: data.isEmpty ? _emptyState('No data for this category') : _addrBarChart(data)),
      ]),
    );
  }

  // ── FIX: Removed ClipRect wrapper — tooltips were being clipped on tall bars.
  // clipBehavior: Clip.none on SingleChildScrollView lets the tooltip layer
  // paint freely above the chart while horizontal scrolling still works correctly.
  Widget _addrBarChart(List<Map<String, dynamic>> data) {
    final maxY = (data.map((e) => e['value'] as double).reduce(math.max) + 2).ceilToDouble();
    final contentW = (data.length * 90.0 + 60).clamp(300.0, double.infinity);
    final sc = ScrollController();
    return Scrollbar(
      controller: sc,
      thumbVisibility: true,
      thickness: 4,
      radius: const Radius.circular(6),
      child: SingleChildScrollView(
        controller: sc,
        scrollDirection: Axis.horizontal,
        // ✅ Clip.none lets the fl_chart tooltip render above the bar
        // even when the bar reaches the very top of the chart area.
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: contentW,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 22, 24),
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barGroups: data.asMap().entries.map((e) {
                final isHov = _hovAddr == e.key;
                final color = _chartPalette[e.key % _chartPalette.length];
                return BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: e.value['value'],
                    width: isHov ? 28 : 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.3)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                ]);
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 70,
                        child: Text(
                          data[i]['label'],
                          style: TextStyle(color: _tk.txtMuted, fontSize: 9),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(color: _tk.txtMuted, fontSize: 9)),
                )),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: _tk.bd, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => _tk.surf,
                  getTooltipItem: (grp, gi, rod, _) => BarTooltipItem(
                    data[gi]['label'] + '\n',
                    TextStyle(color: _tk.txtMuted, fontSize: 10),
                    children: [TextSpan(
                      text: rod.toY.toInt().toString(),
                      style: TextStyle(color: _tk.txtHead, fontSize: 18, fontWeight: FontWeight.w800),
                    )],
                  ),
                ),
                touchCallback: (ev, res) {
                  if (!mounted) return;
                  setState(() => _hovAddr = (ev is FlPointerHoverEvent || ev is FlTapUpEvent)
                      ? res?.spot?.touchedBarGroupIndex : null);
                },
              ),
            )),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String msg) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.bar_chart_rounded, color: _tk.bd2, size: 40),
    const SizedBox(height: 10),
    Text(msg, style: TextStyle(color: _tk.txtMuted, fontSize: 13)),
  ]));
}

// ── Filter Chip button ────────────────────────────────────────────────────────
class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final bg = widget.isSelected
        ? widget.accent
        : (widget.isDark ? const Color(0xFF161F30) : const Color(0xFFF7FAFD));
    final border = widget.isSelected
        ? widget.accent
        : (widget.isDark ? const Color(0xFF1E2E47) : const Color(0xFFDDE6F0));
    final txtColor = widget.isSelected
        ? Colors.white
        : (widget.isDark ? const Color(0xFFAFC4DE) : const Color(0xFF2D4263));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: border, width: 1.5),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: widget.accent.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 3))]
                : (_hov ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)] : null),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 13, color: widget.isSelected ? Colors.white : widget.accent),
            const SizedBox(width: 6),
            Text(widget.label, style: TextStyle(color: txtColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ── Premium Dark Mode Toggle ──────────────────────────────────────────────────
class _DarkModeToggle extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggle;
  const _DarkModeToggle({required this.isDark, required this.onToggle});
  @override
  State<_DarkModeToggle> createState() => _DarkModeToggleState();
}

class _DarkModeToggleState extends State<_DarkModeToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _glowAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutBack);
    _glowAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.isDark) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_DarkModeToggle old) {
    super.didUpdateWidget(old);
    if (widget.isDark != old.isDark) {
      widget.isDark ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            final trackColor = Color.lerp(const Color(0xFFE2EAF4), const Color(0xFF1A3A6E), t)!;
            final thumbColor = Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF3B82F6), t)!;
            final glowColor  = Color.lerp(Colors.transparent, const Color(0x663B82F6), _glowAnim.value)!;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: _hovered
                    ? [BoxShadow(color: glowColor, blurRadius: 14, spreadRadius: 1)]
                    : null,
              ),
              child: Container(
                width: 68,
                height: 32,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color.lerp(const Color(0xFFD0DEEC), const Color(0xFF2B5599), t)!,
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 8,
                      child: Opacity(
                        opacity: (1 - t).clamp(0.0, 1.0),
                        child: const Icon(Icons.wb_sunny_rounded, size: 13, color: Color(0xFFD97706)),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      child: Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: const Icon(Icons.dark_mode_rounded, size: 13, color: Color(0xFF93C5FD)),
                      ),
                    ),
                    Positioned(
                      left: 4 + (_slideAnim.value * 34),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: thumbColor,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2)),
                            if (t > 0.5)
                              BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.4 * t), blurRadius: 10, spreadRadius: 1),
                          ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: t > 0.5
                                ? const Icon(Icons.dark_mode_rounded, key: ValueKey('moon'), size: 13, color: Color(0xFFEFF6FF))
                                : const Icon(Icons.wb_sunny_rounded,  key: ValueKey('sun'),  size: 13, color: Color(0xFFD97706)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}