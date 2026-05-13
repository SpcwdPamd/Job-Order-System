import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/session/session.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF0F52A4);
const _kPrimaryLight = Color(0xFF1565C0);
const _kTableHeader = Color(0xFF1E3A5F);
const _kRowEven = Colors.white;
const Color _kRowOdd = Color(0xFFF8FAFC);
const _kBorder = Color(0xFFCBD5E1);

// ─── RelocationRow ────────────────────────────────────────────────────────────

class RelocationRow {
  int no;
  String date;
  String acctNo;
  String concessionaire;
  String address;
  String remarks;

  RelocationRow({
    required this.no,
    this.date = '',
    this.acctNo = '',
    this.concessionaire = '',
    this.address = '',
    this.remarks = '',
  });

  String getValue(String col) {
    switch (col) {
      case 'no':             return '$no';
      case 'date':           return date;
      case 'acctNo':         return acctNo;
      case 'concessionaire': return concessionaire;
      case 'address':        return address;
      case 'remarks':        return remarks;
      default:               return '';
    }
  }

  void setValue(String col, String val) {
    switch (col) {
      case 'date':           date = val;           break;
      case 'acctNo':         acctNo = val;         break;
      case 'concessionaire': concessionaire = val; break;
      case 'address':        address = val;        break;
      case 'remarks':        remarks = val;        break;
    }
  }
}

// ─── RelocationReportScreen ───────────────────────────────────────────────────

class RelocationReportScreen extends StatefulWidget {
  const RelocationReportScreen({super.key});

  @override
  State<RelocationReportScreen> createState() => _RelocationReportScreenState();
}

class _RelocationReportScreenState extends State<RelocationReportScreen> {
  Tk get _tk => context.tk;

  List<RelocationRow> _rows = [];
  bool _isLoading = true;

  int? _selRow;
  String? _selCol;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear  = DateTime.now().year;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode>             _focusNodes  = {};

  static const List<String> _columns = [
    'no', 'date', 'acctNo', 'concessionaire', 'address', 'remarks',
  ];

  static const Map<String, String> _headers = {
    'no':             'No.',
    'date':           'Date\nAccomplished',
    'acctNo':         'Account\nNumber',
    'concessionaire': 'Concessionaire',
    'address':        'Address',
    'remarks':        'Remarks',
  };

  static const Map<String, double> _colWidths = {
    'no':             52,
    'date':           135,
    'acctNo':         155,
    'concessionaire': 210,
    'address':        190,
    'remarks':        230,
  };

  static const Set<String> _editableCols = {
    'date', 'acctNo', 'concessionaire', 'address', 'remarks',
  };

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchRelocationJobs();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    for (final f in _focusNodes.values)  f.dispose();
    super.dispose();
  }

  // ─── Data fetch ───────────────────────────────────────────────────────────

  Future<void> _fetchRelocationJobs() async {
    setState(() => _isLoading = true);
    try {
      final start = DateTime(_selectedYear, _selectedMonth, 1);
      final end   = DateTime(_selectedYear, _selectedMonth + 1, 1);

      final raw = await Supabase.instance.client
          .from('job_orders')
          .select('id, address, remarks, completed_at, zone')
          .eq('status', 'accomplished')
          .eq('work_type_code', '301')
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .order('created_at', ascending: true);

      final dateFmt = DateFormat('MM/dd/yyyy');
      String fmtDate(dynamic v) {
        if (v == null) return '';
        try { return dateFmt.format(DateTime.parse(v.toString()).toLocal()); }
        catch (_) { return v.toString(); }
      }

      // Dispose stale controllers
      for (final c in _controllers.values) c.dispose();
      for (final f in _focusNodes.values)  f.dispose();
      _controllers.clear();
      _focusNodes.clear();

      final newRows = <RelocationRow>[];
      for (int i = 0; i < raw.length; i++) {
        final j = raw[i];
        newRows.add(RelocationRow(
          no:      i + 1,
          date:    fmtDate(j['completed_at']),
          address: j['address']?.toString() ?? '',
          remarks: j['remarks']?.toString() ?? '',
        ));
      }

      if (newRows.isEmpty) {
        for (int i = 0; i < 5; i++) newRows.add(RelocationRow(no: i + 1));
      }

      for (int r = 0; r < newRows.length; r++) {
        for (final col in _editableCols) {
          final key = '$r-$col';
          _controllers[key] = TextEditingController(text: newRows[r].getValue(col));
          _focusNodes[key]  = FocusNode()
            ..addListener(() {
              if (_focusNodes[key]!.hasFocus) {
                setState(() { _selRow = r; _selCol = col; });
              }
            });
        }
      }

      setState(() {
        _rows      = newRows;
        _isLoading = false;
        _selRow    = null;
        _selCol    = null;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('Error: $e')),
            ]),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ─── Row management ───────────────────────────────────────────────────────

  void _addRow() {
    final r = _rows.length;
    final newRow = RelocationRow(no: r + 1);
    for (final col in _editableCols) {
      final key = '$r-$col';
      _controllers[key] = TextEditingController();
      _focusNodes[key]  = FocusNode()
        ..addListener(() {
          if (_focusNodes[key]!.hasFocus) {
            setState(() { _selRow = r; _selCol = col; });
          }
        });
    }
    setState(() => _rows.add(newRow));
  }

  void _deleteLastRow() {
    if (_rows.isEmpty) return;
    final r = _rows.length - 1;
    for (final col in _editableCols) {
      final key = '$r-$col';
      _controllers[key]?.dispose();
      _controllers.remove(key);
      _focusNodes[key]?.dispose();
      _focusNodes.remove(key);
    }
    setState(() {
      _rows.removeLast();
      if (_selRow == r) { _selRow = null; _selCol = null; }
    });
  }

  void _syncFromControllers() {
    for (int r = 0; r < _rows.length; r++) {
      for (final col in _editableCols) {
        final key = '$r-$col';
        if (_controllers.containsKey(key)) {
          _rows[r].setValue(col, _controllers[key]!.text);
        }
      }
    }
  }

  // ─── PDF Export ───────────────────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    _syncFromControllers();
    final monthName = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    const colFlex = <double>[0.4, 1.2, 1.4, 1.8, 1.6, 2.0];
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(13 * PdfPageFormat.inch, 8.5 * PdfPageFormat.inch),
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        build: (ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SAN PABLO CITY WATER DISTRICT',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('San Pablo City', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 6),
              pw.Text('RELOCATION OF WATER METERS',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('For the month of $monthName', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
            columnWidths: {
              for (int i = 0; i < colFlex.length; i++)
                i: pw.FlexColumnWidth(colFlex[i]),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
                children: _columns.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(_headers[c]!,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                )).toList(),
              ),
              ..._rows.asMap().entries.map((entry) {
                final i   = entry.key;
                final row = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.grey100 : PdfColors.white),
                  children: _columns.map((col) {
                    final isLeft = col == 'concessionaire' || col == 'address' || col == 'remarks';
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: pw.Text(
                        row.getValue(col),
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: isLeft ? pw.TextAlign.left : pw.TextAlign.center,
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('Total: ${_rows.length}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'relocation_report_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf',
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));

    return Scaffold(
      backgroundColor: _tk.bg,
      body: Column(
        children: [
          _buildHeader(monthName),
          _buildToolbar(),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _rows.isEmpty
                ? _buildEmptyState(monthName)
                : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(24),
                child: _buildTableWidget(monthName),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(String monthName) {
    final isDark = _tk.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0B1220), const Color(0xFF0F1D36)]
              : [_kPrimary, _kPrimaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(isDark ? 0.3 : 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              // Titles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Relocation Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'Water Meter Relocations • $monthName',
                      style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              // Month/Year picker
              _ModernMonthYearPicker(
                month: _selectedMonth,
                year: _selectedYear,
                onChanged: (m, y) {
                  setState(() {
                    _selectedMonth = m;
                    _selectedYear  = y;
                  });
                  _fetchRelocationJobs();
                },
              ),
              const SizedBox(width: 12),
              // Refresh
              _HeaderIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onTap: _fetchRelocationJobs,
              ),
              const SizedBox(width: 8),
              // PDF
              _HeaderTextButton(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Export PDF',
                onTap: _rows.isEmpty ? null : _downloadPdf,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Toolbar ─────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      color: _tk.surf,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Record count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPrimary.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_horiz_rounded, size: 13, color: _kPrimary.withOpacity(0.8)),
                const SizedBox(width: 5),
                Text(
                  '${_rows.length} record${_rows.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: _kPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Spacer(),
          _ToolbarButton(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            color: Colors.grey.shade700,
            onTap: _fetchRelocationJobs,
          ),
          if (AppSession.instance.canEditReports) ...[
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.add_rounded,
              label: 'Add Row',
              color: _kPrimary,
              onTap: _addRow,
            ),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.remove_circle_outline_rounded,
              label: 'Delete Last',
              color: Colors.red.shade600,
              onTap: _rows.isNotEmpty ? _deleteLastRow : null,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Loading ──────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text('Loading records…', style: TextStyle(color: _tk.txtMuted, fontSize: 14)),
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(String monthName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.swap_horiz_rounded, size: 48, color: _kPrimary.withOpacity(0.35)),
          ),
          const SizedBox(height: 20),
          Text(
            'No relocations for $monthName',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different month or add a row manually.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Row'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Spreadsheet table ────────────────────────────────────────────────────

  Widget _buildTableWidget(String monthName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title block
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SAN PABLO CITY WATER DISTRICT',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: Color(0xFF0D47A1),
              ),
            ),
            Text(
              'Relocation of Water Meters — $monthName',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Table(
              border: TableBorder.all(color: _kBorder, width: 1),
              columnWidths: {
                for (int i = 0; i < _columns.length; i++)
                  i: FixedColumnWidth(_colWidths[_columns[i]]!),
                _columns.length: const FixedColumnWidth(46),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _buildHeaderRow(),
                ..._rows.asMap().entries.map((e) => _buildDataRow(e.key, e.value)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kTableHeader, _kPrimaryLight],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                'Total Relocations: ${_rows.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kTableHeader, _kPrimaryLight]),
      ),
      children: [
        ..._columns.map((col) => TableCell(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            child: Text(
              _headers[col]!,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        )),
        const TableCell(child: SizedBox(width: 46)),
      ],
    );
  }

  TableRow _buildDataRow(int i, RelocationRow row) {
    final isRowSel = _selRow == i;
    final rowBg = isRowSel
        ? const Color(0xFFEFF6FF)
        : (i.isEven ? _kRowEven : _kRowOdd);

    return TableRow(
      decoration: BoxDecoration(color: rowBg),
      children: [
        ..._columns.map((col) {
          final isCellSel  = isRowSel && _selCol == col;
          final isEditable = _editableCols.contains(col) && AppSession.instance.canEditReports;
          final key        = '$i-$col';

          return TableCell(
            child: GestureDetector(
              onTap: () => setState(() { _selRow = i; _selCol = col; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: isCellSel
                    ? BoxDecoration(
                  border: Border.all(color: _kPrimary, width: 2),
                  color: _kPrimary.withOpacity(0.04),
                )
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: isEditable
                    ? TextField(
                  controller: _controllers[key],
                  focusNode: _focusNodes[key],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  onChanged: (v) => row.setValue(col, v),
                )
                    : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    row.getValue(col),
                    textAlign: col == 'no' ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      fontSize: 12,
                      color: col == 'no' ? Colors.grey[500] : Colors.black87,
                      fontWeight: col == 'no' ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),

        // Delete button
        TableCell(
          child: Center(
            child: Tooltip(
              message: 'Remove row',
              child: InkWell(
                onTap: () {
                  // Remove this specific row
                  for (final col in _editableCols) {
                    final key = '$i-$col';
                    _controllers[key]?.dispose();
                    _controllers.remove(key);
                    _focusNodes[key]?.dispose();
                    _focusNodes.remove(key);
                  }
                  setState(() {
                    _rows.removeAt(i);
                    for (int j = i; j < _rows.length; j++) _rows[j].no = j + 1;
                    if (_selRow == i) { _selRow = null; _selCol = null; }
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.red[400]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── _ModernMonthYearPicker ───────────────────────────────────────────────────

class _ModernMonthYearPicker extends StatelessWidget {
  final int month;
  final int year;
  final void Function(int month, int year) onChanged;

  const _ModernMonthYearPicker({
    required this.month,
    required this.year,
    required this.onChanged,
  });

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final curYear = DateTime.now().year;
    // Wide range: 3 years back, 2 years forward
    final years = List.generate(6, (i) => curYear - 3 + i);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: month,
              dropdownColor: const Color(0xFF1E3A5F),
              iconEnabledColor: Colors.white70,
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              items: List.generate(12, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(_months[i], style: const TextStyle(color: Colors.white, fontSize: 13)),
              )),
              onChanged: (v) => onChanged(v!, year),
            ),
          ),
          Container(width: 1, height: 20, color: Colors.white.withOpacity(0.25)),
          // Year
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: years.contains(year) ? year : years.last,
              dropdownColor: const Color(0xFF1E3A5F),
              iconEnabledColor: Colors.white70,
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              items: years.map((y) => DropdownMenuItem(
                value: y,
                child: Text('$y', style: const TextStyle(color: Colors.white, fontSize: 13)),
              )).toList(),
              onChanged: (v) => onChanged(month, v!),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _HeaderIconButton ────────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _HeaderIconButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

// ─── _HeaderTextButton ────────────────────────────────────────────────────────

class _HeaderTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _HeaderTextButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedOpacity(
          opacity: disabled ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: _kPrimary, size: 16),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── _ToolbarButton ───────────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ToolbarButton({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return AnimatedOpacity(
      opacity: disabled ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}