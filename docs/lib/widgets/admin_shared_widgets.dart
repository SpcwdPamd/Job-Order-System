// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  Admin Shared Widgets — reused across admin pages                          ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/theme/theme_provider.dart';

// ── Small icon button (edit / delete) ────────────────────────────────────────
class AdminIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const AdminIconBtn({super.key, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }
}

// ── Floating action button ────────────────────────────────────────────────────
class AdminAddFab extends StatelessWidget {
  final Color accent;
  final String label;
  final VoidCallback onTap;
  const AdminAddFab({super.key, required this.accent, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [accent, accent.withOpacity(0.80)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(color: accent.withOpacity(0.38), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Add / Edit dialog ─────────────────────────────────────────────────────────
class AdminItemDialog extends StatelessWidget {
  final String title;
  final String codeLabel;
  final String nameLabel;
  final TextEditingController codeCtrl;
  final TextEditingController nameCtrl;
  final GlobalKey<FormState> formKey;
  final Color accent;
  final VoidCallback onSave;

  const AdminItemDialog({
    super.key,
    required this.title,
    required this.codeLabel,
    required this.nameLabel,
    required this.codeCtrl,
    required this.nameCtrl,
    required this.formKey,
    required this.accent,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Dialog(
      backgroundColor: tk.surf,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tk.bd)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Icon(Icons.edit_note_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: TextStyle(
                    color: tk.txtHead, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, color: tk.txtMuted, size: 20),
              ),
            ]),
            const SizedBox(height: 22),
            // Code field
            TextFormField(
              controller: codeCtrl,
              style: TextStyle(color: tk.txtHead),
              decoration: dsInputOf(context, codeLabel, icon: Icons.tag_rounded),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            // Name field
            TextFormField(
              controller: nameCtrl,
              style: TextStyle(color: tk.txtHead),
              decoration: dsInputOf(context, nameLabel, icon: Icons.label_rounded),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(children: [
              Expanded(child: AdminOutlineBtn(
                label: 'Cancel',
                onTap: () => Navigator.pop(context),
              )),
              const SizedBox(width: 12),
              Expanded(child: AdminSolidBtn(
                label: 'Save',
                accent: accent,
                onTap: onSave,
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Delete confirmation dialog ────────────────────────────────────────────────
class AdminDeleteDialog extends StatelessWidget {
  final String name;
  final Color accent;
  final VoidCallback onConfirm;
  const AdminDeleteDialog({super.key, required this.name, required this.accent, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Dialog(
      backgroundColor: tk.surf,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tk.bd)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Icon(Icons.delete_outline_rounded, color: accent, size: 26),
          ),
          const SizedBox(height: 16),
          Text('Delete Item?', style: TextStyle(
              color: tk.txtHead, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('This will remove:\n"$name"\nfrom the dropdown list.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tk.txtMuted, fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: AdminOutlineBtn(
              label: 'Cancel',
              onTap: () => Navigator.pop(context),
            )),
            const SizedBox(width: 12),
            Expanded(child: AdminSolidBtn(
              label: 'Delete',
              accent: accent,
              onTap: onConfirm,
            )),
          ]),
        ]),
      ),
    );
  }
}

// ── Outline button ────────────────────────────────────────────────────────────
class AdminOutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AdminOutlineBtn({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: tk.surf2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tk.bd),
        ),
        child: Center(child: Text(label, style: TextStyle(
            color: tk.txt, fontSize: 14, fontWeight: FontWeight.w600))),
      ),
    );
  }
}

// ── Solid button ──────────────────────────────────────────────────────────────
class AdminSolidBtn extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const AdminSolidBtn({super.key, required this.label, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [accent, accent.withOpacity(0.82)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: accent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
      ),
    );
  }
}