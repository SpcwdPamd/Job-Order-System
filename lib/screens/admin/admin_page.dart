// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  Admin Page — full admin management hub                                    ║
// ║  Sub-pages open inline (no Navigator.push) so the sidebar stays visible.  ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/core/notifiers/pending_users_notifier.dart'; // ← NEW
import 'package:job_order/screens/admin/admin_work_types_page.dart';
import 'package:job_order/screens/admin/admin_damage_spaces_page.dart';
import 'package:job_order/screens/admin/admin_user_approvals_page.dart';
import 'package:job_order/screens/admin/admin_team_accounts_page.dart';
import 'package:job_order/screens/admin/delete_jobs_page.dart';
import 'package:job_order/screens/admin/trash_bin_page.dart';
import 'package:job_order/screens/admin/edit_jo_screen.dart';

enum _AdminSubPage {
  none,
  userApprovals,
  teamAccounts,
  editTeams,
  editPersonnel,
  deleteJobs,
  trashBin,
  workTypes,
  damageSpaces,
}

class AdminPage extends StatefulWidget {
  final VoidCallback? onBack;
  const AdminPage({super.key, this.onBack});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  _AdminSubPage _sub = _AdminSubPage.none;

  void _open(_AdminSubPage page) => setState(() => _sub = page);
  void _back() {
    setState(() => _sub = _AdminSubPage.none);
    // Refresh the badge count whenever we return to the hub
    pendingUsersNotifier.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_sub != _AdminSubPage.none) {
          _back();
          return false;
        }
        return true;
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_sub) {
      case _AdminSubPage.userApprovals:
        return AdminUserApprovalsPage(onBack: _back);
      case _AdminSubPage.teamAccounts:
        return AdminTeamAccountsPage(onBack: _back);
      case _AdminSubPage.editTeams:
        return AdminEditScreen(initialTab: 0, onBack: _back);
      case _AdminSubPage.editPersonnel:
        return AdminEditScreen(initialTab: 1, onBack: _back);
      case _AdminSubPage.deleteJobs:
        return DeleteJobsPage(onBack: _back);
      case _AdminSubPage.trashBin:
        return TrashBinPage(onBack: _back);
      case _AdminSubPage.workTypes:
        return AdminWorkTypesPage(onBack: _back);
      case _AdminSubPage.damageSpaces:
        return AdminDamageSpacesPage(onBack: _back);
      case _AdminSubPage.none:
        return _buildHub(context);
    }
  }

  Widget _buildHub(BuildContext context) {
    final tk = context.tk;
    return Scaffold(
      backgroundColor: tk.bg,
      body: Column(children: [
        DsHeader(
          title: 'Admin',
          subtitle: 'Manage users, teams, data & job order options',
          icon: Icons.admin_panel_settings_rounded,
          accent: tk.violet,
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── USER MANAGEMENT ──────────────────────────────────────────────
              const DsLabel('User Management'),

              // ── User Approvals tile with live badge ──────────────────────────
              ValueListenableBuilder<int>(
                valueListenable: pendingUsersNotifier,
                builder: (_, pending, __) => _AdminTile(
                  icon: Icons.manage_accounts_rounded,
                  title: 'User Approvals',
                  subtitle: 'Review, approve or reject new sign-up requests',
                  accent: tk.violet,
                  badge: pending,                          // ← badge count
                  onTap: () => _open(_AdminSubPage.userApprovals),
                ),
              ),

              const SizedBox(height: 12),
              _AdminTile(
                icon: Icons.phone_android_rounded,
                title: 'Team Mobile Accounts',
                subtitle: "Create, edit or delete login accounts for each team's mobile app",
                accent: tk.green,
                onTap: () => _open(_AdminSubPage.teamAccounts),
              ),
              const SizedBox(height: 28),

              // ── TEAMS & PERSONNEL ────────────────────────────────────────────
              const DsLabel('Teams & Personnel'),
              _AdminTile(
                icon: Icons.groups_rounded,
                title: 'Edit Teams',
                subtitle: 'Create, edit or delete teams and assign members',
                accent: tk.blue,
                onTap: () => _open(_AdminSubPage.editTeams),
              ),
              const SizedBox(height: 12),
              _AdminTile(
                icon: Icons.badge_rounded,
                title: 'Edit Personnel',
                subtitle: 'Add, edit, delete personnel and manage profile photos',
                accent: tk.cyan,
                onTap: () => _open(_AdminSubPage.editPersonnel),
              ),
              const SizedBox(height: 28),

              // ── DATA MANAGEMENT ──────────────────────────────────────────────
              const DsLabel('Data Management'),
              _AdminTile(
                icon: Icons.delete_sweep_rounded,
                title: 'Delete Jobs',
                subtitle: 'Move job orders or skeletal jobs to Trash Bin',
                accent: tk.red,
                onTap: () => _open(_AdminSubPage.deleteJobs),
              ),
              const SizedBox(height: 12),
              _AdminTile(
                icon: Icons.restore_from_trash_rounded,
                title: 'Trash Bin',
                subtitle: 'Restore or permanently delete trashed jobs',
                accent: tk.amber,
                onTap: () => _open(_AdminSubPage.trashBin),
              ),
              const SizedBox(height: 28),

              // ── JOB ORDER OPTIONS ────────────────────────────────────────────
              const DsLabel('Job Order Options'),
              _AdminTile(
                icon: Icons.build_circle_rounded,
                title: 'Add / Edit Type of Works',
                subtitle: 'Manage work type codes shown in Job Order form',
                accent: tk.blue,
                onTap: () => _open(_AdminSubPage.workTypes),
              ),
              const SizedBox(height: 12),
              _AdminTile(
                icon: Icons.layers_rounded,
                title: 'Add / Edit Damage Working Space',
                subtitle: 'Manage damage workspace options in Job Order form',
                accent: tk.amber,
                onTap: () => _open(_AdminSubPage.damageSpaces),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Admin Edit Screen (Teams tab=0, Personnel tab=1) ──────────────────────────
class AdminEditScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback? onBack;
  const AdminEditScreen({super.key, this.initialTab = 0, this.onBack});
  @override
  State<AdminEditScreen> createState() => _AdminEditScreenState();
}

class _AdminEditScreenState extends State<AdminEditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Scaffold(
      backgroundColor: tk.bg,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
          decoration: BoxDecoration(
            color: tk.surf,
            border: Border(bottom: BorderSide(color: tk.bd)),
            boxShadow: tk.shadowSm,
          ),
          child: SafeArea(bottom: false, child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: widget.onBack ?? () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: tk.surf2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tk.bd),
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: tk.txtHead, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tk.blue, tk.blue.withOpacity(0.7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: tk.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Teams & Personnel',
                    style: TextStyle(color: tk.txtHead, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                Text('Add, edit or delete teams and personnel',
                    style: TextStyle(color: tk.txtMuted, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 14),
            TabBar(
              controller: _tab,
              labelColor: tk.blue,
              unselectedLabelColor: tk.txtMuted,
              indicatorColor: tk.blue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: 'Edit Teams'),
                Tab(text: 'Edit Personnel'),
              ],
            ),
          ])),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              EditTeamsTab(),
              EditPersonnelTab(),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Shared Admin Tile ─────────────────────────────────────────────────────────
class _AdminTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final int badge; // ← NEW: 0 means no badge shown

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.badge = 0,
  });

  @override
  State<_AdminTile> createState() => _AdminTileState();
}

class _AdminTileState extends State<_AdminTile> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hov ? widget.accent.withOpacity(0.04) : tk.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hov ? widget.accent.withOpacity(0.35) : tk.bd,
              width: _hov ? 1.5 : 1,
            ),
            boxShadow: _hov
                ? [BoxShadow(color: widget.accent.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 4))]
                : tk.shadowSm,
          ),
          child: Row(children: [
            // Icon box
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: widget.accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.accent.withOpacity(0.22)),
                  ),
                  child: Icon(widget.icon, color: widget.accent, size: 22),
                ),
                // Badge dot on icon
                if (widget.badge > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: tk.surf, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFEF4444).withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Text(
                        widget.badge > 99 ? '99+' : '${widget.badge}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1.2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(widget.title,
                          style: TextStyle(
                              color: tk.txtHead,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600)),
                    ),
                    // Inline badge pill next to title
                    if (widget.badge > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFEF4444).withOpacity(0.30)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 5, height: 5,
                            decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.badge} pending',
                            style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700),
                          ),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(widget.subtitle,
                      style: TextStyle(color: tk.txtMuted, fontSize: 12.5)),
                ])),
            Icon(Icons.chevron_right_rounded, color: tk.bd2, size: 20),
          ]),
        ),
      ),
    );
  }
}