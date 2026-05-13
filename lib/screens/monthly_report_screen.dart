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

// Legal paper LANDSCAPE: 13 × 8.5 inches
const PdfPageFormat _legalLandscape = PdfPageFormat(
  13 * PdfPageFormat.inch,
  8.5 * PdfPageFormat.inch,
);

// ─── CellFormat ───────────────────────────────────────────────────────────────

class CellFormat {
  bool bold;
  bool italic;
  bool underline;
  bool justify;
  double fontSize;

  CellFormat({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.justify = false,
    this.fontSize = 13,
  });

  CellFormat copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? justify,
    double? fontSize,
  }) =>
      CellFormat(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        justify: justify ?? this.justify,
        fontSize: fontSize ?? this.fontSize,
      );
}

// ─── ReportRow ────────────────────────────────────────────────────────────────

class ReportRow {
  int no;
  String remarks;
  String address;
  String foreman;
  String dateReported;
  String dateAccomplished;
  String workType;
  String zone;
  Map<String, CellFormat> formats;

  ReportRow({
    required this.no,
    this.remarks = '',
    this.address = '',
    this.foreman = '',
    this.dateReported = '',
    this.dateAccomplished = '',
    this.workType = '',
    this.zone = '',
    Map<String, CellFormat>? formats,
  }) : formats = formats ?? {};

  CellFormat formatOf(String col) => formats[col] ?? CellFormat();

  String getValue(String col) {
    switch (col) {
      case 'no':
        return '$no';
      case 'remarks':
        return remarks;
      case 'address':
        return address;
      case 'foreman':
        return foreman;
      case 'dateReported':
        return dateReported;
      case 'dateAccomplished':
        return dateAccomplished;
      case 'workType':
        return workType;
      case 'zone':
        return zone;
      default:
        return '';
    }
  }

  void setValue(String col, String val) {
    switch (col) {
      case 'remarks':
        remarks = val;
        break;
      case 'address':
        address = val;
        break;
      case 'foreman':
        foreman = val;
        break;
      case 'dateReported':
        dateReported = val;
        break;
      case 'dateAccomplished':
        dateAccomplished = val;
        break;
      case 'workType':
        workType = val;
        break;
      case 'zone':
        zone = val;
        break;
    }
  }
}

// ─── MonthlyReportScreen ──────────────────────────────────────────────────────

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  static const _accent = Color(0xFF1565C0);
  static const _accentLight = Color(0xFF1976D2);

  Tk get _tk => context.tk;

  List<ReportRow> _rows = [];
  bool _isLoading = true;

  int? _selRow;
  String? _selCol;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  static const List<String> _columns = [
    'no',
    'address',
    'foreman',
    'dateReported',
    'dateAccomplished',
    'workType',
    'remarks',
    'zone',
  ];

  static const Map<String, String> _headers = {
    'no': 'No.',
    'address': 'Address',
    'foreman': 'Foreman',
    'dateReported': 'Date Reported',
    'dateAccomplished': 'Date Accomplished',
    'workType': 'Description\n(Work Type)',
    'remarks': 'Remarks',
    'zone': 'Zone',
  };

  static const Map<String, double> _colWidths = {
    'no': 52,
    'address': 165,
    'foreman': 155,
    'dateReported': 145,
    'dateAccomplished': 155,
    'workType': 235,
    'remarks': 205,
    'zone': 75,
  };

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchAccomplished();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    for (final f in _focusNodes.values) f.dispose();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _key(int rowIdx, String col) => '$rowIdx:$col';

  TextEditingController _ctrl(int rowIdx, String col) {
    final k = _key(rowIdx, col);
    return _controllers.putIfAbsent(
      k,
          () => TextEditingController(text: _rows[rowIdx].getValue(col)),
    );
  }

  FocusNode _focus(int rowIdx, String col) {
    final k = _key(rowIdx, col);
    return _focusNodes.putIfAbsent(k, FocusNode.new);
  }

  // ─── Data fetch ───────────────────────────────────────────────────────────

  Future<void> _fetchAccomplished() async {
    setState(() => _isLoading = true);
    try {
      final start = DateTime(_selectedYear, _selectedMonth, 1);
      final end = DateTime(_selectedYear, _selectedMonth + 1, 1);

      final jobsRaw = await Supabase.instance.client
          .from('job_orders')
          .select('''
            id, remarks, address, zone,
            work_type_code, work_type_name,
            created_at, completed_at,
            leader_id, team_id,
            team:team_id ( foreman:foreman_id (name) )
          ''')
          .eq('status', 'accomplished')
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .order('created_at', ascending: true);

      final leaderIds = <String>{};
      for (final j in jobsRaw) {
        if (j['leader_id'] != null) leaderIds.add(j['leader_id'] as String);
      }

      Map<String, String> leaderNames = {};
      if (leaderIds.isNotEmpty) {
        final personnel = await Supabase.instance.client
            .from('personnel')
            .select('id, name')
            .inFilter('id', leaderIds.toList());
        for (final p in personnel) {
          leaderNames[p['id'] as String] = p['name'] as String? ?? '';
        }
      }

      final dateFmt = DateFormat('MM/dd/yyyy');
      String fmtDate(dynamic raw) {
        if (raw == null) return '';
        try {
          return dateFmt.format(DateTime.parse(raw.toString()).toLocal());
        } catch (_) {
          return raw.toString();
        }
      }

      final newRows = <ReportRow>[];
      for (int i = 0; i < jobsRaw.length; i++) {
        final j = jobsRaw[i];
        String foremanName = '';
        if (j['leader_id'] != null) foremanName = leaderNames[j['leader_id']] ?? '';
        if (foremanName.isEmpty) foremanName = (j['team']?['foreman']?['name'] as String?) ?? '';

        newRows.add(ReportRow(
          no: i + 1,
          remarks: j['remarks'] as String? ?? '',
          address: j['address'] as String? ?? '',
          foreman: foremanName,
          dateReported: fmtDate(j['created_at']),
          dateAccomplished: fmtDate(j['completed_at']),
          workType: [
            j['work_type_code']?.toString() ?? '',
            j['work_type_name']?.toString() ?? '',
          ].where((s) => s.isNotEmpty).join('  '),
          zone: j['zone']?.toString() ?? '',
        ));
      }

      for (final c in _controllers.values) c.dispose();
      _controllers.clear();
      for (final f in _focusNodes.values) f.dispose();
      _focusNodes.clear();

      setState(() {
        _rows = newRows;
        _isLoading = false;
        _selRow = null;
        _selCol = null;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('Error loading data: $e')),
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
    setState(() => _rows.add(ReportRow(no: _rows.length + 1)));
  }

  void _removeRow(int idx) {
    for (final col in _columns) {
      final k = _key(idx, col);
      _controllers.remove(k)?.dispose();
      _focusNodes.remove(k)?.dispose();
    }
    setState(() {
      _rows.removeAt(idx);
      for (int i = idx; i < _rows.length; i++) _rows[i].no = i + 1;
      if (_selRow == idx) {
        _selRow = null;
        _selCol = null;
      }
    });
  }

  // ─── Formatting ───────────────────────────────────────────────────────────

  void _toggleFormat(String prop) {
    if (_selRow == null || _selCol == null) return;
    final r = _rows[_selRow!];
    final fmt = r.formatOf(_selCol!);
    setState(() {
      r.formats[_selCol!] = switch (prop) {
        'bold' => fmt.copyWith(bold: !fmt.bold),
        'italic' => fmt.copyWith(italic: !fmt.italic),
        'underline' => fmt.copyWith(underline: !fmt.underline),
        'justify' => fmt.copyWith(justify: !fmt.justify),
        _ => fmt,
      };
    });
  }

  void _changeFontSize(double size) {
    if (_selRow == null || _selCol == null) return;
    setState(() {
      _rows[_selRow!].formats[_selCol!] =
          _rows[_selRow!].formatOf(_selCol!).copyWith(fontSize: size);
    });
  }

  // ─── PDF Export ───────────────────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    pw.ThemeData? pdfTheme;
    try {
      final regular = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();
      final italic = await PdfGoogleFonts.robotoItalic();
      pdfTheme = pw.ThemeData.withFont(base: regular, bold: bold, italic: italic);
    } catch (_) {}

    final pdf = pw.Document(theme: pdfTheme);
    final monthName = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    const colFlex = <double>[0.5, 1.8, 1.6, 1.6, 1.6, 2.4, 2.0, 0.7];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: _legalLandscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        build: (ctx) => [
          pw.Center(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('SAN PABLO CITY WATER DISTRICT',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text('Monthly Accomplished Jobs Report',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('For the month of $monthName',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
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
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8)),
                )).toList(),
              ),
              ..._rows.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.grey100 : PdfColors.white),
                  children: _columns.map((col) {
                    final fmt = row.formatOf(col);
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: pw.Text(
                        row.getValue(col),
                        style: pw.TextStyle(
                          fontSize: (fmt.fontSize * 0.65).clamp(6.5, 9.5),
                          fontWeight: fmt.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                          fontStyle: fmt.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
                          decoration: fmt.underline ? pw.TextDecoration.underline : pw.TextDecoration.none,
                        ),
                        textAlign: fmt.justify ? pw.TextAlign.justify : pw.TextAlign.left,
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total Accomplished: ${_rows.length}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'monthly_report_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf',
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    final CellFormat? selFmt = (_selRow != null && _selCol != null)
        ? _rows[_selRow!].formatOf(_selCol!)
        : null;

    return Scaffold(
      backgroundColor: _tk.bg,
      body: Column(
        children: [
          _buildHeader(monthName),
          if (AppSession.instance.canEditReports) _buildToolbar(selFmt),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _rows.isEmpty
                ? _buildEmptyState(monthName)
                : _buildTable(monthName),
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
              : [_accent, _accentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(isDark ? 0.3 : 0.4),
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
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              // Titles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'Accomplished Jobs • $monthName',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 12.5,
                      ),
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
                    _selectedYear = y;
                  });
                  _fetchAccomplished();
                },
              ),
              const SizedBox(width: 12),
              // Refresh button
              _HeaderIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onTap: _fetchAccomplished,
              ),
              const SizedBox(width: 8),
              // PDF button
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

  Widget _buildToolbar(CellFormat? selFmt) {
    return Container(
      color: _tk.surf,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text('Format:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ),
          const SizedBox(width: 10),
          _FmtBtn(label: 'B', tooltip: 'Bold', bold: true, active: selFmt?.bold ?? false, onTap: () => _toggleFormat('bold')),
          _FmtBtn(label: 'I', tooltip: 'Italic', italic: true, active: selFmt?.italic ?? false, onTap: () => _toggleFormat('italic')),
          _FmtBtn(label: 'U', tooltip: 'Underline', underline: true, active: selFmt?.underline ?? false, onTap: () => _toggleFormat('underline')),
          _FmtBtn(label: '≡', tooltip: 'Justify', active: selFmt?.justify ?? false, onTap: () => _toggleFormat('justify')),
          const SizedBox(width: 12),
          const Text('Size:', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(width: 6),
          _SizeDropdown(value: selFmt?.fontSize ?? 13, onChanged: _selRow != null ? _changeFontSize : null),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _tk.surf2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _tk.bd2!),
            ),
            child: const Text('Arial', style: TextStyle(fontSize: 12, color: Colors.black87)),
          ),
          const Spacer(),
          // Record count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.table_rows_rounded, size: 13, color: _accent.withOpacity(0.8)),
                const SizedBox(width: 5),
                Text(
                  '${_rows.length} record${_rows.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: _accent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (AppSession.instance.canEditReports)
            _ToolbarButton(
              icon: Icons.add_rounded,
              label: 'Add Row',
              color: _accent,
              onTap: _addRow,
            ),
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
            child: CircularProgressIndicator(
              color: _accent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading records…',
            style: TextStyle(color: _tk.txtMuted, fontSize: 14),
          ),
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
              color: _accent.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.table_chart_outlined, size: 48, color: _accent.withOpacity(0.35)),
          ),
          const SizedBox(height: 20),
          Text(
            'No accomplished jobs for $monthName',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a different month or add a row manually.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Row'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
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

  // ─── Table ────────────────────────────────────────────────────────────────

  Widget _buildTable(String monthName) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title above table
            Row(
              children: [
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
                      'Monthly Accomplished Jobs Report — $monthName',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table container
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
                  border: TableBorder.all(color: const Color(0xFFCBD5E1), width: 1),
                  columnWidths: {
                    for (int i = 0; i < _columns.length; i++)
                      i: FixedColumnWidth(_colWidths[_columns[i]]!),
                    _columns.length: const FixedColumnWidth(46),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    _buildHeaderRow(),
                    ..._rows.asMap().entries.map((entry) => _buildDataRow(entry.key, entry.value)),
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
                  colors: [Color(0xFF1E3A5F), Color(0xFF1565C0)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Total Accomplished: ${_rows.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF1565C0)],
        ),
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

  TableRow _buildDataRow(int i, ReportRow row) {
    final isRowSelected = _selRow == i;
    final rowBg = isRowSelected
        ? const Color(0xFFEFF6FF)
        : (i.isEven ? Colors.white : const Color(0xFFF8FAFC));

    return TableRow(
      decoration: BoxDecoration(color: rowBg),
      children: [
        ..._columns.map((col) {
          final isCellSelected = isRowSelected && _selCol == col;
          final fmt = row.formatOf(col);
          final isReadOnly = col == 'no' || !AppSession.instance.canEditReports;

          return TableCell(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selRow = i;
                  _selCol = col;
                });
                if (!isReadOnly) _focus(i, col).requestFocus();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: isCellSelected
                    ? BoxDecoration(
                  border: Border.all(color: _accent, width: 2),
                  color: _accent.withOpacity(0.04),
                )
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: isReadOnly
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '${row.no}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600),
                  ),
                )
                    : TextField(
                  controller: _ctrl(i, col),
                  focusNode: _focus(i, col),
                  onChanged: (v) => row.setValue(col, v),
                  onTap: () => setState(() {
                    _selRow = i;
                    _selCol = col;
                  }),
                  maxLines: null,
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: fmt.fontSize,
                    fontWeight: fmt.bold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: fmt.italic ? FontStyle.italic : FontStyle.normal,
                    decoration: fmt.underline ? TextDecoration.underline : TextDecoration.none,
                    color: Colors.black87,
                  ),
                  textAlign: fmt.justify ? TextAlign.justify : TextAlign.left,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
          );
        }),

        // Delete cell
        TableCell(
          child: Center(
            child: Tooltip(
              message: 'Remove row',
              child: InkWell(
                onTap: () => _removeRow(i),
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
          // Month dropdown
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
          // Year dropdown
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
                Icon(icon, color: const Color(0xFF1565C0), size: 16),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Color(0xFF1565C0), fontSize: 13, fontWeight: FontWeight.w700)),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
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
    );
  }
}

// ─── _FmtBtn ──────────────────────────────────────────────────────────────────

class _FmtBtn extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool active;
  final bool bold;
  final bool italic;
  final bool underline;
  final VoidCallback onTap;

  const _FmtBtn({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.onTap,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(right: 5),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1565C0).withOpacity(0.11) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: active ? const Color(0xFF1565C0) : const Color(0xFFCBD5E1)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                decoration: underline ? TextDecoration.underline : null,
                color: active ? const Color(0xFF1565C0) : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── _SizeDropdown ────────────────────────────────────────────────────────────

class _SizeDropdown extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;

  const _SizeDropdown({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    const sizes = [9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 16.0, 18.0, 20.0, 24.0];
    final safeValue = sizes.contains(value) ? value : 13.0;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: safeValue,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items: sizes.map((s) => DropdownMenuItem(
            value: s,
            child: Text(s.toInt().toString(), style: const TextStyle(fontSize: 12)),
          )).toList(),
          onChanged: onChanged != null ? (v) => onChanged!(v!) : null,
        ),
      ),
    );
  }
}