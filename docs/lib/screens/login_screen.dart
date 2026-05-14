
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:job_order/core/session/session.dart';
import 'package:job_order/screens/main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey  = GlobalKey<FormState>();
  bool _obscure   = true;
  bool _loading   = false;
  String? _error;
  final _passFocus = FocusNode(); // ← focus node so Enter on username jumps here

  late final AnimationController _blobCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _blobCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _blobCtrl.dispose(); _entryCtrl.dispose();
    _userCtrl.dispose(); _passCtrl.dispose();
    _passFocus.dispose(); // ← dispose the focus node
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('id, username, full_name, role, status, perm_admin, perm_edit_details, perm_edit_reports')
          .eq('username', _userCtrl.text.trim())
          .eq('password', _passCtrl.text.trim())
          .maybeSingle();

      if (!mounted) return;
      if (res == null) {
        setState(() { _loading = false; _error = 'Invalid username or password.'; });
        return;
      }
      // Block pending/rejected/blocked accounts
      final status = res['status'] as String? ?? 'approved';
      if (status == 'pending') {
        setState(() { _loading = false; _error = 'Your account is pending admin approval.'; });
        return;
      }
      if (status == 'rejected') {
        setState(() { _loading = false; _error = 'Your account has been rejected. Contact admin.'; });
        return;
      }
      if (status == 'blocked') {
        setState(() { _loading = false; _error = 'Your account has been blocked. Contact the administrator.'; });
        return;
      }
      AppSession.instance.set(
        res['id'] as int,
        res['username'] as String,
        res['full_name'] as String? ?? '',
        userRole:       res['role']               as String? ?? 'user',
        pAdmin:         res['perm_admin']          as bool?   ?? false,
        pEditDetails:   res['perm_edit_details']   as bool?   ?? false,
        pEditReports:   res['perm_edit_reports']   as bool?   ?? false,
      );
      Navigator.pushReplacement(context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) => const MainScreen(),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ));
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Connection error. Check your network.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: _AnimatedBg(ctrl: _blobCtrl)),
        Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980, maxHeight: 600),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 80, offset: const Offset(0, 24))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Row(children: [
                      const _LeftPanel(),
                      _buildForm(),
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

  Widget _buildForm() => Expanded(
    child: Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Welcome back 👋',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5)),
              const SizedBox(height: 4),
              const Text('Sign in to your account',
                  style: TextStyle(color: Color(0xFF0D1F3C), fontSize: 26,
                      fontWeight: FontWeight.w900, letterSpacing: -0.8)),
              const SizedBox(height: 32),

              const _AuthLabel('Username'),
              const SizedBox(height: 6),
              // ── USERNAME: pressing Enter moves focus to password field ──
              _AuthField(
                controller: _userCtrl,
                hint: 'Enter your username',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _passFocus.requestFocus(),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your username' : null,
              ),
              const SizedBox(height: 18),

              const _AuthLabel('Password'),
              const SizedBox(height: 6),
              // ── PASSWORD: pressing Enter submits the login form ──────────
              TextFormField(
                controller: _passCtrl,
                focusNode: _passFocus,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _loading ? null : _submit(),
                style: const TextStyle(color: Color(0xFF0D1F3C), fontSize: 14),
                decoration: authDeco(
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8), size: 19,
                      ),
                    ),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                _AuthErrorBanner(message: _error!),
              ],
              const SizedBox(height: 26),

              _AuthButton(loading: _loading, label: 'Sign In', onTap: _submit),
              const SizedBox(height: 22),

              Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen())),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                        children: [
                          TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Create one',
                            style: TextStyle(
                                color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),
              Container(height: 1, color: const Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              Center(
                child: Text('San Pablo City Water District',
                    style: TextStyle(
                        color: const Color(0xFF94A3B8).withOpacity(0.7), fontSize: 11.5)),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}


class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _loading        = false;
  String? _error;
  String? _success;

  late final AnimationController _blobCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _blobCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _blobCtrl.dispose(); _entryCtrl.dispose();
    _fullNameCtrl.dispose(); _usernameCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final existing = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('username', _usernameCtrl.text.trim())
          .maybeSingle();
      if (!mounted) return;
      if (existing != null) {
        setState(() { _loading = false; _error = 'Username already taken. Choose another.'; });
        return;
      }
      await Supabase.instance.client.from('users').insert({
        'full_name': _fullNameCtrl.text.trim(),
        'username' : _usernameCtrl.text.trim(),
        'password' : _passCtrl.text.trim(),
        'role'     : 'user',
        'status'   : 'pending',
      });
      if (!mounted) return;
      setState(() { _loading = false; _success = 'Account created! Waiting for admin approval before you can sign in.'; });
      // Don't auto-redirect — user must wait for admin approval
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Something went wrong. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: _AnimatedBg(ctrl: _blobCtrl)),
        Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980, maxHeight: 700),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 80, offset: const Offset(0, 24))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Row(children: [
                      const _LeftPanel(isSignUp: true),
                      _buildForm(),
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

  Widget _buildForm() => Expanded(
    child: Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 36),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Join the system 🚀',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5)),
              const SizedBox(height: 4),
              const Text('Create your account',
                  style: TextStyle(color: Color(0xFF0D1F3C), fontSize: 26,
                      fontWeight: FontWeight.w900, letterSpacing: -0.8)),
              const SizedBox(height: 28),

              const _AuthLabel('Full Name'),
              const SizedBox(height: 6),
              _AuthField(
                controller: _fullNameCtrl,
                hint: 'e.g. Juan dela Cruz',
                icon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your full name';
                  if (v.trim().length < 3) return 'Name must be at least 3 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const _AuthLabel('Username'),
              const SizedBox(height: 6),
              _AuthField(
                controller: _usernameCtrl,
                hint: 'Choose a username',
                icon: Icons.person_outline_rounded,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a username';
                  if (v.trim().length < 3) return 'At least 3 characters';
                  if (v.contains(' ')) return 'No spaces allowed';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const _AuthLabel('Password'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                style: const TextStyle(color: Color(0xFF0D1F3C), fontSize: 14),
                decoration: authDeco(
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscurePass = !_obscurePass),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(
                        _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8), size: 19,
                      ),
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a password';
                  if (v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const _AuthLabel('Confirm Password'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                style: const TextStyle(color: Color(0xFF0D1F3C), fontSize: 14),
                decoration: authDeco(
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(
                        _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8), size: 19,
                      ),
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirm your password';
                  if (v != _passCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                _AuthErrorBanner(message: _error!),
              ],
              if (_success != null) ...[
                const SizedBox(height: 14),
                _AuthSuccessBanner(message: _success!),
              ],
              const SizedBox(height: 24),

              _AuthButton(loading: _loading, label: 'Create Account', onTap: _submit),
              const SizedBox(height: 18),

              Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                        children: [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                                color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Container(height: 1, color: const Color(0xFFE2E8F0)),
              const SizedBox(height: 14),
              Center(
                child: Text('San Pablo City Water District',
                    style: TextStyle(
                        color: const Color(0xFF94A3B8).withOpacity(0.7), fontSize: 11.5)),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}


//  SHARED AUTH WIDGETS


InputDecoration authDeco({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 19),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444))),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8)),
    );

class _AuthLabel extends StatelessWidget {
  final String text;
  const _AuthLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1));
}

// ── _AuthField — now supports textInputAction and onFieldSubmitted ────────────
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    textCapitalization: textCapitalization,
    textInputAction: textInputAction,
    onFieldSubmitted: onFieldSubmitted,
    style: const TextStyle(color: Color(0xFF0D1F3C), fontSize: 14),
    decoration: authDeco(hint: hint, icon: icon),
    validator: validator,
  );
}

class _AuthButton extends StatefulWidget {
  final bool loading;
  final String label;
  final VoidCallback onTap;
  const _AuthButton(
      {required this.loading, required this.label, required this.onTap});
  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: GestureDetector(
      onTap: widget.loading ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: LinearGradient(
            colors: _hov && !widget.loading
                ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]
                : [const Color(0xFF2563EB), const Color(0xFF1E40AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(_hov ? 0.5 : 0.3),
              blurRadius: _hov ? 24 : 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: widget.loading
              ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.2, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 18),
          ]),
        ),
      ),
    ),
  );
}

class _AuthErrorBanner extends StatelessWidget {
  final String message;
  const _AuthErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded,
          color: Color(0xFFEF4444), size: 16),
      const SizedBox(width: 8),
      Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Color(0xFFB91C1C), fontSize: 12.5))),
    ]),
  );
}

class _AuthSuccessBanner extends StatelessWidget {
  final String message;
  const _AuthSuccessBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFA7F3D0)),
    ),
    child: Row(children: [
      const Icon(Icons.check_circle_outline_rounded,
          color: Color(0xFF059669), size: 16),
      const SizedBox(width: 8),
      Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Color(0xFF065F46), fontSize: 12.5))),
    ]),
  );
}


//  ANIMATED BACKGROUND

class _AnimatedBg extends StatelessWidget {
  final AnimationController ctrl;
  const _AnimatedBg({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (ctx, _) {
        final t  = ctrl.value * 2 * math.pi;
        final sw = MediaQuery.of(ctx).size.width;
        final sh = MediaQuery.of(ctx).size.height;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF040D1E), Color(0xFF071428), Color(0xFF050F22)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            _blob(0.15 + 0.08 * math.sin(t * 0.7), 0.2  + 0.06 * math.cos(t * 0.5), 520, const Color(0xFF1D4ED8), 0.18, sw, sh),
            _blob(0.75 + 0.06 * math.cos(t * 0.8), 0.7  + 0.08 * math.sin(t * 0.6), 440, const Color(0xFF6D28D9), 0.12, sw, sh),
            _blob(0.55 + 0.05 * math.sin(t * 0.9), 0.35 + 0.07 * math.cos(t * 0.4), 300, const Color(0xFF0EA5E9), 0.10, sw, sh),
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          ]),
        );
      },
    );
  }

  Widget _blob(double x, double y, double size, Color color, double opacity, double sw, double sh) =>
      Positioned(
        left: x * sw - size / 2,
        top:  y * sh - size / 2,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [color.withOpacity(opacity), color.withOpacity(0)]),
          ),
        ),
      );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;
    const g = 48.0;
    for (double x = 0; x <= size.width; x += g)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y <= size.height; y += g)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }

  @override
  bool shouldRepaint(_) => false;
}


//  LEFT BRANDING PANEL

class _LeftPanel extends StatelessWidget {
  final bool isSignUp;
  const _LeftPanel({this.isSignUp = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF060F23), Color(0xFF0A1A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned(
          top: -60, left: -60,
          child: _glow(260, const Color(0xFF2563EB), 0.15),
        ),
        Positioned(
          bottom: -40, right: -40,
          child: _glow(200, const Color(0xFF7C3AED), 0.12),
        ),
        Positioned.fill(child: CustomPaint(painter: _DotPainter())),
        Padding(
          padding: const EdgeInsets.all(44),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Logo badge
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/images/seal.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 32),
            const Text('San Pablo City',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1.15)),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF60A5FA), Color(0xFF818CF8)])
                  .createShader(b),
              child: const Text('Water District',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      height: 1.15)),
            ),
            const SizedBox(height: 10),
            Text('Job Order Management System',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.38),
                    fontSize: 13,
                    letterSpacing: 0.3)),
            const Spacer(),
            _feat(Icons.bolt_rounded, 'Real-time job tracking',
                const Color(0xFF60A5FA)),
            const SizedBox(height: 12),
            _feat(Icons.groups_rounded, 'Team & personnel management',
                const Color(0xFF818CF8)),
            const SizedBox(height: 12),
            _feat(Icons.analytics_rounded, 'Automated analytics',
                const Color(0xFF34D399)),
            const SizedBox(height: 12),
            _feat(Icons.location_on_rounded, 'Barangay-level tracking',
                const Color(0xFFFBBF24)),
            const Spacer(),
            Text('© 2025 SPCWD · All rights reserved',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.18), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _glow(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent]),
    ),
  );

  Widget _feat(IconData icon, String label, Color color) => Row(children: [
    Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color, size: 15),
    ),
    const SizedBox(width: 11),
    Text(label,
        style: TextStyle(
            color: Colors.white.withOpacity(0.68), fontSize: 12.5)),
  ]);
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.04);
    const s = 28.0;
    for (double x = 0; x < size.width; x += s)
      for (double y = 0; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.0, p);
  }

  @override
  bool shouldRepaint(_) => false;
}