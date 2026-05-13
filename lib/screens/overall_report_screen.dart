import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/session/session.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Short / Letter paper: 8.5 × 11 inches
const PdfPageFormat _shortPortrait = PdfPageFormat(
  8.5 * PdfPageFormat.inch,
  11.0 * PdfPageFormat.inch,
);

// ─── RichStyle – stores formatting for each editable header line ──────────────

class RichStyle {
  bool bold;
  bool italic;
  bool underline;
  bool justify;
  double fontSize;
  String align; // 'left' | 'center' | 'right'

  RichStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.justify = false,
    this.fontSize = 13,
    this.align = 'center',
  });

  RichStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? justify,
    double? fontSize,
    String? align,
  }) {
    return RichStyle(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      justify: justify ?? this.justify,
      fontSize: fontSize ?? this.fontSize,
      align: align ?? this.align,
    );
  }

  TextAlign get textAlign {
    if (justify) return TextAlign.justify;
    switch (align) {
      case 'right':
        return TextAlign.right;
      case 'left':
        return TextAlign.left;
      default:
        return TextAlign.center;
    }
  }

  FontWeight get fontWeight => bold ? FontWeight.bold : FontWeight.normal;
  FontStyle get fontStyle => italic ? FontStyle.italic : FontStyle.normal;
  TextDecoration get decoration =>
      underline ? TextDecoration.underline : TextDecoration.none;
}

// ─── PipeEntry – one row in the pipe detail table ─────────────────────────────

class PipeEntry {
  TextEditingController location;
  TextEditingController quantity;
  TextEditingController pipeDiameter;

  PipeEntry({String loc = '', String qty = '', String dia = ''})
      : location = TextEditingController(text: loc),
        quantity = TextEditingController(text: qty),
        pipeDiameter = TextEditingController(text: dia);

  void dispose() {
    location.dispose();
    quantity.dispose();
    pipeDiameter.dispose();
  }
}

// ─── OverallReportScreen ──────────────────────────────────────────────────────

class OverallReportScreen extends StatefulWidget {
  const OverallReportScreen({super.key});

  @override
  State<OverallReportScreen> createState() => _OverallReportScreenState();
}

class _OverallReportScreenState extends State<OverallReportScreen> {
  Tk get _tk => context.tk;

  // ── Month / Year ────────────────────────────────────────────────────────────
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  bool _isLoading = true;
  bool _editMode = false;

  // ── Editable header fields ──────────────────────────────────────────────────
  final _hLine1Ctrl =
  TextEditingController(text: 'SAN PABLO CITY WATER DISTRICT');
  final _hLine2Ctrl = TextEditingController(text: 'San Pablo City');
  final _hLine3Ctrl =
  TextEditingController(text: 'OPERATIONS DEPARTMENT');
  final _hLine4Ctrl = TextEditingController(
      text: 'Pipelines & Appurtenances Maintenance Division');
  final _hLine5Ctrl =
  TextEditingController(text: 'Monthly Accomplishment Report');

  RichStyle _h1Style = RichStyle(bold: true, fontSize: 16, align: 'center');
  RichStyle _h2Style = RichStyle(fontSize: 12, align: 'center');
  RichStyle _h3Style = RichStyle(bold: true, fontSize: 13, align: 'center');
  RichStyle _h4Style = RichStyle(fontSize: 11, align: 'center');
  RichStyle _h5Style = RichStyle(bold: true, fontSize: 12, align: 'center');

  // Which header line is focused in the toolbar ('h1'..'h5' or null)
  String? _focusedHeader;

  // ── DB stats (this month, auto-computed) ────────────────────────────────────
  // FIX: These now only count non-deleted, non-trashed accomplished jobs,
  // matching the dashboard logic. skeletal_job (status='completed') is also
  // included so both screens tally the same numbers.
  int _thisComplaints = 0;   // accomplished job_orders + completed skeletal_job
  int _thisActed = 0;        // same — every accomplished/completed row IS "acted upon"
  int _thisService = 0;      // work_type_code IN ('101','102') — both tables
  int _thisDistRep = 0;      // work_type_code = '103' — both tables
  int _thisRestoration = 0;  // work_type_code = '203' — both tables
  int _thisWaterMeterA = 0;  // work_type_code = '204' — both tables

  // ── Editable previous-month column fields ───────────────────────────────────
  final _pComplaintsCtrl = TextEditingController();
  final _pActedCtrl = TextEditingController();
  final _pServiceCtrl = TextEditingController();
  final _pDistRepCtrl = TextEditingController();
  final _pDistLenCtrl = TextEditingController();
  final _pRestoCtrl = TextEditingController();
  final _pWaterACtrl = TextEditingController();
  final _pWaterBCtrl = TextEditingController();

  // ── Editable this-month manual fields ──────────────────────────────────────
  final _tDistLenCtrl = TextEditingController(); // item 5 – length text
  final _tWaterBCtrl = TextEditingController();  // item 7b – count

  // ── Pipe table rows ─────────────────────────────────────────────────────────
  final List<PipeEntry> _pipeRows = [PipeEntry(), PipeEntry()];

  // ── Signatories ─────────────────────────────────────────────────────────────
  final _s1Name = TextEditingController(text: 'Name here');
  final _s1Title = TextEditingController(text: 'Position Here');
  final _s2Name = TextEditingController(text: 'Name Here');
  final _s2Title = TextEditingController(text: 'Position Here');
  final _s3Name = TextEditingController(text: 'Name Here');
  final _s3Title = TextEditingController(text: 'Position Here');

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in [
      _hLine1Ctrl, _hLine2Ctrl, _hLine3Ctrl, _hLine4Ctrl, _hLine5Ctrl,
      _pComplaintsCtrl, _pActedCtrl, _pServiceCtrl, _pDistRepCtrl,
      _pDistLenCtrl, _pRestoCtrl, _pWaterACtrl, _pWaterBCtrl,
      _tDistLenCtrl, _tWaterBCtrl,
      _s1Name, _s1Title, _s2Name, _s2Title, _s3Name, _s3Title,
    ]) {
      c.dispose();
    }
    for (final r in _pipeRows) {
      r.dispose();
    }
    super.dispose();
  }

  // ── Date helpers ────────────────────────────────────────────────────────────

  DateTime get _monthStart => DateTime(_year, _month, 1);
  DateTime get _monthEnd => DateTime(_year, _month + 1, 1);
  DateTime get _prevStart => DateTime(_year, _month - 1, 1);
  DateTime get _prevEnd => _monthStart;

  String get _monthName =>
      DateFormat('MMMM yyyy').format(DateTime(_year, _month));
  String get _prevMonthName =>
      DateFormat('MMMM yyyy').format(DateTime(_year, _month - 1));

  // ── Computed totals ─────────────────────────────────────────────────────────

  int get _totalComplaints =>
      _thisComplaints + (int.tryParse(_pComplaintsCtrl.text) ?? 0);
  int get _totalActed =>
      _thisActed + (int.tryParse(_pActedCtrl.text) ?? 0);
  int get _totalService =>
      _thisService + (int.tryParse(_pServiceCtrl.text) ?? 0);
  int get _totalDistRep =>
      _thisDistRep + (int.tryParse(_pDistRepCtrl.text) ?? 0);
  int get _totalResto =>
      _thisRestoration + (int.tryParse(_pRestoCtrl.text) ?? 0);
  int get _totalWaterA =>
      _thisWaterMeterA + (int.tryParse(_pWaterACtrl.text) ?? 0);
  int get _thisWaterB => int.tryParse(_tWaterBCtrl.text) ?? 0;
  int get _totalWaterB =>
      _thisWaterB + (int.tryParse(_pWaterBCtrl.text) ?? 0);

  // ── Data load ───────────────────────────────────────────────────────────────
  // FIX: Mirror the exact same query logic as DashboardScreen:
  //   • job_orders  → status = 'accomplished', completed_at NOT NULL
  //   • skeletal_job → status = 'completed',   completed_at NOT NULL
  //   • Filter by completed_at (not created_at) so the month matches the
  //     dashboard's accomplished count for the same period.
  //   • Deleted / trashed rows have a different status (e.g. 'deleted',
  //     'cancelled') so they are naturally excluded by the status filter.

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sb = Supabase.instance.client;

      // ── This month — job_orders ──────────────────────────────────────────
      final thisJO = await sb
          .from('job_orders')
          .select('work_type_code, status, completed_at')
          .eq('status', 'accomplished')
          .not('completed_at', 'is', null)
          .gte('completed_at', _monthStart.toIso8601String())
          .lt('completed_at', _monthEnd.toIso8601String());

      // ── This month — skeletal_job ────────────────────────────────────────
      final thisSkel = await sb
          .from('skeletal_job')
          .select('work_type_code, status, completed_at')
          .eq('status', 'completed')
          .not('completed_at', 'is', null)
          .gte('completed_at', _monthStart.toIso8601String())
          .lt('completed_at', _monthEnd.toIso8601String());

      // ── Previous month — job_orders ──────────────────────────────────────
      final prevJO = await sb
          .from('job_orders')
          .select('work_type_code, status, completed_at')
          .eq('status', 'accomplished')
          .not('completed_at', 'is', null)
          .gte('completed_at', _prevStart.toIso8601String())
          .lt('completed_at', _prevEnd.toIso8601String());

      // ── Previous month — skeletal_job ────────────────────────────────────
      final prevSkel = await sb
          .from('skeletal_job')
          .select('work_type_code, status, completed_at')
          .eq('status', 'completed')
          .not('completed_at', 'is', null)
          .gte('completed_at', _prevStart.toIso8601String())
          .lt('completed_at', _prevEnd.toIso8601String());

      // Merge both tables for each period
      final thisMerged = [
        ...List<Map<String, dynamic>>.from(thisJO),
        ...List<Map<String, dynamic>>.from(thisSkel),
      ];
      final prevMerged = [
        ...List<Map<String, dynamic>>.from(prevJO),
        ...List<Map<String, dynamic>>.from(prevSkel),
      ];

      // ── Helper: count by work_type_code in a list ────────────────────────
      int count(List<Map<String, dynamic>> rows, List<String> codes) =>
          rows.where((j) => codes.contains(j['work_type_code'] as String? ?? '')).length;

      // Previous month derived values
      final pC  = prevMerged.length;
      final pA  = pC; // every accomplished/completed row = acted upon
      final pS  = count(prevMerged, ['101', '102']);
      final pD  = count(prevMerged, ['103']);
      final pR  = count(prevMerged, ['203']);
      final pW  = count(prevMerged, ['204']);

      setState(() {
        // This month counts — all from merged accomplished/completed rows only
        _thisComplaints  = thisMerged.length;
        _thisActed       = thisMerged.length; // all accomplished = acted upon
        _thisService     = count(thisMerged, ['101', '102']);
        _thisDistRep     = count(thisMerged, ['103']);
        _thisRestoration = count(thisMerged, ['203']);
        _thisWaterMeterA = count(thisMerged, ['204']);

        // Pre-fill previous month fields only when empty
        if (_pComplaintsCtrl.text.isEmpty) _pComplaintsCtrl.text = '$pC';
        if (_pActedCtrl.text.isEmpty)      _pActedCtrl.text      = '$pA';
        if (_pServiceCtrl.text.isEmpty)    _pServiceCtrl.text    = '$pS';
        if (_pDistRepCtrl.text.isEmpty)    _pDistRepCtrl.text    = '$pD';
        if (_pDistLenCtrl.text.isEmpty)    _pDistLenCtrl.text    = '-';
        if (_pRestoCtrl.text.isEmpty)      _pRestoCtrl.text      = '$pR';
        if (_pWaterACtrl.text.isEmpty)     _pWaterACtrl.text     = '$pW';
        if (_pWaterBCtrl.text.isEmpty)     _pWaterBCtrl.text     = '-';

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Header style helpers ────────────────────────────────────────────────────

  RichStyle get _currentStyle {
    switch (_focusedHeader) {
      case 'h1': return _h1Style;
      case 'h2': return _h2Style;
      case 'h3': return _h3Style;
      case 'h4': return _h4Style;
      case 'h5': return _h5Style;
      default:   return RichStyle();
    }
  }

  void _applyStyle(RichStyle s) {
    setState(() {
      switch (_focusedHeader) {
        case 'h1': _h1Style = s; break;
        case 'h2': _h2Style = s; break;
        case 'h3': _h3Style = s; break;
        case 'h4': _h4Style = s; break;
        case 'h5': _h5Style = s; break;
      }
    });
  }

  void _toggleH(String prop) {
    final s = _currentStyle;
    _applyStyle(switch (prop) {
      'bold'      => s.copyWith(bold: !s.bold),
      'italic'    => s.copyWith(italic: !s.italic),
      'underline' => s.copyWith(underline: !s.underline),
      'justify'   => s.copyWith(justify: !s.justify, align: 'left'),
      'left'      => s.copyWith(align: 'left',   justify: false),
      'center'    => s.copyWith(align: 'center', justify: false),
      'right'     => s.copyWith(align: 'right',  justify: false),
      _           => s,
    });
  }

  // ── PDF export ───────────────────────────────────────────────────────────────

  Future<void> _printReport() async {
    final pdf = pw.Document();

    final tDistLen = _tDistLenCtrl.text.trim().isEmpty
        ? '-'
        : _tDistLenCtrl.text.trim();

    const double fsH1   = 15.0;
    const double fsH2   = 12.0;
    const double fsH3   = 13.0;
    const double fsH4   = 11.0;
    const double fsH5   = 12.0;
    const double fsDate = 10.5;
    const double fsCol  = 10.0;
    const double fsBody = 11.0;
    const double fsSig  = 10.0;

    final tableBorder =
    pw.TableBorder.all(width: 0.6, color: PdfColors.black);

    pw.Widget cc(String t, {bool bold = false}) => pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: pw.Text(t,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: fsBody,
              fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

    pw.Widget lc(String t, {bool bold = false}) => pw.Padding(
      padding:
      const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: pw.Text(t,
          style: pw.TextStyle(
              fontSize: fsBody,
              fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

    pw.Widget hc(String t) => pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: pw.Text(t,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: fsCol, fontWeight: pw.FontWeight.bold)),
    );

    pw.TableRow dr(String label, String prev, String cur, String tot,
        {bool bold = false}) =>
        pw.TableRow(children: [
          lc(label, bold: bold),
          cc(prev, bold: bold),
          cc(cur,  bold: bold),
          cc(tot,  bold: bold),
        ]);

    pw.Widget sig(String name, String title, {double topPad = 40}) =>
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: topPad),
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        top: pw.BorderSide(
                            width: 1.0, color: PdfColors.black)),
                  ),
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(name,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: fsSig,
                              fontWeight: pw.FontWeight.bold,
                              decoration: pw.TextDecoration.underline)),
                      pw.SizedBox(height: 3),
                      pw.Text(title,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: fsSig - 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    pdf.addPage(
      pw.Page(
        pageFormat: _shortPortrait,
        margin: const pw.EdgeInsets.fromLTRB(45, 36, 36, 30),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(_hLine1Ctrl.text,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: fsH1,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(_hLine2Ctrl.text,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: fsH2)),
                  pw.SizedBox(height: 4),
                  pw.Text(_hLine3Ctrl.text,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: fsH3,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(_hLine4Ctrl.text,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: fsH4)),
                  pw.SizedBox(height: 4),
                  pw.Text(_hLine5Ctrl.text,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: fsH5,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text('For the month of $_monthName',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: fsDate)),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Table(
              border: tableBorder,
              columnWidths: const {
                0: pw.FlexColumnWidth(4.0),
                1: pw.FlexColumnWidth(1.4),
                2: pw.FlexColumnWidth(1.4),
                3: pw.FlexColumnWidth(1.4),
              },
              children: [
                pw.TableRow(children: [
                  hc(''),
                  hc('Previous Report\n(Month of\n$_prevMonthName)'),
                  hc('This Report\n(Month of\n$_monthName)'),
                  hc('Total\n(Month of Jan\nto $_monthName)'),
                ]),
                dr('1  Complaints Received',
                    _pComplaintsCtrl.text, '$_thisComplaints',
                    '$_totalComplaints', bold: true),
                dr('2  Complaints Acted Upon',
                    _pActedCtrl.text, '$_thisActed',
                    '$_totalActed', bold: true),
                dr('3  Service Connection Repaired',
                    _pServiceCtrl.text, '$_thisService',
                    '$_totalService'),
                dr('4  Distribution Line Repaired',
                    _pDistRepCtrl.text, '$_thisDistRep',
                    '$_totalDistRep'),
                dr('5  Distribution Line Replaced (Length)',
                    _pDistLenCtrl.text, tDistLen, '-'),
                dr('6  Restoration',
                    _pRestoCtrl.text, '$_thisRestoration',
                    '$_totalResto'),
                pw.TableRow(children: [
                  lc('7  Water Meter Relocated', bold: true),
                  cc(''), cc(''), cc(''),
                ]),
                dr('     a. Special Project (outside prop.line)',
                    _pWaterACtrl.text, '$_thisWaterMeterA',
                    '$_totalWaterA'),
                dr('     b. Billed (Requested by concessioners)',
                    _pWaterBCtrl.text, '$_thisWaterB',
                    '$_totalWaterB'),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: tableBorder,
              columnWidths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FlexColumnWidth(2.8),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(children: [
                  hc('#'),
                  hc('Location'),
                  hc('Quantity'),
                  hc('Pipe Diameter'),
                ]),
                ..._pipeRows.asMap().entries.map((e) => pw.TableRow(
                  children: [
                    cc('${e.key + 1}'),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      child: pw.Text(e.value.location.text,
                          style: pw.TextStyle(fontSize: fsBody)),
                    ),
                    cc(e.value.quantity.text),
                    cc(e.value.pipeDiameter.text),
                  ],
                )),
              ],
            ),
            pw.Spacer(),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                sig(_s1Name.text, _s1Title.text, topPad: 40),
                sig(_s2Name.text, _s2Title.text, topPad: 80),
                sig(_s3Name.text, _s3Title.text, topPad: 40),
              ],
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename:
      'overall_report_${_year}_${_month.toString().padLeft(2, '0')}.pdf',
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1565C0);
    final curStyle = _currentStyle;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            decoration: BoxDecoration(
              color: _tk.dark ? const Color(0xFF0B1220) : Colors.white,
              border: Border(
                  bottom: BorderSide(
                      color: _tk.dark
                          ? const Color(0xFF1E2E47)
                          : const Color(0xFFE2E8F0),
                      width: 1)),
              boxShadow: [
                BoxShadow(
                  color: _tk.dark
                      ? Colors.black.withOpacity(0.4)
                      : accent.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withOpacity(0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: accent.withOpacity(0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Icon(Icons.summarize_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overall Report',
                              style: TextStyle(
                                color: _tk.dark
                                    ? const Color(0xFFEDF2FF)
                                    : const Color(0xFF0D1F3C),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              )),
                          Text('Monthly Accomplishment · $_monthName',
                              style: TextStyle(
                                color: _tk.dark
                                    ? const Color(0xFF475F7E)
                                    : const Color(0xFF7A93B4),
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ),
                    _MonthYearPicker(
                      month: _month,
                      year: _year,
                      onChanged: (m, y) {
                        _pComplaintsCtrl.clear();
                        _pActedCtrl.clear();
                        _pServiceCtrl.clear();
                        _pDistRepCtrl.clear();
                        _pDistLenCtrl.clear();
                        _pRestoCtrl.clear();
                        _pWaterACtrl.clear();
                        _pWaterBCtrl.clear();
                        setState(() {
                          _month = m;
                          _year = y;
                        });
                        _loadData();
                      },
                    ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message:
                      _editMode ? 'Exit Edit Mode' : 'Edit Document',
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            setState(() => _editMode = !_editMode),
                        icon: Icon(
                            _editMode
                                ? Icons.edit_off_rounded
                                : Icons.edit_rounded,
                            size: 17),
                        label: Text(_editMode ? 'Done' : 'Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _editMode
                              ? Colors.orange.shade700
                              : const Color(0xFFF7FAFD),
                          foregroundColor:
                          _editMode ? Colors.white : accent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          side: BorderSide(
                              color: _editMode
                                  ? Colors.orange.shade700
                                  : accent.withOpacity(0.25)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _printReport,
                      icon:
                      const Icon(Icons.print_rounded, size: 17),
                      label: const Text('Print / Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEBF3FF),
                        foregroundColor: accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                        side: BorderSide(
                            color: accent.withOpacity(0.25)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Refresh',
                      child: GestureDetector(
                        onTap: _loadData,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFD),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFDDE6F0)),
                          ),
                          child: Icon(Icons.refresh_rounded,
                              color: accent, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Formatting toolbar ──────────────────────────────────────────
          if (_editMode)
            Container(
              color: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    _focusedHeader != null
                        ? 'Header Style:'
                        : 'Click a header field \u2192',
                    style: TextStyle(
                      fontSize: 12,
                      color: _focusedHeader != null
                          ? Colors.black87
                          : Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_focusedHeader != null) ...[
                    const SizedBox(width: 12),
                    _FmtBtn(
                        label: 'B',
                        tooltip: 'Bold',
                        bold: true,
                        active: curStyle.bold,
                        onTap: () => _toggleH('bold')),
                    _FmtBtn(
                        label: 'I',
                        tooltip: 'Italic',
                        italic: true,
                        active: curStyle.italic,
                        onTap: () => _toggleH('italic')),
                    _FmtBtn(
                        label: 'U',
                        tooltip: 'Underline',
                        underline: true,
                        active: curStyle.underline,
                        onTap: () => _toggleH('underline')),
                    _FmtBtn(
                        label: '\u2261',
                        tooltip: 'Justify',
                        active: curStyle.justify,
                        onTap: () => _toggleH('justify')),
                    const SizedBox(width: 8),
                    _AlignBtn(
                        icon: Icons.format_align_left,
                        tooltip: 'Align Left',
                        active: curStyle.align == 'left' &&
                            !curStyle.justify,
                        onTap: () => _toggleH('left')),
                    _AlignBtn(
                        icon: Icons.format_align_center,
                        tooltip: 'Align Center',
                        active: curStyle.align == 'center' &&
                            !curStyle.justify,
                        onTap: () => _toggleH('center')),
                    _AlignBtn(
                        icon: Icons.format_align_right,
                        tooltip: 'Align Right',
                        active: curStyle.align == 'right' &&
                            !curStyle.justify,
                        onTap: () => _toggleH('right')),
                    const SizedBox(width: 12),
                    const Text('Size:',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 6),
                    _SizeDropdown(
                        value: curStyle.fontSize,
                        onChanged: (s) => _applyStyle(
                            curStyle.copyWith(fontSize: s))),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFDDE6F0)),
                      ),
                      child: const Text('Arial',
                          style: TextStyle(
                              fontSize: 12, color: Colors.black87)),
                    ),
                  ],
                  const Spacer(),
                  if (!_isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border:
                        Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle,
                              size: 8,
                              color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Text('Live data',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          if (_editMode)
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── Document body ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1565C0)))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                  const BoxConstraints(maxWidth: 760),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                          Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildDocHeader(),
                        _buildMainTable(),
                        _buildPipeTable(),
                        _buildSignatories(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Document header ──────────────────────────────────────────────────────────

  Widget _buildDocHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          _headerLine(_hLine1Ctrl, 'h1', _h1Style),
          const SizedBox(height: 2),
          _headerLine(_hLine2Ctrl, 'h2', _h2Style),
          const SizedBox(height: 10),
          _headerLine(_hLine3Ctrl, 'h3', _h3Style),
          _headerLine(_hLine4Ctrl, 'h4', _h4Style),
          const SizedBox(height: 6),
          _headerLine(_hLine5Ctrl, 'h5', _h5Style),
          const SizedBox(height: 2),
          Text(
            'For the month of $_monthName',
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _headerLine(
      TextEditingController ctrl,
      String key,
      RichStyle style,
      ) {
    final isFocused = _focusedHeader == key && _editMode;

    if (_editMode) {
      return GestureDetector(
        onTap: () => setState(() => _focusedHeader = key),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: isFocused
                  ? const Color(0xFF1565C0)
                  : Colors.transparent,
              width: isFocused ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
            color: isFocused
                ? const Color(0xFFEFF6FF)
                : Colors.transparent,
          ),
          child: TextField(
            controller: ctrl,
            readOnly: !AppSession.instance.canEditReports,
            textAlign: style.textAlign,
            onTap: () => setState(() => _focusedHeader = key),
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: style.fontSize,
              fontWeight: style.fontWeight,
              fontStyle: style.fontStyle,
              decoration: style.decoration,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding:
              EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Text(
        ctrl.text,
        textAlign: style.textAlign,
        style: TextStyle(
          fontFamily: 'Arial',
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          fontStyle: style.fontStyle,
          decoration: style.decoration,
        ),
      ),
    );
  }

  // ── Main accomplishment table ─────────────────────────────────────────────────

  Widget _buildMainTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Table(
        border: TableBorder.all(
            color: const Color(0xFFCBD5E1), width: 1),
        columnWidths: const {
          0: FlexColumnWidth(3.5),
          1: FlexColumnWidth(1.3),
          2: FlexColumnWidth(1.3),
          3: FlexColumnWidth(1.3),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1E3A5F)),
            children: [
              _th(''),
              _th('Previous Report\n(Month of $_prevMonthName)'),
              _th('This Report\n(Month of $_monthName)'),
              _th('Total\n(Month of Jan to $_monthName)'),
            ],
          ),
          _row('1  Complaints Received', _pComplaintsCtrl,
              '$_thisComplaints', '$_totalComplaints',
              bold: true),
          _row('2  Complaints Acted Upon', _pActedCtrl,
              '$_thisActed', '$_totalActed',
              bold: true),
          _row('3  Service Connection Repaired', _pServiceCtrl,
              '$_thisService', '$_totalService'),
          _row('4  Distribution Line Repaired', _pDistRepCtrl,
              '$_thisDistRep', '$_totalDistRep'),
          _rowManual(
            '5  Distribution Line Replaced (Length)',
            _pDistLenCtrl,
            _tDistLenCtrl,
            '-',
          ),
          _row('6  Restoration', _pRestoCtrl,
              '$_thisRestoration', '$_totalResto'),
          TableRow(
            decoration:
            const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: [
              Padding(
                padding:
                const EdgeInsets.fromLTRB(14, 10, 8, 4),
                child: const Text(
                  '7  Water Meter Relocated',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(),
              const SizedBox(),
              const SizedBox(),
            ],
          ),
          _row(
            '     a. Special Project (outside prop.line)',
            _pWaterACtrl,
            '$_thisWaterMeterA',
            '$_totalWaterA',
          ),
          _rowManual(
            '     b. Billed (Requested by concessioners)',
            _pWaterBCtrl,
            _tWaterBCtrl,
            '$_totalWaterB',
          ),
        ],
      ),
    );
  }

  TableRow _row(
      String label,
      TextEditingController prevCtrl,
      String thisVal,
      String total, {
        bool bold = false,
      }) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Text(label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight:
              bold ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
      _editCell(prevCtrl),
      _staticCell(thisVal),
      _staticCell(total),
    ]);
  }

  TableRow _rowManual(
      String label,
      TextEditingController prevCtrl,
      TextEditingController thisCtrl,
      String total,
      ) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w500)),
      ),
      _editCell(prevCtrl, numeric: false),
      _editCell(thisCtrl, numeric: false),
      _staticCell(total),
    ]);
  }

  // ── Pipe detail table ─────────────────────────────────────────────────────────

  Widget _buildPipeTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Table(
            border: TableBorder.all(
                color: const Color(0xFFCBD5E1), width: 1),
            columnWidths: const {
              0: FixedColumnWidth(36),
              1: FlexColumnWidth(2.5),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration:
                const BoxDecoration(color: Color(0xFF1E3A5F)),
                children: [
                  _th('#'),
                  _th('Location'),
                  _th('Quantity'),
                  _th('Pipe Diameter'),
                ],
              ),
              ..._pipeRows.asMap().entries.map((e) {
                final i = e.key;
                final row = e.value;
                return TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven
                        ? Colors.white
                        : const Color(0xFFF8FAFC),
                  ),
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8)),
                      ),
                    ),
                    _inlineEdit(row.location,
                        hint: 'e.g. San Antonio 2'),
                    _inlineEdit(row.quantity,
                        hint: 'e.g. 1m', center: true),
                    _inlineEdit(row.pipeDiameter,
                        hint: 'e.g. PVC PIPE 2', center: true),
                  ],
                );
              }),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                if (AppSession.instance.canEditReports)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _pipeRows.add(PipeEntry())),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add Row'),
                    style: TextButton.styleFrom(
                        foregroundColor:
                        const Color(0xFF1565C0)),
                  ),
                if (AppSession.instance.canEditReports &&
                    _pipeRows.length > 1)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _pipeRows.last.dispose();
                      _pipeRows.removeLast();
                    }),
                    icon: Icon(Icons.remove_rounded,
                        size: 17, color: Colors.red[400]),
                    label: Text('Remove Row',
                        style:
                        TextStyle(color: Colors.red[400])),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Signatories ───────────────────────────────────────────────────────────────

  Widget _buildSignatories() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _sigBlock(_s1Name, _s1Title)),
          const SizedBox(width: 16),
          Expanded(child: _sigBlock(_s2Name, _s2Title)),
          const SizedBox(width: 16),
          Expanded(child: _sigBlock(_s3Name, _s3Title)),
        ],
      ),
    );
  }

  Widget _sigBlock(
      TextEditingController name,
      TextEditingController title,
      ) {
    return Column(
      children: [
        const SizedBox(height: 56),
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(color: Colors.black87, width: 1)),
          ),
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              TextField(
                controller: name,
                readOnly: !AppSession.instance.canEditReports,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  decoration: TextDecoration.underline,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              TextField(
                controller: title,
                readOnly: !AppSession.instance.canEditReports,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black87),
                maxLines: 2,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Cell helpers ──────────────────────────────────────────────────────────────

  Widget _th(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _staticCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _editCell(
      TextEditingController ctrl, {
        bool numeric = true,
      }) {
    final isAdmin = AppSession.instance.canEditReports;
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: TextField(
        controller: ctrl,
        readOnly: !isAdmin,
        textAlign: TextAlign.center,
        keyboardType:
        numeric ? TextInputType.number : TextInputType.text,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.digitsOnly]
            : [],
        onChanged: isAdmin ? (_) => setState(() {}) : null,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              vertical: 6, horizontal: 4),
          filled: true,
          fillColor: isAdmin
              ? const Color(0xFFF0F4FF)
              : const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide:
            const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(
                color: Color(0xFF1565C0), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide:
            const BorderSide(color: Color(0xFFCBD5E1)),
          ),
        ),
      ),
    );
  }

  Widget _inlineEdit(
      TextEditingController ctrl, {
        String hint = '',
        bool center = false,
      }) {
    final isAdmin = AppSession.instance.canEditReports;
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: TextField(
        controller: ctrl,
        readOnly: !isAdmin,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: isAdmin ? hint : null,
          hintStyle: const TextStyle(
              color: Color(0xFF94A3B8), fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              vertical: 6, horizontal: 8),
          filled: true,
          fillColor: isAdmin
              ? const Color(0xFFF8FAFF)
              : const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide:
            const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(
                color: Color(0xFF1565C0), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide:
            const BorderSide(color: Color(0xFFCBD5E1)),
          ),
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
            color: active
                ? const Color(0xFF1565C0).withOpacity(0.11)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active
                  ? const Color(0xFF1565C0)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                bold ? FontWeight.w900 : FontWeight.w500,
                fontStyle:
                italic ? FontStyle.italic : FontStyle.normal,
                decoration:
                underline ? TextDecoration.underline : null,
                color: active
                    ? const Color(0xFF1565C0)
                    : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── _AlignBtn ────────────────────────────────────────────────────────────────

class _AlignBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _AlignBtn({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
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
            color: active
                ? const Color(0xFF1565C0).withOpacity(0.11)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active
                  ? const Color(0xFF1565C0)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          child: Center(
            child: Icon(icon,
                size: 17,
                color: active
                    ? const Color(0xFF1565C0)
                    : Colors.grey[700]),
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
    const sizes = [
      9.0, 10.0, 11.0, 12.0, 13.0,
      14.0, 16.0, 18.0, 20.0, 24.0,
    ];
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
          style:
          const TextStyle(fontSize: 12, color: Colors.black87),
          items: sizes
              .map((s) => DropdownMenuItem(
            value: s,
            child: Text(s.toInt().toString(),
                style: const TextStyle(fontSize: 12)),
          ))
              .toList(),
          onChanged:
          onChanged != null ? (v) => onChanged!(v!) : null,
        ),
      ),
    );
  }
}

// ─── _MonthYearPicker ─────────────────────────────────────────────────────────

class _MonthYearPicker extends StatelessWidget {
  final int month;
  final int year;
  final void Function(int month, int year) onChanged;

  const _MonthYearPicker({
    required this.month,
    required this.year,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const months = [
      'January', 'February', 'March', 'April',
      'May',     'June',     'July',  'August',
      'September', 'October', 'November', 'December',
    ];
    final curYear = DateTime.now().year;
    final years = List.generate(5, (i) => curYear - 2 + i);
    final tk = context.tk;
    final isDark = tk.dark;
    final borderClr =
    isDark ? const Color(0xFF1E2E47) : const Color(0xFFDDE6F0);
    final bgClr =
    isDark ? const Color(0xFF161F30) : const Color(0xFFF7FAFD);
    final dropClr =
    isDark ? const Color(0xFF101827) : Colors.white;
    final txtClr =
    isDark ? const Color(0xFFEDF2FF) : const Color(0xFF0D1F3C);
    final iconClr =
    isDark ? const Color(0xFF475F7E) : const Color(0xFF7A93B4);

    Widget picker({
      required int value,
      required List<int> items,
      required String Function(int) label,
      required ValueChanged<int> onSel,
    }) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bgClr,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderClr),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            dropdownColor: dropClr,
            iconEnabledColor: iconClr,
            style: TextStyle(color: txtClr, fontSize: 13),
            items: items
                .map((v) => DropdownMenuItem(
              value: v,
              child: Text(label(v),
                  style:
                  TextStyle(color: txtClr, fontSize: 13)),
            ))
                .toList(),
            onChanged: (v) => onSel(v!),
          ),
        ),
      );
    }

    return Row(children: [
      picker(
        value: month,
        items: List.generate(12, (i) => i + 1),
        label: (m) => months[m - 1],
        onSel: (m) => onChanged(m, year),
      ),
      const SizedBox(width: 8),
      picker(
        value: year,
        items: years,
        label: (y) => '$y',
        onSel: (y) => onChanged(month, y),
      ),
    ]);
  }
}