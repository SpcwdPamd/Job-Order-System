// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  Admin — Damage Working Space Manager (Supabase-backed)                    ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/data/admin_data.dart';
import 'package:job_order/widgets/admin_shared_widgets.dart';

class AdminDamageSpacesPage extends StatefulWidget {
  final VoidCallback? onBack;
  const AdminDamageSpacesPage({super.key, this.onBack});
  @override
  State<AdminDamageSpacesPage> createState() => _AdminDamageSpacesPageState();
}

class _AdminDamageSpacesPageState extends State<AdminDamageSpacesPage> {
  @override
  void initState() {
    super.initState();
    damageSpacesNotifier.addListener(_refresh);
    damageSpacesNotifier.fetch();
  }

  @override
  void dispose() {
    damageSpacesNotifier.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  void _showDialog({DamageSpaceItem? item}) {
    final tk = context.tk;
    final codeCtrl = TextEditingController(text: item?.code ?? '');
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final formKey  = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AdminItemDialog(
        title: item != null ? 'Edit Damage Space' : 'Add Damage Space',
        codeLabel: 'Code (e.g. A)',
        nameLabel: 'Name (e.g. Concrete/Asphalt)',
        codeCtrl: codeCtrl,
        nameCtrl: nameCtrl,
        formKey: formKey,
        accent: tk.amber,
        onSave: () async {
          if (!formKey.currentState!.validate()) return;
          Navigator.pop(ctx);
          try {
            if (item != null) {
              await damageSpacesNotifier.update(item.id, codeCtrl.text.trim(), nameCtrl.text.trim());
            } else {
              await damageSpacesNotifier.add(codeCtrl.text.trim(), nameCtrl.text.trim());
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: context.tk.red),
              );
            }
          }
        },
      ),
    );
  }

  void _confirmDelete(DamageSpaceItem item) {
    final tk = context.tk;
    showDialog(
      context: context,
      builder: (ctx) => AdminDeleteDialog(
        name: '${item.code} — ${item.name}',
        accent: tk.red,
        onConfirm: () async {
          Navigator.pop(ctx);
          try {
            await damageSpacesNotifier.remove(item.id);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: context.tk.red),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final items = damageSpacesNotifier.items;
    final isLoading = damageSpacesNotifier.isLoading;

    return Scaffold(
      backgroundColor: tk.bg,
      body: Column(children: [
        DsHeader(
          title: 'Damage Working Space',
          subtitle: 'Add, edit or delete damage space options',
          icon: Icons.layers_rounded,
          accent: tk.amber,
          actions: [
            GestureDetector(
              onTap: () => widget.onBack != null ? widget.onBack!() : Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tk.surf2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tk.bd),
                ),
                child: Icon(Icons.arrow_back_rounded, color: tk.txtMuted, size: 20),
              ),
            ),
          ],
        ),
        Expanded(
          child: isLoading
              ? const DsLoading()
              : items.isEmpty
              ? const DsEmpty(
              message: 'No damage spaces yet. Tap + to add one.',
              icon: Icons.layers_outlined)
              : ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _DamageSpaceCard(
              item: items[i],
              accent: tk.amber,
              onEdit: () => _showDialog(item: items[i]),
              onDelete: () => _confirmDelete(items[i]),
            ),
          ),
        ),
      ]),
      floatingActionButton: AdminAddFab(
        accent: tk.amber,
        label: 'Add Damage Space',
        onTap: () => _showDialog(),
      ),
    );
  }
}

class _DamageSpaceCard extends StatelessWidget {
  final DamageSpaceItem item;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DamageSpaceCard({
    required this.item, required this.accent,
    required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: tk.surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tk.bd),
        boxShadow: tk.shadowSm,
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: accent.withOpacity(0.22)),
          ),
          child: Center(
            child: Text(item.code,
                style: TextStyle(color: accent, fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(item.name,
            style: TextStyle(color: tk.txtHead, fontSize: 14, fontWeight: FontWeight.w500))),
        AdminIconBtn(icon: Icons.edit_rounded, color: tk.blue, onTap: onEdit),
        const SizedBox(width: 6),
        AdminIconBtn(icon: Icons.delete_rounded, color: tk.red, onTap: onDelete),
      ]),
    );
  }
}