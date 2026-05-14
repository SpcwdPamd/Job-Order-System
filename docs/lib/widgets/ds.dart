// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  SPCWD Design System — Shared widgets, uses Tk tokens from context         ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:job_order/core/theme/theme_provider.dart';

// ── Static accent colors (same in both modes, used in non-context places) ─────
const kBlue   = Color(0xFF2563EB);
const kGreen  = Color(0xFF059669);
const kRed    = Color(0xFFDC2626);
const kAmber  = Color(0xFFD97706);
const kViolet = Color(0xFF7C3AED);
const kCyan   = Color(0xFF0891B2);
const kPink   = Color(0xFFDB2777);
const kIndigo = Color(0xFF4338CA);

// Keep backward-compat statics for non-context code
const kBg      = Color(0xFFF0F4F8);
const kSurf    = Color(0xFFFFFFFF);
const kSurf2   = Color(0xFFF8FAFC);
const kBd      = Color(0xFFE2E8F0);
const kBd2     = Color(0xFFCBD5E1);
const kMuted   = Color(0xFF94A3B8);
const kTxt     = Color(0xFF334155);
const kTxtDark = Color(0xFF0F172A);
const kBlueMid = Color(0xFF3B82F6);
const kBlueLight = Color(0xFFEFF6FF);
const kBlueBd  = Color(0xFFBFDBFE);
const kSideBg  = Color(0xFF1E3A5F);
const kSideMuted = Color(0xFF64748B);
const kSideTxt = Color(0xFFCBD5E1);
List<BoxShadow> kShadowSm = [
  BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
];
List<BoxShadow> kShadowMd = [
  BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
];

// ── Page Header (theme-aware) ─────────────────────────────────────────────────
class DsHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final List<Widget> actions;

  const DsHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 24),
      decoration: BoxDecoration(
        color: tk.surf,
        border: Border(bottom: BorderSide(color: tk.bd)),
        boxShadow: tk.shadowSm,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent, accent.withOpacity(0.75)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [BoxShadow(color: accent.withOpacity(0.28), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: tk.txtHead, fontSize: 21,
                fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: tk.txtMuted, fontSize: 12.5)),
          ])),
          ...actions,
        ]),
      ),
    );
  }
}

// ── Surface Card ──────────────────────────────────────────────────────────────
class DsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;

  const DsCard({super.key, required this.child, this.padding, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tk.surf, borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tk.bd), boxShadow: tk.shadowSm,
      ),
      child: child,
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────
class DsLabel extends StatelessWidget {
  final String text;
  const DsLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text.toUpperCase(), style: TextStyle(
        color: context.tk.txtMuted, fontSize: 10.5,
        fontWeight: FontWeight.w700, letterSpacing: 1.6)),
  );
}

// ── Tag / Badge ───────────────────────────────────────────────────────────────
class DsTag extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bg;
  const DsTag(this.label, this.color, {super.key, this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg ?? color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

// ── Search Bar ────────────────────────────────────────────────────────────────
class DsSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onClear;

  const DsSearchBar({super.key, required this.controller, required this.hint, this.onClear});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: tk.surf, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tk.bd), boxShadow: tk.shadowSm,
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: tk.txtHead, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: tk.txtMuted, fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded, color: tk.txtMuted, size: 18),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, val, __) => val.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                onTap: () { controller.clear(); onClear?.call(); },
                child: Icon(Icons.close_rounded, color: tk.txtMuted, size: 16)),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── Input decoration (context-aware) ─────────────────────────────────────────
InputDecoration dsInputOf(BuildContext context, String label,
    {IconData? icon, Widget? suffix, String? hint}) {
  final tk = context.tk;
  return InputDecoration(
    labelText: label.isEmpty ? null : label,
    hintText: hint ?? (label.isEmpty ? null : null),
    labelStyle: TextStyle(color: tk.txtMuted, fontSize: 13.5),
    hintStyle: TextStyle(color: tk.txtMuted),
    prefixIcon: icon != null ? Icon(icon, color: tk.txtMuted, size: 19) : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: tk.surf,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tk.bd)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tk.bd)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tk.blue, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tk.red)),
  );
}

// Keep static version for non-context places
InputDecoration dsInput(String label, {IconData? icon, Widget? suffix, String? hint}) => InputDecoration(
  labelText: label.isEmpty ? null : label,
  hintText: hint,
  labelStyle: const TextStyle(color: kMuted, fontSize: 13.5),
  hintStyle: const TextStyle(color: kMuted),
  prefixIcon: icon != null ? Icon(icon, color: kMuted, size: 19) : null,
  suffixIcon: suffix,
  filled: true,
  fillColor: kSurf,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBd)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBd)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBlue, width: 1.5)),
);

// ── Loading ───────────────────────────────────────────────────────────────────
class DsLoading extends StatelessWidget {
  const DsLoading({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 36, height: 36,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: context.tk.blue)),
      const SizedBox(height: 14),
      Text('Loading…', style: TextStyle(color: context.tk.txtMuted, fontSize: 13)),
    ]),
  );
}

// ── Empty State ───────────────────────────────────────────────────────────────
class DsEmpty extends StatelessWidget {
  final String message;
  final IconData icon;
  const DsEmpty({super.key, required this.message, this.icon = Icons.inbox_rounded});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72,
          decoration: BoxDecoration(color: tk.blueBg, borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, color: tk.blue, size: 34)),
      const SizedBox(height: 14),
      Text(message, style: TextStyle(color: tk.txt, fontSize: 14, fontWeight: FontWeight.w500)),
    ]));
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────
class DsDivider extends StatelessWidget {
  const DsDivider({super.key});
  @override
  Widget build(BuildContext context) => Divider(color: context.tk.bd, height: 1, thickness: 1);
}

// Legacy helpers (backward compat with static palette) ────────────────────────
Color workTypeColor(String? code) {
  switch (code) {
    case '101': return kBlue; case '102': return kCyan; case '103': return kViolet;
    case '104': return kAmber; case '201': return kGreen; case '202': return kRed;
    case '203': return kIndigo; case '301': return kPink; default: return kMuted;
  }
}
String difficultyLabel(int? lvl) {
  switch (lvl) { case 1: return 'Minor'; case 2: return 'Moderate'; case 3: return 'Major'; default: return '—'; }
}
Color difficultyColor(int? lvl) {
  switch (lvl) { case 1: return kGreen; case 2: return kAmber; case 3: return kRed; default: return kMuted; }
}