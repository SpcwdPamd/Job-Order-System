import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrashBinPage extends StatefulWidget {
  final VoidCallback? onBack;
  const TrashBinPage({super.key, this.onBack});
  @override
  State<TrashBinPage> createState() => _TrashBinPageState();
}

class _TrashBinPageState extends State<TrashBinPage> {
  Tk get _tk => context.tk;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  List<String> _selectedIds = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Supabase.instance.client.from('job_orders')
          .select('id, jo_number, shift_time, team:team_id (team_name), work_type_name, address, status, created_at')
          .eq('status', 'deleted').order('created_at', ascending: false);
      final s = await Supabase.instance.client.from('skeletal_job')
          .select('id, name, leader:leader_id (name), member_ids, work_type_name, address, status, created_at, completed_at')
          .eq('status', 'deleted').order('created_at', ascending: false);
      final combined = [
        ...r.map((j) => {...j, 'type': 'regular', 'displayName': j['jo_number'] ?? 'No J.O#', 'displayLeader': j['team']?['team_name'] ?? '—', 'nature': j['work_type_name'] ?? '—'}),
        ...s.map((j) => {...j, 'type': 'skeletal', 'displayName': j['name'] ?? 'No Name', 'displayLeader': j['leader']?['name'] ?? '—', 'nature': j['work_type_name'] ?? '—'}),
      ];
      if (!mounted) return;
      setState(() { _all = combined; _filtered = combined; _selectedIds = []; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() { _filtered = _all.where((j) =>
    (j['displayName'] ?? '').toLowerCase().contains(q) ||
        (j['displayLeader'] ?? '').toLowerCase().contains(q) ||
        (j['nature'] ?? '').toLowerCase().contains(q)).toList(); });
  }

  Future<void> _restore(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final rIds = ids.where((id) => _all.any((j) => j['id'] == id && j['type'] == 'regular')).toList();
      // Skeletal jobs that were completed before deletion → restore to 'completed'
      final skelDone = ids.where((id) => _all.any((j) =>
      j['id'] == id && j['type'] == 'skeletal' && j['completed_at'] != null)).toList();
      // Skeletal jobs that were still pending before deletion → restore to 'pending'
      final skelPend = ids.where((id) => _all.any((j) =>
      j['id'] == id && j['type'] == 'skeletal' && j['completed_at'] == null)).toList();
      if (rIds.isNotEmpty) await Supabase.instance.client.from('job_orders').update({'status': 'pending'}).inFilter('id', rIds);
      if (skelDone.isNotEmpty) await Supabase.instance.client.from('skeletal_job').update({'status': 'completed'}).inFilter('id', skelDone);
      if (skelPend.isNotEmpty) await Supabase.instance.client.from('skeletal_job').update({'status': 'pending'}).inFilter('id', skelPend);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ids.length} job(s) restored'), backgroundColor: const Color(0xFF059669)));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _permDelete(List<String> ids) async {
    if (ids.isEmpty) return;
    final confirm = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _tk.surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _tk.bd)),
          title: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 20)),
            const SizedBox(width: 12),
            Text('Permanent Delete', style: TextStyle(color: _tk.txtHead, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: Text('${ids.length} job(s) will be permanently deleted. This cannot be undone.', style: TextStyle(color: _tk.txt, fontSize: 13.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: _tk.txtMuted))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                child: const Text('Delete Forever')),
          ],
        ));
    if (confirm != true) return;
    try {
      final rIds = ids.where((id) => _all.any((j) => j['id'] == id && j['type'] == 'regular')).toList();
      final sIds = ids.where((id) => _all.any((j) => j['id'] == id && j['type'] == 'skeletal')).toList();
      if (rIds.isNotEmpty) await Supabase.instance.client.from('job_orders').delete().inFilter('id', rIds);
      if (sIds.isNotEmpty) await Supabase.instance.client.from('skeletal_job').delete().inFilter('id', sIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ids.length} job(s) permanently deleted'), backgroundColor: const Color(0xFFDC2626)));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tk.bg,
      body: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
          decoration: BoxDecoration(color: _tk.surf, border: Border(bottom: BorderSide(color: _tk.bd)), boxShadow: _tk.shadowSm),
          child: SafeArea(bottom: false, child: Column(children: [
            Row(children: [
              GestureDetector(onTap: () => widget.onBack != null ? widget.onBack!() : Navigator.pop(context),
                  child: Container(width: 38, height: 38, decoration: BoxDecoration(color: _tk.surf2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _tk.bd)),
                      child: Icon(Icons.arrow_back_rounded, color: _tk.txtHead, size: 20))),
              const SizedBox(width: 14),
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [const Color(0xFFD97706), const Color(0xFFD97706).withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFFD97706).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: const Icon(Icons.restore_from_trash_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Trash Bin', style: TextStyle(color: _tk.txtHead, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                Text('Restore or permanently delete jobs', style: TextStyle(color: _tk.txtMuted, fontSize: 12)),
              ])),
              if (_selectedIds.isNotEmpty)
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFD97706).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD97706).withOpacity(0.3))),
                    child: Text('${_selectedIds.length} selected', style: const TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 14),
            DsSearchBar(controller: _search, hint: 'Search trash…', onClear: _filter),
          ])),
        ),

        // Action bar
        if (_selectedIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: const Color(0xFFD97706).withOpacity(0.06),
            child: Row(children: [
              Text('${_selectedIds.length} selected', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              TextButton.icon(onPressed: () => setState(() => _selectedIds.clear()),
                  icon: Icon(Icons.clear, size: 14, color: _tk.txtMuted),
                  label: Text('Clear', style: TextStyle(color: _tk.txtMuted, fontSize: 12))),
              const SizedBox(width: 6),
              ElevatedButton.icon(onPressed: () => _restore(_selectedIds),
                  icon: const Icon(Icons.restore_rounded, size: 14),
                  label: const Text('Restore'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              const SizedBox(width: 6),
              ElevatedButton.icon(onPressed: () => _permDelete(_selectedIds),
                  icon: const Icon(Icons.delete_forever_rounded, size: 14),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ),

        Expanded(child: _loading
            ? const DsLoading()
            : _filtered.isEmpty
            ? DsEmpty(message: _search.text.isEmpty ? 'Trash is empty' : 'No results found', icon: Icons.delete_outline_rounded)
            : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _filtered.length,
            itemBuilder: (context, i) {
              final j = _filtered[i];
              final isSkeletal = j['type'] == 'skeletal';
              final isSelected = _selectedIds.contains(j['id']);
              final typeColor = isSkeletal ? const Color(0xFFD97706) : const Color(0xFF2563EB);
              return GestureDetector(
                onTap: () => setState(() { if (isSelected) _selectedIds.remove(j['id']); else _selectedIds.add(j['id'] as String); }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFFDC2626).withOpacity(0.05) : _tk.surf,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? Color(0xFFDC2626) : _tk.bd, width: isSelected ? 1.5 : 1),
                    boxShadow: isSelected ? null : _tk.shadowSm,
                  ),
                  child: Row(children: [
                    Container(width: 22, height: 22, decoration: BoxDecoration(
                        color: isSelected ? Color(0xFFDC2626) : _tk.surf2, borderRadius: BorderRadius.circular(6), border: Border.all(color: isSelected ? Color(0xFFDC2626) : _tk.bd2)),
                        child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null),
                    const SizedBox(width: 12),
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(isSkeletal ? Icons.groups_rounded : Icons.receipt_long_rounded, color: typeColor, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(j['displayName'] ?? '—', style: TextStyle(color: _tk.txtHead, fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text('${isSkeletal ? 'Leader' : 'Team'}: ${j['displayLeader']}', style: TextStyle(color: _tk.txt, fontSize: 12.5)),
                      Text(j['nature'] ?? '—', style: TextStyle(color: _tk.txtMuted, fontSize: 12)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      DsTag(isSkeletal ? 'Skeletal' : 'Regular', typeColor),
                      const SizedBox(height: 4),
                      DsTag('Trashed', const Color(0xFFDC2626)),
                    ]),
                  ]),
                ),
              );
            })),
      ]),
    );
  }
}