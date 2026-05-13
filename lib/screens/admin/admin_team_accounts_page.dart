// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  AdminTeamAccountsPage — Create / Edit / Delete team mobile accounts       ║
// ║  Auth strategy: pure profiles-table login (NO Supabase Auth / NO email)    ║
// ║                                                                              ║
// ║  HOW IT WORKS (web-compatible version):                                      ║
// ║  • Passwords are hashed with SHA-256 + a fixed app salt (via `crypto` pkg)  ║
// ║  • This replaces bcrypt which is NOT supported on Flutter Web               ║
// ║  • Stored in profiles.password_hash (text column)                           ║
// ║  • Login screen must also use _hashPassword() — see login note below        ║
// ║                                                                              ║
// ║  ⚠️  MIGRATION NOTE:                                                         ║
// ║  If you previously used bcrypt hashes, those existing passwords will NOT    ║
// ║  match the new SHA-256 hashes. Reset all team account passwords after       ║
// ║  switching to this version.                                                  ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// ── REQUIRED pubspec.yaml dependency ─────────────────────────────────────────
//   crypto: ^3.0.3        # replaces bcrypt — works on web + mobile + desktop
//
// ── REMOVE from pubspec.yaml ──────────────────────────────────────────────────
//   # bcrypt: ^1.1.3      ← delete this line
//
// ── LOGIN SCREEN CHANGE (login_screen.dart) ───────────────────────────────────
//   Add these imports:
//     import 'dart:convert';
//     import 'package:crypto/crypto.dart';
//
//   Add this helper (copy from bottom of this file):
//     String _hashPassword(String password) { ... }
//
//   Replace BCrypt.checkpw(...) with:
//     final ok = _hashPassword(password) == res['password_hash'];

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/widgets/ds.dart';

// ── Password hashing helper (SHA-256 + fixed salt) ───────────────────────────
// Copy this function to login_screen.dart as well so login verification matches.
String _hashPassword(String password) {
  // A fixed salt makes rainbow-table attacks harder while staying web-compatible.
  // Change 'spcwd_2025_salt' to any unique string for your deployment.
  const salt = 'spcwd_2025_salt';
  final bytes = utf8.encode('$salt:$password');
  return sha256.convert(bytes).toString();
}

class AdminTeamAccountsPage extends StatefulWidget {
  final VoidCallback? onBack;
  const AdminTeamAccountsPage({super.key, this.onBack});

  @override
  State<AdminTeamAccountsPage> createState() => _AdminTeamAccountsPageState();
}

class _AdminTeamAccountsPageState extends State<AdminTeamAccountsPage> {
  Tk get _tk => context.tk;

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _teams    = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final profilesRes = await _sb
          .from('profiles')
          .select('id, username, full_name, role, team_id, created_at')
          .eq('role', 'user')
          .order('created_at', ascending: false);

      final teamsRes = await _sb
          .from('teams')
          .select('id, team_name')
          .order('team_name');

      if (!mounted) return;
      setState(() {
        _accounts = List<Map<String, dynamic>>.from(profilesRes);
        _teams    = List<Map<String, dynamic>>.from(teamsRes);
        _filtered = List.from(_accounts);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Error loading accounts: $e', error: true);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_accounts)
          : _accounts.where((a) {
        final user = (a['username'] as String? ?? '').toLowerCase();
        final name = (a['full_name'] as String? ?? '').toLowerCase();
        final team = _teamName(a['team_id']).toLowerCase();
        return user.contains(q) || name.contains(q) || team.contains(q);
      }).toList();
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _teamName(dynamic teamId) {
    if (teamId == null) return 'No team';
    final t = _teams.firstWhere(
          (t) => t['id'] == teamId,
      orElse: () => {'team_name': 'Unknown'},
    );
    return t['team_name'] as String? ?? 'Unknown';
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _tk.red : _tk.green,
    ));
  }

  // ── CREATE ────────────────────────────────────────────────────────────────
  Future<void> _createAccount({
    required String username,
    required String fullName,
    required String password,
    required String? teamId,
  }) async {
    final cleanUsername = username.trim().toLowerCase();

    try {
      // 1. Check username is not already taken
      final existing = await _sb
          .from('profiles')
          .select('id')
          .eq('username', cleanUsername)
          .maybeSingle();

      if (existing != null) {
        _snack('Username "$cleanUsername" is already taken', error: true);
        return;
      }

      // 2. Hash password with SHA-256 (web + mobile compatible)
      final hash = _hashPassword(password);

      // 3. Insert profile row
      await _sb.from('profiles').insert({
        'username':      cleanUsername,
        'full_name':     fullName.trim(),
        'role':          'user',
        'team_id':       teamId,
        'password_hash': hash,
      });

      _snack('Account "$cleanUsername" created!');
      await _load();
    } catch (e) {
      _snack('Error creating account: $e', error: true);
    }
  }

  // ── UPDATE PROFILE ────────────────────────────────────────────────────────
  Future<void> _updateProfile({
    required String id,
    required String username,
    required String fullName,
    required String? teamId,
  }) async {
    try {
      await _sb.from('profiles').update({
        'username':  username.trim().toLowerCase(),
        'full_name': fullName.trim(),
        'team_id':   teamId,
      }).eq('id', id);
      _snack('Account updated!');
      await _load();
    } catch (e) {
      _snack('Update failed: $e', error: true);
    }
  }

  // ── RESET PASSWORD ────────────────────────────────────────────────────────
  Future<void> _resetPassword({
    required String id,
    required String username,
    required String newPassword,
  }) async {
    try {
      final hash = _hashPassword(newPassword);
      await _sb.from('profiles').update({
        'password_hash': hash,
      }).eq('id', id);
      _snack('Password reset for "@$username"!');
    } catch (e) {
      _snack('Password reset failed: $e', error: true);
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<void> _deleteAccount(String id, String username) async {
    final ok = await _confirmDialog(
      icon: Icons.person_remove_rounded,
      iconColor: _tk.red,
      title: 'Delete Account?',
      body: 'This will permanently remove the account for "@$username".\n'
          'The team member will no longer be able to log in.',
      confirmLabel: 'Delete',
      confirmColor: _tk.red,
    );
    if (ok != true) return;

    try {
      await _sb.from('profiles').delete().eq('id', id);
      _snack('Account "@$username" deleted.');
      await _load();
    } catch (e) {
      _snack('Delete failed: $e', error: true);
    }
  }

  // ── SHOW CREATE DIALOG ────────────────────────────────────────────────────
  void _showCreateDialog() {
    final usernameCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmCtrl  = TextEditingController();
    String? selectedTeamId;
    bool obscurePw  = true;
    bool obscureCon = true;
    bool saving     = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: 520, maxHeight: 720),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Scaffold(
                backgroundColor: _tk.bg,
                body: Column(children: [
                  _dialogHeader('Create Team Account',
                      Icons.person_add_rounded, _tk.green,
                          () => Navigator.pop(ctx)),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoBanner(
                              icon: Icons.info_outline_rounded,
                              color: _tk.blue,
                              bg: _tk.blueBg,
                              text:
                              'No email required. Members log in with their '
                                  'username and password only.',
                            ),
                            const SizedBox(height: 18),

                            _fieldLabel('Assign to Team'),
                            _teamDropdown(
                              value: selectedTeamId,
                              onChanged: (v) =>
                                  setS(() => selectedTeamId = v),
                            ),

                            const SizedBox(height: 18),
                            _fieldLabel('Full Name'),
                            TextField(
                              controller: fullNameCtrl,
                              style: TextStyle(
                                  color: _tk.txtHead, fontSize: 14),
                              decoration: dsInputOf(context, '',
                                  hint: 'e.g. Team Alpha',
                                  icon: Icons.badge_rounded),
                            ),

                            const SizedBox(height: 18),
                            _fieldLabel('Username *'),
                            TextField(
                              controller: usernameCtrl,
                              style: TextStyle(
                                  color: _tk.txtHead, fontSize: 14),
                              autocorrect: false,
                              onChanged: (v) {
                                final clean = v
                                    .toLowerCase()
                                    .replaceAll(RegExp(r'[^a-z0-9_]'), '');
                                if (v != clean) {
                                  usernameCtrl.value =
                                      usernameCtrl.value.copyWith(
                                        text: clean,
                                        selection: TextSelection.collapsed(
                                            offset: clean.length),
                                      );
                                }
                              },
                              decoration: dsInputOf(context, '',
                                  hint:
                                  'e.g. team_alpha (letters, numbers, _)',
                                  icon: Icons.alternate_email_rounded),
                            ),

                            const SizedBox(height: 18),
                            _fieldLabel('Password *'),
                            TextField(
                              controller: passwordCtrl,
                              obscureText: obscurePw,
                              style: TextStyle(
                                  color: _tk.txtHead, fontSize: 14),
                              decoration: dsInputOf(context, '',
                                  hint: 'Min. 6 characters',
                                  icon: Icons.lock_rounded,
                                  suffix: GestureDetector(
                                    onTap: () =>
                                        setS(() => obscurePw = !obscurePw),
                                    child: Icon(
                                      obscurePw
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: _tk.txtMuted,
                                      size: 18,
                                    ),
                                  )),
                            ),

                            const SizedBox(height: 14),
                            _fieldLabel('Confirm Password *'),
                            TextField(
                              controller: confirmCtrl,
                              obscureText: obscureCon,
                              style: TextStyle(
                                  color: _tk.txtHead, fontSize: 14),
                              decoration: dsInputOf(context, '',
                                  hint: 'Re-enter password',
                                  icon: Icons.lock_outline_rounded,
                                  suffix: GestureDetector(
                                    onTap: () =>
                                        setS(() => obscureCon = !obscureCon),
                                    child: Icon(
                                      obscureCon
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: _tk.txtMuted,
                                      size: 18,
                                    ),
                                  )),
                            ),
                          ]),
                    ),
                  ),

                  _dialogFooter(
                    onCancel: () => Navigator.pop(ctx),
                    onSave: saving
                        ? null
                        : () async {
                      final username =
                      usernameCtrl.text.trim().toLowerCase();
                      final fullName = fullNameCtrl.text.trim();
                      final pw   = passwordCtrl.text;
                      final conf = confirmCtrl.text;

                      if (username.isEmpty) {
                        _snack('Username is required', error: true);
                        return;
                      }
                      if (pw.length < 6) {
                        _snack(
                            'Password must be at least 6 characters',
                            error: true);
                        return;
                      }
                      if (pw != conf) {
                        _snack('Passwords do not match', error: true);
                        return;
                      }

                      setS(() => saving = true);
                      await _createAccount(
                        username: username,
                        fullName: fullName,
                        password: pw,
                        teamId: selectedTeamId,
                      );
                      if (mounted) Navigator.pop(ctx);
                    },
                    saveLabel: 'Create Account',
                    accent: _tk.green,
                    saving: saving,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── SHOW EDIT DIALOG ──────────────────────────────────────────────────────
  void _showEditDialog(Map<String, dynamic> account) {
    final usernameCtrl =
    TextEditingController(text: account['username'] ?? '');
    final fullNameCtrl =
    TextEditingController(text: account['full_name'] ?? '');
    String? selectedTeamId = account['team_id'];
    bool saving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: 520, maxHeight: 640),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Scaffold(
                backgroundColor: _tk.bg,
                body: Column(children: [
                  _dialogHeader('Edit Account',
                      Icons.manage_accounts_rounded, _tk.blue,
                          () => Navigator.pop(ctx)),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoBanner(
                              icon: Icons.lock_reset_rounded,
                              color: _tk.blue,
                              bg: _tk.blueBg,
                              text:
                              'To reset the password, use the '
                                  '"Reset Password" button on the account card.',
                            ),

                            const SizedBox(height: 18),
                            _fieldLabel('Assign to Team'),
                            _teamDropdown(
                              value: selectedTeamId,
                              onChanged: (v) =>
                                  setS(() => selectedTeamId = v),
                            ),

                            const SizedBox(height: 18),
                            _fieldLabel('Full Name'),
                            TextField(
                              controller: fullNameCtrl,
                              style: TextStyle(
                                  color: _tk.txtHead, fontSize: 14),
                              decoration: dsInputOf(context, '',
                                  hint: 'Display name',
                                  icon: Icons.badge_rounded),
                            ),

                            const SizedBox(height: 18),
                            _fieldLabel('Username'),
                            TextField(
                              controller: usernameCtrl,
                              style: TextStyle(
                                  color: _tk.txtHead, fontSize: 14),
                              autocorrect: false,
                              decoration: dsInputOf(context, '',
                                  hint: 'username',
                                  icon: Icons.alternate_email_rounded),
                            ),
                          ]),
                    ),
                  ),

                  _dialogFooter(
                    onCancel: () => Navigator.pop(ctx),
                    onSave: saving
                        ? null
                        : () async {
                      final username =
                      usernameCtrl.text.trim().toLowerCase();
                      if (username.isEmpty) {
                        _snack('Username is required', error: true);
                        return;
                      }
                      setS(() => saving = true);
                      await _updateProfile(
                        id: account['id'] as String,
                        username: username,
                        fullName: fullNameCtrl.text.trim(),
                        teamId: selectedTeamId,
                      );
                      if (mounted) Navigator.pop(ctx);
                    },
                    saveLabel: 'Save Changes',
                    accent: _tk.blue,
                    saving: saving,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── SHOW RESET PASSWORD DIALOG ────────────────────────────────────────────
  void _showResetPasswordDialog(Map<String, dynamic> account) {
    final newPwCtrl   = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureNew   = true;
    bool obscureCon   = true;
    bool saving       = false;
    final username    = account['username'] as String? ?? '';

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: 520, maxHeight: 500),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Scaffold(
                backgroundColor: _tk.bg,
                body: Column(children: [
                  _dialogHeader('Reset Password',
                      Icons.lock_reset_rounded, _tk.amber,
                          () => Navigator.pop(ctx)),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoBanner(
                              icon: Icons.alternate_email_rounded,
                              color: _tk.amber,
                              bg: _tk.amberBg,
                              text: 'Resetting password for @$username.',
                            ),
                            const SizedBox(height: 18),

                            _fieldLabel('New Password *'),
                            TextField(
                              controller: newPwCtrl,
                              obscureText: obscureNew,
                              style: TextStyle(
                                  color: _tk.txtHead, fontSize: 14),
                              decoration: dsInputOf(context, '',
                                  hint: 'Min. 6 characters',
                                  icon: Icons.lock_rounded,
                                  suffix: GestureDetector(
                                    onTap: () => setS(
                                            () => obscureNew = !obscureNew),
                                    child: Icon(
                                      obscureNew
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: _tk.txtMuted,
                                      size: 18,
                                    ),
                                  )),
                            ),

                            const SizedBox(height: 14),
                            _fieldLabel('Confirm New Password *'),
                            TextField(
                              controller: confirmCtrl,
                              obscureText: obscureCon,
                              style: TextStyle(
                                  color: _tk.txtHead, fontSize: 14),
                              decoration: dsInputOf(context, '',
                                  hint: 'Re-enter new password',
                                  icon: Icons.lock_outline_rounded,
                                  suffix: GestureDetector(
                                    onTap: () => setS(
                                            () => obscureCon = !obscureCon),
                                    child: Icon(
                                      obscureCon
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: _tk.txtMuted,
                                      size: 18,
                                    ),
                                  )),
                            ),
                          ]),
                    ),
                  ),

                  _dialogFooter(
                    onCancel: () => Navigator.pop(ctx),
                    onSave: saving
                        ? null
                        : () async {
                      final pw   = newPwCtrl.text;
                      final conf = confirmCtrl.text;
                      if (pw.length < 6) {
                        _snack(
                            'Password must be at least 6 characters',
                            error: true);
                        return;
                      }
                      if (pw != conf) {
                        _snack('Passwords do not match', error: true);
                        return;
                      }
                      setS(() => saving = true);
                      await _resetPassword(
                        id: account['id'] as String,
                        username: username,
                        newPassword: pw,
                      );
                      if (mounted) Navigator.pop(ctx);
                    },
                    saveLabel: 'Reset Password',
                    accent: _tk.amber,
                    saving: saving,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── SHARED WIDGETS ────────────────────────────────────────────────────────

  Widget _infoBanner({
    required IconData icon,
    required Color color,
    required Color bg,
    required String text,
  }) =>
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontSize: 11.5)),
          ),
        ]),
      );

  Widget _dialogHeader(
      String title,
      IconData icon,
      Color accent,
      VoidCallback onClose,
      ) =>
      Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
        decoration: BoxDecoration(
          color: _tk.surf,
          border: Border(bottom: BorderSide(color: _tk.bd)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: _tk.txtHead,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _tk.bd.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close_rounded,
                  color: _tk.txtMuted, size: 16),
            ),
          ),
        ]),
      );

  Widget _dialogFooter({
    required VoidCallback onCancel,
    required VoidCallback? onSave,
    required String saveLabel,
    required Color accent,
    bool saving = false,
  }) =>
      Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
        decoration: BoxDecoration(
          color: _tk.surf,
          border: Border(top: BorderSide(color: _tk.bd)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: onCancel,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: _tk.surf2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _tk.bd),
              ),
              child: Center(
                child: Text('Cancel',
                    style: TextStyle(
                        color: _tk.txt,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onSave,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 46,
                decoration: BoxDecoration(
                  gradient: onSave != null
                      ? LinearGradient(
                    colors: [accent, accent.withOpacity(0.82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: onSave == null ? _tk.bd : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: onSave != null
                      ? [
                    BoxShadow(
                        color: accent.withOpacity(0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                      : null,
                ),
                child: Center(
                  child: saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 7),
                    Text(saveLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      );

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: TextStyle(
            color: _tk.txtHead,
            fontSize: 13,
            fontWeight: FontWeight.w600)),
  );

  Widget _teamDropdown({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: _tk.surf,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _tk.bd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value,
            isExpanded: true,
            dropdownColor: _tk.surf,
            style: TextStyle(color: _tk.txtHead, fontSize: 14),
            hint: Text('— No team assigned —',
                style: TextStyle(color: _tk.txtMuted)),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('— No team assigned —',
                    style: TextStyle(color: _tk.txtMuted)),
              ),
              ..._teams.map((t) => DropdownMenuItem<String?>(
                value: t['id'] as String?,
                child:
                Text(t['team_name'] as String? ?? 'Unnamed'),
              )),
            ],
            onChanged: onChanged,
          ),
        ),
      );

  Future<bool?> _confirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: _tk.surf,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _tk.bd)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border:
                  Border.all(color: iconColor.withOpacity(0.25)),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(
                      color: _tk.txtHead,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _tk.txtMuted,
                      fontSize: 13.5,
                      height: 1.5)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                          color: _tk.surf2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _tk.bd)),
                      child: Center(
                        child: Text('Cancel',
                            style: TextStyle(
                                color: _tk.txt,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            confirmColor,
                            confirmColor.withOpacity(0.82)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: confirmColor.withOpacity(0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Center(
                        child: Text(confirmLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      );

  // ── ACCOUNT CARD ──────────────────────────────────────────────────────────
  Widget _buildAccountCard(Map<String, dynamic> account) {
    final username = account['username'] as String? ?? '—';
    final fullName = account['full_name'] as String? ?? '';
    final teamId   = account['team_id'];
    final teamName = _teamName(teamId);
    final hasTeam  = teamId != null;
    final initial  = username.isNotEmpty ? username[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _tk.surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tk.bd),
        boxShadow: _tk.shadowSm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_tk.green, _tk.green.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _tk.green.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName.isNotEmpty ? fullName : '@$username',
                    style: TextStyle(
                        color: _tk.txtHead,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text('@$username',
                      style:
                      TextStyle(color: _tk.txtMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasTeam
                          ? _tk.green.withOpacity(0.10)
                          : _tk.amberBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasTeam
                            ? _tk.green.withOpacity(0.30)
                            : _tk.amber.withOpacity(0.30),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        hasTeam
                            ? Icons.groups_rounded
                            : Icons.warning_amber_rounded,
                        color: hasTeam ? _tk.green : _tk.amber,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(teamName,
                          style: TextStyle(
                            color: hasTeam ? _tk.green : _tk.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                    ]),
                  ),
                ]),
          ),

          // Action buttons
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onTap: () => _showEditDialog(account),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _tk.blueBg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _tk.blue.withOpacity(0.25)),
                ),
                child: Icon(Icons.edit_rounded, color: _tk.blue, size: 15),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _showResetPasswordDialog(account),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _tk.amberBg,
                  borderRadius: BorderRadius.circular(9),
                  border:
                  Border.all(color: _tk.amber.withOpacity(0.25)),
                ),
                child: Icon(Icons.lock_reset_rounded,
                    color: _tk.amber, size: 15),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () =>
                  _deleteAccount(account['id'] as String, username),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _tk.redBg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _tk.red.withOpacity(0.25)),
                ),
                child:
                Icon(Icons.delete_rounded, color: _tk.red, size: 15),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tk = _tk;

    return Scaffold(
      backgroundColor: tk.bg,
      body: Column(children: [
        DsHeader(
          title: 'Team Mobile Accounts',
          subtitle: 'Username-only logins • No email required',
          icon: Icons.phone_android_rounded,
          accent: tk.green,
          actions: [
            GestureDetector(
              onTap: _load,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tk.surf2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tk.bd),
                ),
                child: Icon(Icons.refresh_rounded,
                    color: tk.txtMuted, size: 18),
              ),
            ),
            GestureDetector(
              onTap: () => widget.onBack != null
                  ? widget.onBack!()
                  : Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tk.surf2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tk.bd),
                ),
                child: Icon(Icons.arrow_back_rounded,
                    color: tk.txtMuted, size: 20),
              ),
            ),
          ],
        ),

        // Stats strip
        if (!_isLoading)
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            color: tk.surf,
            child: Row(children: [
              _statChip(
                icon: Icons.people_rounded,
                label:
                '${_accounts.length} account${_accounts.length == 1 ? '' : 's'}',
                color: tk.blue,
                bg: tk.blueBg,
              ),
              const SizedBox(width: 10),
              _statChip(
                icon: Icons.groups_rounded,
                label:
                '${_accounts.where((a) => a['team_id'] != null).length} assigned',
                color: tk.green,
                bg: tk.greenBg,
              ),
              const SizedBox(width: 10),
              _statChip(
                icon: Icons.warning_amber_rounded,
                label:
                '${_accounts.where((a) => a['team_id'] == null).length} unassigned',
                color: tk.amber,
                bg: tk.amberBg,
              ),
            ]),
          ),

        // Search + Create
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
          child: Row(children: [
            Expanded(
              child: DsSearchBar(
                controller: _searchCtrl,
                hint: 'Search by username, name or team…',
                onClear: _filter,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _showCreateDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tk.green, tk.green.withOpacity(0.82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: tk.green.withOpacity(0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 17),
                  SizedBox(width: 7),
                  Text('Create Account',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const DsLoading()
              : _filtered.isEmpty
              ? DsEmpty(
            message: _accounts.isEmpty
                ? 'No team accounts yet.\nTap "Create Account" to add one.'
                : 'No matching accounts.',
            icon: Icons.phone_android_outlined,
          )
              : RefreshIndicator(
            onRefresh: _load,
            color: tk.green,
            child: ListView.builder(
              padding:
              const EdgeInsets.fromLTRB(24, 4, 24, 32),
              itemCount: _filtered.length,
              itemBuilder: (_, i) =>
                  _buildAccountCard(_filtered[i]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) =>
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}