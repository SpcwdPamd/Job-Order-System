import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeleteTeamsPage extends StatefulWidget {
  const DeleteTeamsPage({super.key});
  @override
  State<DeleteTeamsPage> createState() => _DeleteTeamsPageState();
}

class _DeleteTeamsPageState extends State<DeleteTeamsPage> {
  Tk get _tk => context.tk;

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  Set<String> _selectedIds = {};
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('teams')
          .select('id, team_name, foreman_id, personnel_ids, foreman:foreman_id (name)')
          .order('team_name');
      final enriched = res.map((t) => {...t, 'member_count': (t['personnel_ids'] as List?)?.length ?? 0}).toList();
      if (!mounted) return;
      setState(() { _all = enriched; _filtered = enriched; _selectedIds = {}; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _all.where((t) =>
      (t['team_name'] ?? '').toLowerCase().contains(q) ||
          (t['foreman']?['name'] ?? '').toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _tk.surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _tk.bd)),
          title: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.group_remove_rounded, color: Color(0xFFDC2626), size: 20)),
            const SizedBox(width: 12),
            Text('Delete Teams?', style: TextStyle(color: _tk.txtHead, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: Text('${_selectedIds.length} team(s) will be permanently deleted. This cannot be undone.', style: TextStyle(color: _tk.txt, fontSize: 13.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: _tk.txtMuted))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                child: const Text('Delete Forever')),
          ],
        ));
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('teams').delete().inFilter('id', _selectedIds.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_selectedIds.length} team(s) deleted'), backgroundColor: const Color(0xFFDC2626)));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = _tk;
    return Scaffold(
      backgroundColor: tk.bg,
      body: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
          decoration: BoxDecoration(color: tk.surf, border: Border(bottom: BorderSide(color: tk.bd)), boxShadow: tk.shadowSm),
          child: SafeArea(bottom: false, child: Column(children: [
            Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(width: 38, height: 38, decoration: BoxDecoration(color: tk.surf2, borderRadius: BorderRadius.circular(10), border: Border.all(color: tk.bd)),
                      child: Icon(Icons.arrow_back_rounded, color: tk.txtHead, size: 20))),
              const SizedBox(width: 14),
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [const Color(0xFF7C3AED), const Color(0xFF7C3AED).withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: const Icon(Icons.group_remove_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Delete Teams', style: TextStyle(color: tk.txtHead, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                Text('Permanently remove teams from the system', style: TextStyle(color: tk.txtMuted, fontSize: 12)),
              ])),
              if (_selectedIds.isNotEmpty)
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3))),
                    child: Text('${_selectedIds.length} selected', style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 14),
            DsSearchBar(controller: _search, hint: 'Search teams or foreman…', onClear: _filter),
          ])),
        ),

        // Action bar
        if (_selectedIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: const Color(0xFFDC2626).withOpacity(0.05),
            child: Row(children: [
              Text('${_selectedIds.length} team(s) selected', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              TextButton.icon(onPressed: () => setState(() => _selectedIds.clear()),
                  icon: Icon(Icons.clear, size: 14, color: tk.txtMuted),
                  label: Text('Clear', style: TextStyle(color: tk.txtMuted, fontSize: 12))),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_forever_rounded, size: 15),
                  label: const Text('Delete Forever'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
            ]),
          ),

        // List
        Expanded(child: _loading
            ? const DsLoading()
            : _filtered.isEmpty
            ? DsEmpty(message: _search.text.isEmpty ? 'No teams found' : 'No results', icon: Icons.group_off_rounded)
            : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _filtered.length,
            itemBuilder: (context, i) {
              final t = _filtered[i];
              final id = t['id'] as String;
              final isSelected = _selectedIds.contains(id);
              final memberCount = t['member_count'] as int? ?? 0;
              return GestureDetector(
                onTap: () => setState(() { if (isSelected) _selectedIds.remove(id); else _selectedIds.add(id); }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFDC2626).withOpacity(0.05) : tk.surf,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? const Color(0xFFDC2626) : tk.bd, width: isSelected ? 1.5 : 1),
                    boxShadow: isSelected ? null : tk.shadowSm,
                  ),
                  child: Row(children: [
                    Container(width: 22, height: 22,
                        decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFDC2626) : tk.surf2,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSelected ? const Color(0xFFDC2626) : tk.bd2)),
                        child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null),
                    const SizedBox(width: 12),
                    Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.groups_rounded, color: Color(0xFF7C3AED), size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t['team_name'] ?? 'Unnamed Team', style: TextStyle(color: tk.txtHead, fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text('Foreman: ${t['foreman']?['name'] ?? '—'}', style: TextStyle(color: tk.txt, fontSize: 12.5)),
                    ])),
                    DsTag('$memberCount members', const Color(0xFF7C3AED)),
                  ]),
                ),
              );
            })),
      ]),
    );
  }
}