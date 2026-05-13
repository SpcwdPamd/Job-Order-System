import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/session/session.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/core/notifiers/pending_users_notifier.dart'; // ← NEW
import 'package:job_order/screens/login_screen.dart';
import 'package:job_order/screens/accomplished_screen.dart';
import 'package:job_order/screens/dashboard_screen.dart';
import 'package:job_order/screens/job_order_screen.dart';
import 'package:job_order/screens/settings_screen.dart';
import 'package:job_order/screens/skeletal_team_screen.dart';
import 'package:job_order/screens/team_jobs_screen.dart';
import 'package:job_order/screens/team_jo.dart';
import 'package:job_order/screens/monthly_report_screen.dart';
import 'package:job_order/screens/overall_report_screen.dart';
import 'package:job_order/screens/relocation_report_screen.dart';
import 'package:job_order/screens/admin/admin_page.dart';

// Index map:
//  0  Dashboard        1  Job Order       2  Team Jobs
//  3  Skeletal         4  Team J.O        5  Accomplished
//  6  Monthly Report   7  Overall Report  8  Relocation
//  9  Settings        10  Admin
const _glowColors = <int, Color>{
  0:  Color(0xFF1D6FE8), 1:  Color(0xFF0891B2), 2:  Color(0xFF7C3AED),
  3:  Color(0xFF059669), 4:  Color(0xFFDB2777), 5:  Color(0xFF059669),
  6:  Color(0xFF4338CA), 7:  Color(0xFF0891B2), 8:  Color(0xFFDB2777),
  9:  Color(0xFF64748B), 10: Color(0xFF7C3AED),
};

class _SideItem {
  final int idx; final IconData icon; final String label;
  const _SideItem(this.idx, this.icon, this.label);
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int  _sel      = 0;
  bool _expanded = true;
  bool _reports  = false;
  int  _hov      = -1;
  bool _isDark   = false;

  static const _top = [
    _SideItem(0,  Icons.dashboard_rounded,    'Analytics'),
    _SideItem(1,  Icons.receipt_long_rounded, 'Complaints'),
    _SideItem(2,  Icons.work_history_rounded, 'Job Orders'),
    _SideItem(3,  Icons.group_add_rounded,    'Skeletal'),
    _SideItem(4,  Icons.groups_rounded,       'Team Overview'),
    _SideItem(5,  Icons.task_alt_rounded,     'Accomplished'),
  ];
  static const _reps = [
    _SideItem(6,  Icons.calendar_month_rounded, 'Monthly Report'),
    _SideItem(7,  Icons.bar_chart_rounded,      'Overall Report'),
    _SideItem(8,  Icons.swap_horiz_rounded,     'Relocation'),
  ];

  List<Widget> get _screens => [
    const DashboardScreen(),
    const JobOrderScreen(),
    const TeamJobsScreen(),
    const SkeletalTeamScreen(),
    const TeamJoScreen(),
    const AccomplishedScreen(),
    const MonthlyReportScreen(),
    const OverallReportScreen(),
    const RelocationReportScreen(),
    const SettingsScreen(),
    AdminPage(onBack: () => setState(() => _sel = 0)),
  ];

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onTheme);
    // ── Fetch pending count once on start, then keep it live ──────────────
    pendingUsersNotifier.refresh();
    pendingUsersNotifier.addListener(_onPending);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onTheme);
    pendingUsersNotifier.removeListener(_onPending);
    super.dispose();
  }

  void _onTheme() {
    if (mounted) setState(() => _isDark = themeNotifier.isDark);
  }

  void _onPending() {
    // Rebuild so the badge count updates in the sidebar
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tk = Tk(_isDark);
    return TkProvider(
      tk: tk,
      child: Scaffold(
        backgroundColor: tk.bg,
        body: Row(children: [
          _sidebar(tk),
          Expanded(child: _screens[_sel]),
        ]),
      ),
    );
  }

  // ── SIDEBAR ─────────────────────────────────────────────────────────────────
  Widget _sidebar(Tk tk) {
    final rActive = _reps.any((r) => r.idx == _sel);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      width: _expanded ? 248 : 68,
      decoration: BoxDecoration(
        color: tk.sideBg,
        border: Border(right: BorderSide(color: tk.sideBd, width: 1)),
      ),
      child: Column(children: [
        _sHeader(tk),
        Expanded(child: ClipRect(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_expanded) _sLabel(tk, 'MAIN'),
                ..._top.map((i) => _sTile(tk, i)),
                const SizedBox(height: 6),
                if (_expanded) _sLabel(tk, 'REPORTS'),
                _sReportsGroup(tk, rActive),
                const SizedBox(height: 6),
                if (_expanded) _sLabel(tk, 'SYSTEM'),
                _sTile(tk, const _SideItem(9, Icons.tune_rounded, 'Settings')),
                if (AppSession.instance.canAccessAdmin)
                  _sAdminTile(tk), // ← uses special tile with badge
              ]),
            ))),
        _sFooter(tk),
      ]),
    );
  }

  // ── Admin tile with pending badge ──────────────────────────────────────────
  Widget _sAdminTile(Tk tk) {
    const item  = _SideItem(10, Icons.admin_panel_settings_rounded, 'Admin');
    final isSel = _sel == item.idx;
    final isHov = _hov == item.idx;
    final glow  = _glowColors[item.idx] ?? const Color(0xFF7C3AED);
    final pending = pendingUsersNotifier.value;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = item.idx),
      onExit:  (_) => setState(() => _hov = -1),
      child: GestureDetector(
        onTap: () {
          setState(() => _sel = item.idx);
          // Refresh count when admin page is opened
          pendingUsersNotifier.refresh();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          clipBehavior: Clip.hardEdge,
          margin: EdgeInsets.symmetric(horizontal: _expanded ? 8 : 9, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: _expanded ? 10 : 0, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: isSel
                ? glow.withOpacity(tk.dark ? 0.22 : 0.18)
                : isHov
                ? Colors.white.withOpacity(tk.dark ? 0.04 : 0.06)
                : Colors.transparent,
            border: isSel ? Border.all(color: glow.withOpacity(0.35), width: 1) : null,
            boxShadow: isSel
                ? [BoxShadow(
                color: glow.withOpacity(tk.dark ? 0.35 : 0.25),
                blurRadius: 14,
                offset: const Offset(0, 2))]
                : null,
          ),
          child: _expanded
              ? Row(children: [
            if (isSel)
              Container(
                  width: 3, height: 15,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: glow,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(color: glow.withOpacity(0.7), blurRadius: 8)
                      ]))
            else
              const SizedBox(width: 11),
            Icon(item.icon,
                size: 18,
                color: isSel
                    ? glow
                    : isHov
                    ? const Color(0xFFD6E4F7)
                    : const Color(0xFF5A7FA8)),
            const SizedBox(width: 9),
            Expanded(
                child: Text(item.label,
                    style: TextStyle(
                        color: isSel
                            ? Colors.white
                            : isHov
                            ? const Color(0xFFD6E4F7)
                            : const Color(0xFF8AAED4),
                        fontSize: 12.5,
                        fontWeight: isSel
                            ? FontWeight.w600
                            : FontWeight.w400))),
            // ── Badge ──────────────────────────────────────────────────
            if (pending > 0)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.55),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Text(
                  pending > 99 ? '99+' : '$pending',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.2),
                ),
              ),
          ])
              : Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(item.icon,
                  size: 18,
                  color: isSel
                      ? glow
                      : isHov
                      ? const Color(0xFFD6E4F7)
                      : const Color(0xFF5A7FA8)),
              // Dot badge when sidebar is collapsed
              if (pending > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: tk.sideBg, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.6),
                            blurRadius: 6)
                      ],
                    ),
                    child: Center(
                      child: Text(
                        pending > 9 ? '9+' : '$pending',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            height: 1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sHeader(Tk tk) {
    final hBg = tk.dark ? const Color(0xFF02060E) : const Color(0xFF071A38);
    final hBd = tk.dark ? const Color(0xFF0C1525) : const Color(0xFF163461);
    return Container(
      height: 66,
      decoration: BoxDecoration(color: hBg, border: Border(bottom: BorderSide(color: hBd))),
      child: _expanded
          ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            _sLogo(),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('SPCWD',
                      style: TextStyle(color: Colors.white, fontSize: 13.5,
                          fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  Text('Job Order System', style: TextStyle(color: tk.sideMut, fontSize: 10)),
                ]),
          ]),
          GestureDetector(
            onTap: () => setState(() => _expanded = false),
            child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white, size: 18)),
          ),
        ]),
      )
          : GestureDetector(
          onTap: () => setState(() => _expanded = true),
          child: Center(child: _sLogo())),
    );
  }

  Widget _sLogo() => Container(
    width: 34, height: 34,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(9),
      boxShadow: [
        const BoxShadow(color: Color(0x661D6FE8), blurRadius: 12, offset: Offset(0, 3))
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.asset('assets/images/seal.png', fit: BoxFit.cover),
    ),
  );

  Widget _sLabel(Tk tk, String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(t,
        style: TextStyle(
            color: tk.dark
                ? const Color(0xFF1A3A5E)
                : const Color(0xFF3D608A),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8)),
  );

  Widget _sTile(Tk tk, _SideItem item) {
    final isSel = _sel == item.idx;
    final isHov = _hov == item.idx;
    final glow  = _glowColors[item.idx] ?? const Color(0xFF1D6FE8);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = item.idx),
      onExit:  (_) => setState(() => _hov = -1),
      child: GestureDetector(
        onTap: () => setState(() => _sel = item.idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          clipBehavior: Clip.hardEdge,
          margin: EdgeInsets.symmetric(horizontal: _expanded ? 8 : 9, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: _expanded ? 10 : 0, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: isSel
                ? glow.withOpacity(tk.dark ? 0.22 : 0.18)
                : isHov
                ? Colors.white.withOpacity(tk.dark ? 0.04 : 0.06)
                : Colors.transparent,
            border: isSel ? Border.all(color: glow.withOpacity(0.35), width: 1) : null,
            boxShadow: isSel
                ? [BoxShadow(
                color: glow.withOpacity(tk.dark ? 0.35 : 0.25),
                blurRadius: 14,
                offset: const Offset(0, 2))]
                : null,
          ),
          child: _expanded
              ? Row(children: [
            if (isSel)
              Container(
                  width: 3, height: 15,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: glow,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(color: glow.withOpacity(0.7), blurRadius: 8)
                      ]))
            else
              const SizedBox(width: 11),
            Icon(item.icon,
                size: 18,
                color: isSel
                    ? glow
                    : isHov
                    ? const Color(0xFFD6E4F7)
                    : const Color(0xFF5A7FA8)),
            const SizedBox(width: 9),
            Expanded(
                child: Text(item.label,
                    style: TextStyle(
                        color: isSel
                            ? Colors.white
                            : isHov
                            ? const Color(0xFFD6E4F7)
                            : const Color(0xFF8AAED4),
                        fontSize: 12.5,
                        fontWeight: isSel
                            ? FontWeight.w600
                            : FontWeight.w400))),
          ])
              : Center(
              child: Icon(item.icon,
                  size: 18,
                  color: isSel
                      ? glow
                      : isHov
                      ? const Color(0xFFD6E4F7)
                      : const Color(0xFF5A7FA8))),
        ),
      ),
    );
  }

  Widget _sReportsGroup(Tk tk, bool rActive) {
    final isHov = _hov == 999;
    const glow  = Color(0xFF4338CA);
    return Column(children: [
      MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hov = 999),
        onExit:  (_) => setState(() => _hov = -1),
        child: GestureDetector(
          onTap: () => setState(() => _reports = !_reports),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            clipBehavior: Clip.hardEdge,
            margin: EdgeInsets.symmetric(
                horizontal: _expanded ? 8 : 9, vertical: 2),
            padding: EdgeInsets.symmetric(
                horizontal: _expanded ? 10 : 0, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: rActive
                  ? glow.withOpacity(tk.dark ? 0.22 : 0.18)
                  : isHov
                  ? Colors.white.withOpacity(tk.dark ? 0.04 : 0.06)
                  : Colors.transparent,
              border: rActive ? Border.all(color: glow.withOpacity(0.35)) : null,
              boxShadow: rActive
                  ? [BoxShadow(
                  color: glow.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 2))]
                  : null,
            ),
            child: _expanded
                ? Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              const SizedBox(width: 11),
              Icon(Icons.assessment_rounded,
                  size: 18,
                  color: rActive
                      ? glow
                      : isHov
                      ? const Color(0xFFD6E4F7)
                      : const Color(0xFF5A7FA8)),
              const SizedBox(width: 9),
              Expanded(
                  child: Text('Reports',
                      style: TextStyle(
                          color: rActive
                              ? Colors.white
                              : isHov
                              ? const Color(0xFFD6E4F7)
                              : const Color(0xFF8AAED4),
                          fontSize: 12.5,
                          fontWeight: rActive
                              ? FontWeight.w600
                              : FontWeight.w400))),
              AnimatedRotation(
                  turns: _reports ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF5A7FA8),
                      size: 17)),
            ])
                : Center(
                child: Icon(Icons.assessment_rounded,
                    size: 18,
                    color: rActive
                        ? glow
                        : isHov
                        ? const Color(0xFFD6E4F7)
                        : const Color(0xFF5A7FA8))),
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        child: (_reports && _expanded)
            ? Column(
          children: _reps.map((item) {
            final isSel  = _sel == item.idx;
            final isHovS = _hov == item.idx + 500;
            final subGlow = _glowColors[item.idx] ?? glow;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hov = item.idx + 500),
              onExit:  (_) => setState(() => _hov = -1),
              child: GestureDetector(
                onTap: () => setState(() => _sel = item.idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  clipBehavior: Clip.hardEdge,
                  margin: _expanded
                      ? const EdgeInsets.fromLTRB(20, 1, 8, 1)
                      : const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  padding: _expanded
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
                      : const EdgeInsets.symmetric(horizontal: 0, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: isSel
                        ? subGlow.withOpacity(tk.dark ? 0.22 : 0.18)
                        : isHovS
                        ? Colors.white.withOpacity(0.05)
                        : Colors.transparent,
                    border: isSel
                        ? Border.all(color: subGlow.withOpacity(0.35))
                        : null,
                    boxShadow: isSel
                        ? [BoxShadow(
                        color: subGlow.withOpacity(0.2),
                        blurRadius: 8)]
                        : null,
                  ),
                  child: _expanded
                      ? Row(children: [
                    Container(
                        width: 3,
                        height: 14,
                        margin: const EdgeInsets.only(right: 9),
                        decoration: BoxDecoration(
                            color: isSel
                                ? subGlow
                                : const Color(0xFF253F5E),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isSel
                                ? [BoxShadow(
                                color: subGlow.withOpacity(0.5),
                                blurRadius: 4)]
                                : null)),
                    Icon(item.icon,
                        size: 14,
                        color: isSel
                            ? subGlow
                            : const Color(0xFF5A7FA8)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(item.label,
                            style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : const Color(0xFF8AAED4),
                                fontSize: 11.5,
                                fontWeight: isSel
                                    ? FontWeight.w600
                                    : FontWeight.w400))),
                  ])
                      : Center(
                      child: Icon(item.icon,
                          size: 18,
                          color: isSel
                              ? subGlow
                              : const Color(0xFF5A7FA8))),
                ),
              ),
            );
          }).toList(),
        )
            : const SizedBox.shrink(),
      ),
    ]);
  }

  // ── FOOTER ──────────────────────────────────────────────────────────────────
  Widget _sFooter(Tk tk) {
    final fBg = tk.dark ? const Color(0xFF02060E) : const Color(0xFF071A38);
    final fBd = tk.sideBd;

    final sess        = AppSession.instance;
    final displayName = sess.fullName ?? sess.username ?? 'User';
    final initial     = sess.initial;

    void showSignOutDialog() {
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (ctx) => Dialog(
          backgroundColor:
          tk.dark ? const Color(0xFF101827) : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          elevation: 24,
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.25),
                      width: 1.5),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Color(0xFFEF4444), size: 26),
              ),
              const SizedBox(height: 18),
              Text('Sign Out',
                  style: TextStyle(
                      color: tk.dark
                          ? const Color(0xFFEDF2FF)
                          : const Color(0xFF0D1F3C),
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  'Are you sure you want to sign out\nof the SPCWD Job Order System?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: tk.dark
                          ? const Color(0xFF475F7E)
                          : const Color(0xFF7A93B4),
                      fontSize: 13.5,
                      height: 1.5)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: tk.dark
                          ? const Color(0xFF161F30)
                          : const Color(0xFFF7FAFD),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: tk.dark
                              ? const Color(0xFF1E2E47)
                              : const Color(0xFFDDE6F0)),
                    ),
                    child: Center(
                        child: Text('Cancel',
                            style: TextStyle(
                                color: tk.dark
                                    ? const Color(0xFFAFC4DE)
                                    : const Color(0xFF2D4263),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600))),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () {
                    AppSession.instance.clear();
                    Navigator.pop(ctx);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                          (route) => false,
                    );
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                            color:
                            const Color(0xFFEF4444).withOpacity(0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: const Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.logout_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Sign Out',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700)),
                        ])),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: _expanded ? 12 : 0, vertical: 10),
      decoration:
      BoxDecoration(color: fBg, border: Border(top: BorderSide(color: fBd))),
      child: _expanded
          ? Row(children: [
        Container(
          width: 34, height: 34,
          decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)])),
          child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14))),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                            color: Color(0xFF34D399),
                            shape: BoxShape.circle)),
                    Text(
                      sess.isAdmin ? 'Admin' :
                      sess.isSubAdmin ? 'Sub-Admin' : 'Online',
                      style: TextStyle(
                          color: sess.isAdmin
                              ? const Color(0xFFA78BFA)
                              : sess.isSubAdmin
                              ? const Color(0xFF22D3EE)
                              : const Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ])),
        GestureDetector(
          onTap: showSignOutDialog,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.white.withOpacity(0.10)),
            ),
            child: const Icon(Icons.logout_rounded,
                color: Color(0xFFEF4444), size: 15),
          ),
        ),
      ])
          : GestureDetector(
        onTap: showSignOutDialog,
        child: Center(
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFEF4444), size: 16),
            )),
      ),
    );
  }
}