// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  Admin — Type of Works Manager (Supabase-backed)                           ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/data/admin_data.dart';
import 'package:job_order/widgets/admin_shared_widgets.dart';

class AdminWorkTypesPage extends StatefulWidget {
  final VoidCallback? onBack;
  const AdminWorkTypesPage({super.key, this.onBack});
  @override
  State<AdminWorkTypesPage> createState() => _AdminWorkTypesPageState();
}

class _AdminWorkTypesPageState extends State<AdminWorkTypesPage> {
  @override
  void initState() {
    super.initState();
    workTypesNotifier.addListener(_refresh);
    // Refresh from Supabase every time the page opens
    workTypesNotifier.fetch();
  }

  @override
  void dispose() {
    workTypesNotifier.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  void _showDialog({WorkTypeItem? item}) {
    final tk = context.tk;
    final codeCtrl = TextEditingController(text: item?.code ?? '');
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final formKey  = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AdminItemDialog(
        title: item != null ? 'Edit Type of Work' : 'Add Type of Work',
        codeLabel: 'Code (e.g. 101)',
        nameLabel: 'Name (e.g. Service Lines/Fittings)',
        codeCtrl: codeCtrl,
        nameCtrl: nameCtrl,
        formKey: formKey,
        accent: tk.blue,
        onSave: () async {
          if (!formKey.currentState!.validate()) return;
          Navigator.pop(ctx);
          try {
            if (item != null) {
              await workTypesNotifier.update(item.id, codeCtrl.text.trim(), nameCtrl.text.trim());
            } else {
              await workTypesNotifier.add(codeCtrl.text.trim(), nameCtrl.text.trim());
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

  void _confirmDelete(WorkTypeItem item) {
    final tk = context.tk;
    showDialog(
      context: context,
      builder: (ctx) => AdminDeleteDialog(
        name: '${item.code} — ${item.name}',
        accent: tk.red,
        onConfirm: () async {
          Navigator.pop(ctx);
          try {
            await workTypesNotifier.remove(item.id);
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
    final items = workTypesNotifier.items;
    final isLoading = workTypesNotifier.isLoading;

    return Scaffold(
      backgroundColor: tk.bg,
      body: Column(children: [
        DsHeader(
          title: 'Type of Works',
          subtitle: 'Add, edit or delete work type options',
          icon: Icons.build_circle_rounded,
          accent: tk.blue,
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
              message: 'No work types yet. Tap + to add one.',
              icon: Icons.build_circle_outlined)
              : ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _WorkTypeCard(
              item: items[i],
              accent: tk.blue,
              onEdit: () => _showDialog(item: items[i]),
              onDelete: () => _confirmDelete(items[i]),
            ),
          ),
        ),
      ]),
      floatingActionButton: AdminAddFab(
        accent: tk.blue,
        label: 'Add Work Type',
        onTap: () => _showDialog(),
      ),
    );
  }
}

class _WorkTypeCard extends StatelessWidget {
  final WorkTypeItem item;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _WorkTypeCard({
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
                style: TextStyle(color: accent, fontSize: 12,
                    fontWeight: FontWeight.w800, letterSpacing: 0.2)),
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