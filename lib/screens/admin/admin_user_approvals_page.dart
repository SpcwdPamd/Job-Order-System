import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/core/notifiers/pending_users_notifier.dart'; // ← NEW
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserApprovalsPage extends StatefulWidget {
  final VoidCallback? onBack;
  const AdminUserApprovalsPage({super.key, this.onBack});
  @override
  State<AdminUserApprovalsPage> createState() => _AdminUserApprovalsPageState();
}

class _AdminUserApprovalsPageState extends State<AdminUserApprovalsPage>
    with SingleTickerProviderStateMixin {
  Tk get _tk => context.tk;
  List<Map<String, dynamic>> _pending  = [];
  List<Map<String, dynamic>> _allUsers = [];
  bool _loading = true;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await Supabase.instance.client
          .from('users')
          .select('id, full_name, username, role, status, created_at, '
          'perm_admin, perm_edit_details, perm_edit_reports')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _pending  = (all as List).where((u) => u['status'] == 'pending')
            .map((u) => Map<String, dynamic>.from(u)).toList();
        _allUsers = (all).where((u) => u['status'] != 'pending')
            .map((u) => Map<String, dynamic>.from(u)).toList();
        _loading  = false;
      });
      // ── Keep the global badge in sync whenever this page loads ───────────
      pendingUsersNotifier.value = _pending.length;
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _tk.red));
    }
  }

  Future<void> _setStatus(int id, String status) async {
    try {
      await Supabase.instance.client
          .from('users').update({'status': status}).eq('id', id);
      if (!mounted) return;
      await _load(); // also updates pendingUsersNotifier inside _load()
      final msg = switch (status) {
        'approved' => 'User approved ✓',
        'rejected' => 'User rejected',
        'blocked'  => 'User blocked',
        _          => 'Status updated',
      };
      final color = status == 'approved' ? const Color(0xFF059669) : _tk.red;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _tk.red));
    }
  }

  Future<void> _deleteUser(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _tk.surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _tk.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.warning_rounded, color: _tk.red, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Delete Account?',
              style: TextStyle(
                  color: _tk.txtHead,
                  fontWeight: FontWeight.w800,
                  fontSize: 16))),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are about to permanently delete:',
                  style: TextStyle(color: _tk.txt, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _tk.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _tk.red.withOpacity(0.2))),
                child: Row(children: [
                  Icon(Icons.person_rounded, color: _tk.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(name,
                          style: TextStyle(
                              color: _tk.red,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5))),
                ]),
              ),
              const SizedBox(height: 10),
              Text(
                  'This cannot be undone. All data linked to this account will be affected.',
                  style: TextStyle(color: _tk.txtMuted, fontSize: 12)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: _tk.txtMuted))),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Delete Permanently'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _tk.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('users').delete().eq('id', id);
      if (!mounted) return;
      await _load(); // refreshes notifier
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account deleted permanently'),
          backgroundColor: Color(0xFF059669)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e'),
              backgroundColor: _tk.red));
    }
  }

  Future<void> _removePhoto(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _tk.surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Profile Photo?',
            style:
            TextStyle(color: _tk.txtHead, fontWeight: FontWeight.w700)),
        content: Text('This will remove the user\'s profile photo.',
            style: TextStyle(color: _tk.txt)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: _tk.txtMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _tk.red,
                foregroundColor: Colors.white,
                elevation: 0),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({'profile_photo_url': null}).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile photo removed'),
          backgroundColor: Color(0xFF059669)));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _tk.red));
    }
  }

  // ── Sub-admin permissions dialog ──────────────────────────────────────────
  void _showPermissionsDialog(Map<String, dynamic> user) {
    final id        = user['id'] as int;
    final name      = user['full_name'] as String? ??
        user['username'] as String? ?? '—';
    String role     = user['role'] as String? ?? 'user';
    bool pAdmin     = user['perm_admin']        as bool? ?? false;
    bool pReports   = user['perm_edit_reports'] as bool? ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isSubAdmin = role == 'sub_admin';
          return Dialog(
            backgroundColor: _tk.surf,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: _tk.bd)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _tk.violet.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _tk.violet.withOpacity(0.28)),
                      ),
                      child: Icon(Icons.manage_accounts_rounded,
                          color: _tk.violet, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Permissions',
                                style: TextStyle(
                                    color: _tk.txtHead,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            Text(name,
                                style: TextStyle(
                                    color: _tk.txtMuted, fontSize: 12.5)),
                          ]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close_rounded,
                          color: _tk.txtMuted, size: 20),
                    ),
                  ]),

                  const SizedBox(height: 22),

                  Text('Role',
                      style: TextStyle(
                          color: _tk.txtMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4)),
                  const SizedBox(height: 10),
                  _RoleChip(
                    label: 'Regular User',
                    icon: Icons.person_rounded,
                    selected: role == 'user',
                    color: _tk.blue,
                    onTap: () => setS(() {
                      role     = 'user';
                      pAdmin   = false;
                      pReports = false;
                    }),
                  ),
                  const SizedBox(height: 8),
                  _RoleChip(
                    label: 'Sub-Admin',
                    icon: Icons.admin_panel_settings_outlined,
                    selected: role == 'sub_admin',
                    color: _tk.violet,
                    onTap: () => setS(() => role = 'sub_admin'),
                  ),

                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: isSubAdmin
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),
                        Text('Permissions',
                            style: TextStyle(
                                color: _tk.txtMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4)),
                        const SizedBox(height: 10),
                        _PermToggle(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'Admin Panel Access',
                          sublabel: 'Can view & use the Admin sidebar section',
                          value: pAdmin,
                          color: _tk.violet,
                          onChanged: (v) => setS(() => pAdmin = v),
                        ),
                        const SizedBox(height: 8),
                        _PermToggle(
                          icon: Icons.description_rounded,
                          label: 'Edit Reports',
                          sublabel:
                          'Can edit monthly, overall & relocation reports',
                          value: pReports,
                          color: _tk.green,
                          onChanged: (v) => setS(() => pReports = v),
                        ),
                      ],
                    ),
                    secondChild: const SizedBox(height: 0),
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_rounded, size: 17),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tk.violet,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await Supabase.instance.client
                              .from('users')
                              .update({
                            'role':               role,
                            'perm_admin':         role == 'sub_admin' ? pAdmin   : false,
                            'perm_edit_details':  false,
                            'perm_edit_reports':  role == 'sub_admin' ? pReports : false,
                          }).eq('id', id);
                          if (!mounted) return;
                          _load();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Permissions saved for $name'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: _tk.red),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tk.bg,
      body: Column(children: [
        // ── Header ─────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
          decoration: BoxDecoration(
            color: _tk.surf,
            border: Border(bottom: BorderSide(color: _tk.bd)),
            boxShadow: _tk.shadowSm,
          ),
          child: SafeArea(
              bottom: false,
              child: Column(children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => widget.onBack != null
                        ? widget.onBack!()
                        : Navigator.pop(context),
                    child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                            color: _tk.surf2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _tk.bd)),
                        child: Icon(Icons.arrow_back_rounded,
                            color: _tk.txtHead, size: 20)),
                  ),
                  const SizedBox(width: 14),
                  Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [
                                _tk.violet,
                                _tk.violet.withOpacity(0.7)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: _tk.violet.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]),
                      child: const Icon(Icons.manage_accounts_rounded,
                          color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('User Accounts',
                                style: TextStyle(
                                    color: _tk.txtHead,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4)),
                            Text('Approve, block, promote or delete accounts',
                                style: TextStyle(
                                    color: _tk.txtMuted, fontSize: 12)),
                          ])),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                            color: _tk.surf2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _tk.bd)),
                        child: Icon(Icons.refresh_rounded,
                            color: _tk.txtMuted, size: 18)),
                  ),
                ]),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tab,
                  labelColor: _tk.violet,
                  unselectedLabelColor: _tk.txtMuted,
                  indicatorColor: _tk.violet,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: [
                    // ── Pending tab shows live badge count ─────────────────
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Pending'),
                          if (_pending.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFFEF4444)
                                          .withOpacity(0.45),
                                      blurRadius: 6)
                                ],
                              ),
                              child: Text(
                                _pending.length > 99
                                    ? '99+'
                                    : '${_pending.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(text: 'All Accounts (${_allUsers.length})'),
                  ],
                ),
              ])),
        ),

        Expanded(
            child: _loading
                ? Center(
                child: CircularProgressIndicator(color: _tk.violet))
                : TabBarView(controller: _tab, children: [
              _buildPendingList(),
              _buildAllAccountsList(),
            ])),
      ]),
    );
  }

  Widget _buildPendingList() {
    if (_pending.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline_rounded,
                color: _tk.txtMuted.withOpacity(0.3), size: 52),
            const SizedBox(height: 12),
            Text('No pending requests',
                style: TextStyle(color: _tk.txtMuted, fontSize: 14)),
          ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pending.length,
      itemBuilder: (_, i) {
        final u = _pending[i];
        return _UserCard(
          user: u,
          mode: _CardMode.pending,
          onApprove: () => _setStatus(u['id'] as int, 'approved'),
          onReject:  () => _setStatus(u['id'] as int, 'rejected'),
          onBlock:   () {},
          onUnblock: () {},
          onDelete:  () => _deleteUser(u['id'] as int,
              u['full_name'] ?? u['username'] ?? 'this user'),
          onRemovePhoto: () => _removePhoto(u['id'] as int),
          onPermissions: () => _showPermissionsDialog(u),
        );
      },
    );
  }

  Widget _buildAllAccountsList() {
    if (_allUsers.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.group_outlined,
                color: _tk.txtMuted.withOpacity(0.3), size: 52),
            const SizedBox(height: 12),
            Text('No accounts found',
                style: TextStyle(color: _tk.txtMuted, fontSize: 14)),
          ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allUsers.length,
      itemBuilder: (_, i) {
        final u = _allUsers[i];
        return _UserCard(
          user: u,
          mode: _CardMode.manage,
          onApprove:     () => _setStatus(u['id'] as int, 'approved'),
          onReject:      () => _setStatus(u['id'] as int, 'rejected'),
          onBlock:       () => _setStatus(u['id'] as int, 'blocked'),
          onUnblock:     () => _setStatus(u['id'] as int, 'approved'),
          onDelete:      () => _deleteUser(u['id'] as int,
              u['full_name'] ?? u['username'] ?? 'this user'),
          onRemovePhoto: () => _removePhoto(u['id'] as int),
          onPermissions: () => _showPermissionsDialog(u),
        );
      },
    );
  }
}

// ── Role chip ─────────────────────────────────────────────────────────────────
class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _RoleChip({
    required this.label, required this.icon,
    required this.selected, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : tk.surf2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: selected ? color.withOpacity(0.45) : tk.bd,
              width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? color : tk.txtMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: selected ? color : tk.txt,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5))),
          if (selected)
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 12),
            ),
        ]),
      ),
    );
  }
}

// ── Permission toggle row ─────────────────────────────────────────────────────
class _PermToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  const _PermToggle({
    required this.icon, required this.label, required this.sublabel,
    required this.value, required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.07) : tk.surf2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
            color: value ? color.withOpacity(0.35) : tk.bd,
            width: value ? 1.5 : 1),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(value ? 0.15 : 0.07),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      color: tk.txtHead,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text(sublabel,
                  style: TextStyle(color: tk.txtMuted, fontSize: 11.5)),
            ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
        ),
      ]),
    );
  }
}

enum _CardMode { pending, manage }

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final _CardMode mode;
  final VoidCallback onApprove, onReject, onBlock, onUnblock,
      onDelete, onRemovePhoto, onPermissions;

  const _UserCard({
    required this.user,
    required this.mode,
    required this.onApprove,
    required this.onReject,
    required this.onBlock,
    required this.onUnblock,
    required this.onDelete,
    required this.onRemovePhoto,
    required this.onPermissions,
  });

  @override
  Widget build(BuildContext context) {
    final tk      = context.tk;
    final name    = user['full_name'] as String? ?? user['username'] as String? ?? '—';
    final uname   = user['username']  as String? ?? '—';
    final role    = user['role']   as String? ?? 'user';
    final status  = user['status'] as String? ?? 'pending';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final isBlocked   = status == 'blocked';
    final isSubAdmin  = role == 'sub_admin';

    Color roleColor; String roleLabel;
    switch (role) {
      case 'admin':     roleColor = tk.violet; roleLabel = 'Admin'; break;
      case 'sub_admin': roleColor = tk.cyan;   roleLabel = 'Sub-Admin'; break;
      default:          roleColor = tk.blue;   roleLabel = 'User';
    }

    Color statusColor; String statusLabel; IconData statusIcon;
    switch (status) {
      case 'approved': statusColor = const Color(0xFF059669); statusLabel = 'Approved'; statusIcon = Icons.verified_rounded; break;
      case 'rejected': statusColor = const Color(0xFFDC2626); statusLabel = 'Rejected'; statusIcon = Icons.cancel_rounded; break;
      case 'blocked':  statusColor = const Color(0xFF6B7280); statusLabel = 'Blocked';  statusIcon = Icons.block_rounded; break;
      default:         statusColor = const Color(0xFFD97706); statusLabel = 'Pending';  statusIcon = Icons.hourglass_empty_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isBlocked
            ? (tk.dark ? const Color(0xFF0F1923) : const Color(0xFFF9FAFB))
            : tk.surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isBlocked
                ? const Color(0xFF6B7280).withOpacity(0.3)
                : tk.bd),
        boxShadow: tk.shadowSm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isBlocked
                      ? [const Color(0xFF6B7280), const Color(0xFF4B5563)]
                      : isSubAdmin
                      ? [tk.cyan, tk.cyan.withOpacity(0.7)]
                      : [tk.blue, const Color(0xFF1A5EC4)],
                ),
              ),
              child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (isBlocked)
                          Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.block_rounded,
                                  color: const Color(0xFF6B7280), size: 14)),
                        Expanded(
                            child: Text(name,
                                style: TextStyle(
                                    color: isBlocked ? tk.txtMuted : tk.txtHead,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    decoration: isBlocked
                                        ? TextDecoration.lineThrough
                                        : null))),
                      ]),
                      Text('@$uname',
                          style: TextStyle(color: tk.txtMuted, fontSize: 12.5)),
                      if (isSubAdmin) ...[
                        const SizedBox(height: 5),
                        Wrap(spacing: 5, runSpacing: 4, children: [
                          if (user['perm_admin'] == true)
                            _MiniPill('Panel', tk.violet),
                          if (user['perm_edit_reports'] == true)
                            _MiniPill('Reports', tk.green),
                          if (user['perm_admin'] != true &&
                              user['perm_edit_reports'] != true)
                            _MiniPill('No permissions', tk.txtMuted),
                        ]),
                      ],
                    ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withOpacity(0.30))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, size: 11, color: statusColor),
                  const SizedBox(width: 4),
                  Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 5),
              DsTag(roleLabel, roleColor),
            ]),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(children: [
            Divider(color: tk.bd, height: 1),
            const SizedBox(height: 12),
            if (mode == _CardMode.pending) ...[
              Row(children: [
                Expanded(child: _ActionBtn(
                  label: 'Approve', icon: Icons.check_rounded,
                  color: const Color(0xFF059669), onTap: onApprove,
                )),
                const SizedBox(width: 8),
                Expanded(child: _ActionBtn(
                  label: 'Reject', icon: Icons.close_rounded,
                  color: const Color(0xFFDC2626), onTap: onReject,
                )),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: 'Delete', icon: Icons.delete_forever_rounded,
                  color: const Color(0xFF6B7280),
                  onTap: onDelete, compact: true,
                ),
              ]),
            ] else ...[
              Row(children: [
                if (!isBlocked) ...[
                  Expanded(child: _ActionBtn(
                    label: 'Block', icon: Icons.block_rounded,
                    color: const Color(0xFF6B7280), onTap: onBlock,
                  )),
                ] else ...[
                  Expanded(child: _ActionBtn(
                    label: 'Unblock', icon: Icons.lock_open_rounded,
                    color: const Color(0xFF059669), onTap: onUnblock,
                  )),
                ],
                const SizedBox(width: 8),
                _ActionBtn(
                  label: 'Roles', icon: Icons.shield_rounded,
                  color: tk.violet, onTap: onPermissions, compact: true,
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: 'No Photo', icon: Icons.no_photography_rounded,
                  color: const Color(0xFFD97706),
                  onTap: onRemovePhoto, compact: true,
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: 'Delete', icon: Icons.delete_forever_rounded,
                  color: const Color(0xFFDC2626),
                  onTap: onDelete, compact: true,
                ),
              ]),
              if (status == 'rejected') ...[
                const SizedBox(height: 8),
                _ActionBtn(
                  label: 'Approve Account',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF059669),
                  onTap: onApprove, fullWidth: true,
                ),
              ],
            ],
          ]),
        ),
      ]),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniPill(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.30)),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

class _ActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool compact;
  final bool fullWidth;
  const _ActionBtn({
    required this.label, required this.icon,
    required this.color, required this.onTap,
    this.compact = false, this.fullWidth = false,
  });
  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 36,
          width: widget.fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 12 : 0),
          decoration: BoxDecoration(
            color: _hov
                ? widget.color.withOpacity(0.16)
                : widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: widget.color.withOpacity(_hov ? 0.45 : 0.25)),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.color, size: 15),
                const SizedBox(width: 5),
                Text(widget.label,
                    style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5)),
              ]),
        ),
      ),
    );
  }
}