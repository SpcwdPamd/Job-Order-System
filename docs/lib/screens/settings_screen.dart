import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/session/session.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:job_order/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _isDark = themeNotifier.isDark;
    themeNotifier.addListener(_onTheme);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() {
    if (mounted) setState(() => _isDark = themeNotifier.isDark);
  }

  void _openEditProfile() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => const _EditProfileDialog(),
    ).then((_) => setState(() {})); // refresh to show updated name
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Scaffold(
      backgroundColor: tk.bg,
      body: Column(children: [
        DsHeader(
          title: 'Settings',
          subtitle: 'Appearance, data & account',
          icon: Icons.tune_rounded,
          accent: tk.blue,
        ),
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── PROFILE ──────────────────────────────────────────────────────
            const DsLabel('Profile'),
            _ProfileCard(onEditTap: _openEditProfile),
            const SizedBox(height: 28),

            // ── APPEARANCE ───────────────────────────────────────────────────
            const DsLabel('Appearance'),
            _AppearanceCard(isDark: _isDark, onToggle: themeNotifier.toggle),
            const SizedBox(height: 28),

            // ── ABOUT ────────────────────────────────────────────────────────
            const DsLabel('About'),
            _AboutCard(),
            const SizedBox(height: 28),

            // ── ACCOUNT ──────────────────────────────────────────────────────
            const DsLabel('Account'),
            _SignOutTile(),
            const SizedBox(height: 40),

            // ── APP INFO ─────────────────────────────────────────────────────
            Center(child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: tk.blueBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: tk.blueBd),
                  boxShadow: tk.shadowSm,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                            color: tk.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.asset('assets/images/seal.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SPCWD Job Order System',
                        style: TextStyle(
                            color: tk.txtHead,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text('Version 4.0  ·  ${_isDark ? "Dark" : "Light"} Edition',
                        style: TextStyle(color: tk.txtMuted, fontSize: 11)),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
              Text('San Pablo City Water District',
                  style: TextStyle(
                      color: tk.txtMuted.withOpacity(0.6), fontSize: 11)),
            ])),
          ]),
        )),
      ]),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String sub,
      Color accent, VoidCallback onTap) {
    final tk = context.tk;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tk.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tk.bd),
            boxShadow: tk.shadowSm,
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.18)),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      color: tk.txtHead,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(sub, style: TextStyle(color: tk.txtMuted, fontSize: 12.5)),
            ])),
            Icon(Icons.chevron_right_rounded, color: tk.bd2, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Profile Card
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final VoidCallback onEditTap;
  const _ProfileCard({required this.onEditTap});

  @override
  Widget build(BuildContext context) {
    final tk      = context.tk;
    final sess    = AppSession.instance;
    final name    = sess.fullName ?? 'Unknown';
    final uname   = sess.username ?? '';
    final initial = sess.initial;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tk.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tk.bd),
        boxShadow: tk.shadowSm,
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: TextStyle(
                  color: tk.txtHead,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Row(children: [
            Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 5),
                decoration: const BoxDecoration(
                    color: Color(0xFF34D399), shape: BoxShape.circle)),
            Text('@$uname',
                style: TextStyle(color: tk.txtMuted, fontSize: 12.5)),
          ]),
        ])),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onEditTap,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: tk.blueBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tk.blueBd),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit_rounded, color: tk.blue, size: 15),
                const SizedBox(width: 6),
                Text('Edit Profile',
                    style: TextStyle(
                        color: tk.blue,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Edit Profile Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog();
  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey     = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _loading        = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: AppSession.instance.fullName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _success = null; });

    try {
      final uid     = AppSession.instance.userId;
      final newName = _nameCtrl.text.trim();
      final newPass = _passCtrl.text.trim();

      final Map<String, dynamic> updates = {'full_name': newName};
      if (newPass.isNotEmpty) updates['password'] = newPass;

      await Supabase.instance.client
          .from('users')
          .update(updates)
          .eq('id', uid!);

      // Update local session
      AppSession.instance.fullName = newName;

      if (!mounted) return;
      setState(() { _loading = false; _success = 'Profile updated successfully!'; });
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Failed to update. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Dialog(
      backgroundColor: tk.surf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: tk.blueBg,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: tk.blueBd),
                      ),
                      child: Icon(Icons.manage_accounts_rounded,
                          color: tk.blue, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit Profile',
                              style: TextStyle(
                                  color: tk.txtHead,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          Text('Update your name or password',
                              style: TextStyle(color: tk.txtMuted, fontSize: 12)),
                        ])),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                            color: tk.bd.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.close_rounded,
                            color: tk.txtMuted, size: 17),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 26),

                  // Full name
                  _dlgLabel(tk, 'Full Name'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(color: tk.txtHead, fontSize: 14),
                    decoration: _deco(tk,
                        hint: 'Your full name', icon: Icons.badge_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter your full name';
                      if (v.trim().length < 3) return 'At least 3 characters';
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // New password
                  _dlgLabel(tk, 'New Password'),
                  Text('Leave blank to keep current password',
                      style: TextStyle(color: tk.txtMuted, fontSize: 11)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    style: TextStyle(color: tk.txtHead, fontSize: 14),
                    decoration: _deco(tk,
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        suffix: GestureDetector(
                          onTap: () =>
                              setState(() => _obscurePass = !_obscurePass),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: tk.txtMuted, size: 19,
                            ),
                          ),
                        )),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length < 6)
                        return 'At least 6 characters';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Confirm password
                  _dlgLabel(tk, 'Confirm New Password'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    style: TextStyle(color: tk.txtHead, fontSize: 14),
                    decoration: _deco(tk,
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        suffix: GestureDetector(
                          onTap: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: tk.txtMuted, size: 19,
                            ),
                          ),
                        )),
                    validator: (v) {
                      if (_passCtrl.text.isNotEmpty && v != _passCtrl.text)
                        return 'Passwords do not match';
                      return null;
                    },
                  ),

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: tk.redBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tk.redBd),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline_rounded,
                            color: tk.red, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: TextStyle(
                                    color: tk.red, fontSize: 12.5))),
                      ]),
                    ),
                  ],

                  // Success
                  if (_success != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: Color(0xFF059669), size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_success!,
                                style: const TextStyle(
                                    color: Color(0xFF065F46), fontSize: 12.5))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 26),

                  // Action buttons
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: tk.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tk.bd2),
                        ),
                        child: Center(
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: tk.txtMuted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600))),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _loading ? null : _save,
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [tk.blue, const Color(0xFF1E40AF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: tk.blue.withOpacity(0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Center(
                              child: _loading
                                  ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                                  : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.save_rounded,
                                        color: Colors.white, size: 17),
                                    SizedBox(width: 7),
                                    Text('Save Changes',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                  ])),
                        ),
                      ),
                    )),
                  ]),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _dlgLabel(Tk tk, String t) => Text(t,
      style: TextStyle(
          color: tk.txtHead,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1));

  InputDecoration _deco(Tk tk,
      {required String hint, required IconData icon, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tk.txtMuted),
        prefixIcon: Icon(icon, color: tk.txtMuted, size: 19),
        suffixIcon: suffix,
        filled: true,
        fillColor: tk.surf,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: tk.bd)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: tk.bd)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: tk.blue, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: tk.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(color: tk.red, width: 1.8)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Appearance Card (preserved from original)
// ─────────────────────────────────────────────────────────────────────────────
class _AppearanceCard extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggle;
  const _AppearanceCard({required this.isDark, required this.onToggle});
  @override
  State<_AppearanceCard> createState() => _AppearanceCardState();
}

class _AppearanceCardState extends State<_AppearanceCard>
    with TickerProviderStateMixin {
  late AnimationController _toggleCtrl;
  late AnimationController _shineCtrl;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _toggleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _slideAnim = CurvedAnimation(
        parent: _toggleCtrl, curve: Curves.easeInOutBack);
    if (widget.isDark) _toggleCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_AppearanceCard old) {
    super.didUpdateWidget(old);
    if (widget.isDark != old.isDark) {
      widget.isDark ? _toggleCtrl.forward() : _toggleCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _toggleCtrl.dispose();
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AnimatedBuilder(
      animation: _toggleCtrl,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: tk.surf,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tk.bd),
            boxShadow: tk.shadowMd,
          ),
          child: Column(children: [
            // Preview band
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 140,
                child: Stack(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.isDark
                            ? [const Color(0xFF05090F), const Color(0xFF0D1827), const Color(0xFF080E1C)]
                            : [const Color(0xFFEBF3FF), const Color(0xFFF0F5FA), const Color(0xFFE6EEF9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: Size.infinite,
                    painter: _GridPainter(
                      color: widget.isDark
                          ? const Color(0xFF1E2E47).withOpacity(0.6)
                          : const Color(0xFFBDD6FF).withOpacity(0.5),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _shineCtrl,
                    builder: (_, __) => Positioned(
                      left: -200 + _shineCtrl.value * 600,
                      top: -40,
                      child: Transform.rotate(
                        angle: -math.pi / 6,
                        child: Container(
                          width: 60, height: 300,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(widget.isDark ? 0.04 : 0.18),
                              Colors.white.withOpacity(0),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 44, height: 100,
                        decoration: BoxDecoration(
                          color: widget.isDark ? const Color(0xFF05090F) : const Color(0xFF0E2A57),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: widget.isDark ? const Color(0xFF0C1525) : const Color(0xFF163872)),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(width: 22, height: 4, margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.9), borderRadius: BorderRadius.circular(2))),
                          ...List.generate(3, (_) => Container(
                              width: 22, height: 3, margin: const EdgeInsets.only(bottom: 5),
                              decoration: BoxDecoration(color: const Color(0xFF5A7FA8).withOpacity(0.5), borderRadius: BorderRadius.circular(2)))),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.isDark ? const Color(0xFF101827) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: widget.isDark ? const Color(0xFF1E2E47) : const Color(0xFFDDE6F0)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(children: [
                            Container(width: 30, height: 5,
                                decoration: BoxDecoration(
                                    color: widget.isDark ? const Color(0xFFEDF2FF) : const Color(0xFF0D1F3C),
                                    borderRadius: BorderRadius.circular(3))),
                            const Spacer(),
                            Container(width: 28, height: 10,
                                decoration: BoxDecoration(
                                  color: widget.isDark ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFF1D6FE8).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: widget.isDark ? const Color(0xFF3B82F6).withOpacity(0.4) : const Color(0xFF1D6FE8).withOpacity(0.3)),
                                )),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Row(children: List.generate(3, (i) {
                          final colors = [const Color(0xFFD97706), const Color(0xFF059669), const Color(0xFF1D6FE8)];
                          return Expanded(child: Container(
                            margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                            height: 40,
                            decoration: BoxDecoration(
                              color: widget.isDark ? const Color(0xFF101827) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: widget.isDark ? const Color(0xFF1E2E47) : const Color(0xFFDDE6F0)),
                            ),
                            child: Center(child: Container(width: 18, height: 4,
                                decoration: BoxDecoration(color: colors[i].withOpacity(0.7), borderRadius: BorderRadius.circular(2)))),
                          ));
                        })),
                      ])),
                    ]),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _ThemeTile(
                    label: 'Light', icon: Icons.wb_sunny_rounded,
                    accent: const Color(0xFFD97706),
                    isSelected: !widget.isDark, isDarkUI: widget.isDark,
                    onTap: () { if (widget.isDark) widget.onToggle(); },
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _ThemeTile(
                    label: 'Dark', icon: Icons.dark_mode_rounded,
                    accent: const Color(0xFF3B82F6),
                    isSelected: widget.isDark, isDarkUI: widget.isDark,
                    onTap: () { if (!widget.isDark) widget.onToggle(); },
                  )),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Theme Mode',
                        style: TextStyle(
                            color: widget.isDark ? const Color(0xFFEDF2FF) : const Color(0xFF0D1F3C),
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(widget.isDark ? 'Dark mode is active' : 'Light mode is active',
                        style: TextStyle(
                            color: widget.isDark ? const Color(0xFF475F7E) : const Color(0xFF7A93B4),
                            fontSize: 12)),
                  ])),
                  // Toggle switch
                  GestureDetector(
                    onTap: widget.onToggle,
                    child: AnimatedBuilder(
                      animation: _slideAnim,
                      builder: (_, __) {
                        final t = _slideAnim.value;
                        final trackColor = Color.lerp(const Color(0xFFEBF3FF), const Color(0xFF0D2452), t)!;
                        final thumbColor = Color.lerp(Colors.white, const Color(0xFF1E3A6E), t)!;
                        return Container(
                          width: 76, height: 36,
                          decoration: BoxDecoration(
                            color: trackColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Color.lerp(const Color(0xFFCBDCEE), const Color(0xFF1D4ED8), t)!,
                              width: 1.5,
                            ),
                          ),
                          child: Stack(alignment: Alignment.center, children: [
                            Positioned(left: 9,
                                child: Opacity(opacity: (1.0 - t).clamp(0.0, 1.0),
                                    child: const Icon(Icons.wb_sunny_rounded, size: 14, color: Color(0xFFD97706)))),
                            Positioned(right: 9,
                                child: Opacity(opacity: t.clamp(0.0, 1.0),
                                    child: const Icon(Icons.dark_mode_rounded, size: 14, color: Color(0xFF93C5FD)))),
                            Positioned(
                              left: 4 + (_slideAnim.value * 36),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: thumbColor,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 2)),
                                    if (t > 0.5) BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.45 * t), blurRadius: 12, spreadRadius: 1),
                                  ],
                                ),
                                child: Center(child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    t > 0.5 ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                                    key: ValueKey(t > 0.5), size: 14,
                                    color: t > 0.5 ? const Color(0xFFEFF6FF) : const Color(0xFFD97706),
                                  ),
                                )),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _ThemeTile extends StatefulWidget {
  final String label; final IconData icon; final Color accent;
  final bool isSelected, isDarkUI; final VoidCallback onTap;
  const _ThemeTile({
    required this.label, required this.icon, required this.accent,
    required this.isSelected, required this.isDarkUI, required this.onTap,
  });
  @override
  State<_ThemeTile> createState() => _ThemeTileState();
}

class _ThemeTileState extends State<_ThemeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _hov = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 180),
        value: widget.isSelected ? 1.0 : 0.0);
    _scale = Tween<double>(begin: 1.0, end: 1.02)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_ThemeTile old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      widget.isSelected ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isSelected
        ? widget.accent
        : (widget.isDarkUI ? const Color(0xFF1E2E47) : const Color(0xFFDDE6F0));
    final bgColor = widget.isSelected
        ? widget.accent.withOpacity(widget.isDarkUI ? 0.12 : 0.06)
        : (widget.isDarkUI ? const Color(0xFF161F30) : const Color(0xFFF7FAFD));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: widget.isSelected ? 2 : 1),
              boxShadow: widget.isSelected
                  ? [BoxShadow(color: widget.accent.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 4))]
                  : (_hov ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))] : null),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.accent.withOpacity(widget.isSelected ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.accent.withOpacity(widget.isSelected ? 0.4 : 0.2)),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.label,
                    style: TextStyle(
                        color: widget.isSelected
                            ? widget.accent
                            : (widget.isDarkUI ? const Color(0xFFEDF2FF) : const Color(0xFF0D1F3C)),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                Text(widget.label == 'Light' ? 'Clean & bright' : 'Easy on eyes',
                    style: TextStyle(
                        color: widget.isDarkUI ? const Color(0xFF475F7E) : const Color(0xFF7A93B4),
                        fontSize: 11)),
              ])),
              if (widget.isSelected)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: widget.accent,
                    boxShadow: [BoxShadow(color: widget.accent.withOpacity(0.4), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                )
              else
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: widget.isDarkUI ? const Color(0xFF283D5C) : const Color(0xFFDDE6F0),
                        width: 1.5),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 0.5;
    const gap = 18.0;
    for (double x = 0; x <= size.width; x += gap)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y <= size.height; y += gap)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sign Out Tile
// ─────────────────────────────────────────────────────────────────────────────
//  About Tile (button → popup dialog)
// ─────────────────────────────────────────────────────────────────────────────
class _AboutCard extends StatefulWidget {
  const _AboutCard();
  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  bool _hov = false;

  void _showAboutDialog() {
    final tk = context.tk;

    Widget creditRow(String role, List<String> names) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 10, height: 10,
            margin: const EdgeInsets.only(top: 3, right: 12),
            decoration: BoxDecoration(
              color: tk.blue,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: tk.blue.withOpacity(0.45), blurRadius: 6)],
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(role,
                  style: TextStyle(
                      color: tk.txtMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4)),
              const SizedBox(height: 5),
              ...names.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(n,
                    style: TextStyle(
                        color: tk.txtHead,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
              )),
            ]),
          ),
        ]),
      );
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.58),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              color: tk.surf,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: tk.bd),
              boxShadow: tk.shadowMd,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // ── Header gradient band ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tk.blue, tk.blue.withOpacity(0.78)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                child: Row(children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.28)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset('assets/images/seal.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('SPCWD Job Order System',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 3),
                    Text('San Pablo City Water District',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 12)),
                  ])),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 17),
                    ),
                  ),
                ]),
              ),

              // ── Credits body ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(children: [
                  creditRow('INITIATIVE BY', ['Engr. Alvin A. Santiago']),
                  creditRow('PROJECT LEAD', ['Engr. Jomelo Angelo N. Muñoz']),
                  creditRow('DEVELOPERS', [
                    'Rafael P. Abratique',
                    'Jan Hendrix D. Bueno',
                  ]),
                  creditRow('BETA TESTERS', [
                    'Engr. Johnrei B. Gesmundo',
                    'Howard Lance B. Pasco',
                    'Robert Bryan C. Dela Rosa',
                  ]),
                ]),
              ),

              // ── Footer ───────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: tk.surf2,
                  border: Border(top: BorderSide(color: tk.bd)),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Center(
                  child: Text('Version 4.0  ·  © 2026 SPCWD',
                      style: TextStyle(
                          color: tk.txtMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: _showAboutDialog,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hov ? tk.blueBg : tk.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hov ? tk.blueBd : tk.bd,
              width: _hov ? 1.5 : 1,
            ),
            boxShadow: _hov
                ? [BoxShadow(color: tk.blue.withOpacity(0.10), blurRadius: 14, offset: const Offset(0, 4))]
                : tk.shadowSm,
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: tk.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tk.blue.withOpacity(0.18)),
              ),
              child: Icon(Icons.info_outline_rounded, color: tk.blue, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('About',
                  style: TextStyle(
                      color: _hov ? tk.blue : tk.txtHead,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('Credits, team & version info',
                  style: TextStyle(color: tk.txtMuted, fontSize: 12.5)),
            ])),
            Icon(Icons.chevron_right_rounded,
                color: _hov ? tk.blue : tk.bd2, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SignOutTile extends StatefulWidget {
  const _SignOutTile();
  @override
  State<_SignOutTile> createState() => _SignOutTileState();
}

class _SignOutTileState extends State<_SignOutTile> {
  bool _hov = false;

  void _showSignOutDialog() {
    final tk = context.tk;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => Dialog(
        backgroundColor: tk.surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25), width: 1.5),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 26),
            ),
            const SizedBox(height: 18),
            Text('Sign Out',
                style: TextStyle(color: tk.txtHead, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Are you sure you want to sign out\nof the SPCWD Job Order System?',
                textAlign: TextAlign.center,
                style: TextStyle(color: tk.txtMuted, fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: tk.surf2,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: tk.bd),
                  ),
                  child: Center(child: Text('Cancel',
                      style: TextStyle(color: tk.txt, fontSize: 13.5, fontWeight: FontWeight.w600))),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () {
                  AppSession.instance.clear();
                  Navigator.pop(ctx);
                  Navigator.pushAndRemoveUntil(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, a, __) => const LoginScreen(),
                      transitionsBuilder: (_, a, __, child) =>
                          FadeTransition(opacity: a, child: child),
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
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
                    boxShadow: [BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.35),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text('Sign Out', style: TextStyle(
                        color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ])),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: _showSignOutDialog,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hov ? const Color(0xFFEF4444).withOpacity(0.04) : tk.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hov ? const Color(0xFFEF4444).withOpacity(0.35) : tk.bd,
              width: _hov ? 1.5 : 1,
            ),
            boxShadow: _hov
                ? [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.10),
                blurRadius: 14, offset: const Offset(0, 4))]
                : tk.shadowSm,
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.18)),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sign Out',
                  style: TextStyle(
                      color: _hov ? const Color(0xFFEF4444) : context.tk.txtHead,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('Log out of your account',
                  style: TextStyle(color: context.tk.txtMuted, fontSize: 12.5)),
            ])),
            Icon(Icons.chevron_right_rounded,
                color: _hov ? const Color(0xFFEF4444).withOpacity(0.5) : context.tk.bd2,
                size: 20),
          ]),
        ),
      ),
    );
  }
}