import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceEntry {
  final String studentName;
  final String uid;
  final String branch;
  final String section;
  final String year;
  final DateTime? entryTime;
  final DateTime? exitTime;

  const _AttendanceEntry({
    required this.studentName,
    required this.uid,
    required this.branch,
    required this.section,
    required this.year,
    this.entryTime,
    this.exitTime,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section → Branch mapping
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, String> _sectionToBranch = {
  'A': 'Computer Engineering',
  'B': 'Computer Engineering',
  'C': 'Cyber Security',
  'E': 'Information Technology',
  'F': 'AI',
  'K': 'IoT',
  'P': 'Mechanical',
  'G': 'CSBS',
  'H': 'Civil',
  'I': 'Electrical',
  'J': 'ETC',
};

// ─────────────────────────────────────────────────────────────────────────────
//  Event helper
// ─────────────────────────────────────────────────────────────────────────────
class _EventItem {
  final String id;
  final String title;
  _EventItem(this.id, this.title);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  // ── Event state ──
  List<_EventItem> _events = [];
  bool _loadingEvents = true;
  String? _selectedEventId;
  String? _selectedEventTitle;

  // ── Filter state ──
  String? _selectedSection;
  String? _selectedBranch;
  String? _selectedYear;

  // ── Result state ──
  bool _loading = false;
  bool _generated = false;
  List<_AttendanceEntry> _entries = [];

  // ── Fade animation ──
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  final List<String> _sections = ['A','B','C','E','F','G','H','I','J','K','P'];
  final List<String> _years = ['2nd Year', '3rd Year'];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events').orderBy('date', descending: true).get();
      final list = snap.docs.map((d) {
        final title = d.data()['title']?.toString() ?? 'Untitled Event';
        return _EventItem(d.id, title);
      }).toList();
      setState(() { _events = list; _loadingEvents = false; });
    } catch (_) {
      setState(() => _loadingEvents = false);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onSectionChanged(String? section) {
    setState(() {
      _selectedSection = section;
      _selectedBranch = section != null ? _sectionToBranch[section] : null;
      _generated = false;
      _entries = [];
    });
  }

  // ── Firestore query ──
  Future<void> _generateReport() async {
    if (_selectedEventId == null) {
      _showSnack('Please select an Event first.');
      return;
    }
    if (_selectedSection == null || _selectedYear == null) {
      _showSnack('Please select both a Section and a Year.');
      return;
    }

    setState(() { _loading = true; _generated = false; _entries = []; });
    _fadeCtrl.reset();

    try {
      // Query ONLY the selected event's attendance subcollection
      final attSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventId)
          .collection('attendance')
          .get();

      final List<_AttendanceEntry> results = [];

      final futures = attSnap.docs.map((doc) async {
        final data = doc.data();
        final userId = data['userId']?.toString() ?? '';
        if (userId.isEmpty) return;

        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(userId).get();
        final ud = userDoc.data() ?? {};
        final rd = (ud['roleData'] as Map<dynamic, dynamic>?)
                ?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
        final sd = (data['studentDetails'] as Map<dynamic, dynamic>?)
                ?.map((k, v) => MapEntry(k.toString(), v)) ?? {};

        // Resolve section
        final profileSection = (rd['section'] ?? sd['section'] ?? '').toString().toUpperCase().trim();
        if (profileSection != _selectedSection!.toUpperCase()) return;

        // Resolve year — normalise "2", "2nd Year", "2nd" all to compare
        final rawYear = (rd['year'] ?? sd['year'] ?? '').toString().trim();
        final normProfile = _normaliseYear(rawYear);
        final normSelected = _normaliseYear(_selectedYear!);
        if (normProfile != normSelected) return;

        final branch = (rd['department'] ?? rd['branch'] ?? sd['department'] ?? sd['branch'] ?? _selectedBranch ?? '').toString();
        final name = (ud['name'] ?? sd['name'] ?? 'Unknown').toString();

        final Timestamp? entryTs = data['entryTime'] as Timestamp?;
        final Timestamp? exitTs  = data['exitTime']  as Timestamp?;

        results.add(_AttendanceEntry(
          studentName: name,
          uid: userId,
          branch: branch.isEmpty ? (_selectedBranch ?? '') : branch,
          section: profileSection,
          year: rawYear,
          entryTime: entryTs?.toDate(),
          exitTime:  exitTs?.toDate(),
        ));
      });

      await Future.wait(futures);
      results.sort((a, b) => a.studentName.compareTo(b.studentName));

      setState(() { _entries = results; _loading = false; _generated = true; });
      _fadeCtrl.forward();
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Error: $e');
    }
  }

  String _normaliseYear(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^0-9a-z]'), '');
    if (s.startsWith('2')) return '2';
    if (s.startsWith('3')) return '3';
    if (s.startsWith('4')) return '4';
    return s;
  }

  // ── Excel Export ──
  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheetName = 'Attendance_Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    // Header style
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#C62828'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
    );

    final headers = ['#', 'Student Name', 'UID', 'Branch', 'Section', 'Year', 'Entry Time', 'Exit Time'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    final fmt = DateFormat('dd MMM yyyy HH:mm');
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      final row = [
        '${i + 1}',
        e.studentName,
        e.uid.length >= 8 ? e.uid.substring(0, 8) : e.uid,
        e.branch,
        e.section,
        e.year,
        e.entryTime != null ? fmt.format(e.entryTime!) : '--',
        e.exitTime  != null ? fmt.format(e.exitTime!)  : '--',
      ];
      for (var j = 0; j < row.length; j++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
          .value = TextCellValue(row[j]);
      }
    }

    final bytes = excel.save();
    if (bytes == null) { _showSnack('Failed to generate Excel file.'); return; }

    final dir = await getApplicationDocumentsDirectory();
    final safeEvent = (_selectedEventTitle ?? 'Event').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'Report_${safeEvent}_Sec${_selectedSection}_${_selectedYear?.replaceAll(' ', '_')}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await OpenFile.open(file.path);
    _showSnack('Excel saved: $fileName');
  }

  // ── PDF Export ──
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final fmt = DateFormat('dd MMM yyyy, HH:mm');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Attendance Report — ${_selectedEventTitle ?? 'Event'}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Section: $_selectedSection ($_selectedBranch)  |  Year: $_selectedYear',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
          pw.SizedBox(height: 2),
          pw.Text('Generated: ${fmt.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.red50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.SizedBox(height: 6),
              pw.Text('Total Students Present: ${_entries.length}',
                  style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Branch: $_selectedBranch | Section: $_selectedSection | Year: $_selectedYear',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Table.fromTextArray(
          headers: ['#', 'Student Name', 'UID', 'Branch', 'Section', 'Year', 'Entry', 'Exit'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.red100),
          cellStyle: const pw.TextStyle(fontSize: 8),
          data: _entries.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final e = entry.value;
            return [
              '$i', e.studentName,
              e.uid.length >= 8 ? e.uid.substring(0, 8) : e.uid,
              e.branch, e.section, e.year,
              e.entryTime != null ? DateFormat('HH:mm').format(e.entryTime!) : '--:--',
              e.exitTime  != null ? DateFormat('HH:mm').format(e.exitTime!)  : '--:--',
            ];
          }).toList(),
        ),
      ],
    ));

    final Uint8List bytes = await pdf.save();
    final safeEvent = (_selectedEventTitle ?? 'Event').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await Printing.sharePdf(
        bytes: bytes,
        filename: 'Report_${safeEvent}_Sec${_selectedSection}_${_selectedYear?.replaceAll(' ', '_')}.pdf');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFC62828),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildHeader(),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildSectionLabel('SELECT FILTERS'),
              const SizedBox(height: 12),
              _buildDropdownFilters(),
              if (_selectedBranch != null) ...[
                const SizedBox(height: 12),
                _buildBranchBadge(),
              ],
              const SizedBox(height: 24),
              _buildGenerateButton(),
              const SizedBox(height: 28),
              if (_loading) _buildLoadingState(),
              if (_generated && !_loading) _buildResults(),
            ],
          ),
        ),
      ),
    ]);
  }

  // ── Header ──
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 24, top: 24, bottom: 24, right: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFC62828).withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.analytics_rounded, color: Color(0xFFC62828)),
        ),
        const SizedBox(width: 16),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Generate Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0E1424))),
          Text('Section-wise attendance summary', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }

  Widget _buildSectionLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1.5));

  // ── Cascading Dropdowns ──
  Widget _buildDropdownFilters() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.5),
    );
    final inputDeco = InputDecoration(
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border, enabledBorder: border.copyWith(borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: border,
    );

    return Column(children: [
      // ── Event dropdown ──
      _loadingEvents
          ? const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(color: Color(0xFFC62828)),
            ))
          : DropdownButtonFormField<String>(
              value: _selectedEventId,
              decoration: inputDeco.copyWith(
                labelText: 'Select Event',
                prefixIcon: const Icon(Icons.event_rounded, color: Color(0xFFC62828)),
              ),
              hint: const Text('Choose an event...'),
              items: _events.map((e) => DropdownMenuItem(
                value: e.id,
                child: Text(e.title, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: (v) {
                final found = _events.firstWhere((e) => e.id == v, orElse: () => _EventItem('', ''));
                setState(() {
                  _selectedEventId = v;
                  _selectedEventTitle = found.title;
                  _generated = false;
                  _entries = [];
                });
              },
            ),
      const SizedBox(height: 12),
      // ── Section dropdown ──
      DropdownButtonFormField<String>(
        value: _selectedSection,
        decoration: inputDeco.copyWith(
          labelText: 'Section',
          prefixIcon: const Icon(Icons.class_outlined, color: Color(0xFFC62828)),
        ),
        items: _sections.map((s) => DropdownMenuItem(
          value: s,
          child: Text('Section $s  •  ${_sectionToBranch[s]}',
              style: const TextStyle(fontSize: 14)),
        )).toList(),
        onChanged: _onSectionChanged,
      ),
      const SizedBox(height: 12),
      // ── Year dropdown ──
      DropdownButtonFormField<String>(
        value: _selectedYear,
        decoration: inputDeco.copyWith(
          labelText: 'Year',
          prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFFC62828)),
        ),
        items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
        onChanged: (v) => setState(() { _selectedYear = v; _generated = false; _entries = []; }),
      ),
    ]);
  }

  Widget _buildBranchBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFC62828).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC62828).withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.auto_awesome, color: Color(0xFFC62828), size: 16),
        const SizedBox(width: 8),
        Text('Auto-detected branch: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(_selectedBranch ?? '', style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _generateReport,
        icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
        label: Text(_loading ? 'Generating…' : 'Generate Report',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFC62828),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(child: Column(children: [
      const SizedBox(height: 16),
      const CircularProgressIndicator(color: Color(0xFFC62828)),
      const SizedBox(height: 20),
      const Text('Fetching attendance data…', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Text('Section $_selectedSection — $_selectedBranch — $_selectedYear',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
      const SizedBox(height: 40),
    ]));
  }

  Widget _buildResults() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary row
        Row(children: [
          _buildSummaryCard('Students', '${_entries.length}', Icons.groups_rounded, const Color(0xFFC62828)),
          const SizedBox(width: 12),
          _buildSummaryCard('Section', _selectedSection ?? '-', Icons.class_rounded, Colors.indigo),
        ]),
        const SizedBox(height: 16),

        // Export buttons row
        Row(children: [
          Expanded(child: _exportButton(
            icon: Icons.picture_as_pdf_rounded,
            label: 'Export PDF',
            color: const Color(0xFFC62828),
            onTap: _exportPdf,
          )),
          const SizedBox(width: 10),
          Expanded(child: _exportButton(
            icon: Icons.table_chart_rounded,
            label: 'Export Excel',
            color: Colors.green.shade700,
            onTap: _exportToExcel,
          )),
        ]),
        const SizedBox(height: 20),

        _buildSectionLabel('STUDENT RECORDS'),
        const SizedBox(height: 12),

        if (_entries.isEmpty)
          _buildEmptyState()
        else
          ..._entries.asMap().entries.map((e) => _buildStudentCard(e.key + 1, e.value)),
      ]),
    );
  }

  Widget _exportButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildStudentCard(int index, _AttendanceEntry e) {
    final fmt = DateFormat('HH:mm');
    final hasExit = e.exitTime != null;
    final initials = _initials(e.studentName);
    final avatarColor = _nameColor(e.studentName);
    final uidShort = e.uid.length >= 8 ? e.uid.substring(0, 8) : e.uid;
    final subLine = e.year.isNotEmpty ? '${e.branch} · Yr ${e.year} · Sec ${e.section}' : e.branch;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 22, backgroundColor: avatarColor,
                child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0E1424))),
              const SizedBox(height: 2),
              Text('UID: $uidShort', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontFamily: 'monospace')),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (hasExit ? Colors.orange : Colors.green).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(hasExit ? 'Exited' : 'Present',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: hasExit ? Colors.orange : Colors.green)),
            ),
          ]),
          const SizedBox(height: 10),
          _chip(Icons.domain_rounded, subLine, Colors.indigo),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ENTRY TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(e.entryTime != null ? fmt.format(e.entryTime!) : '--:--',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.green)),
                if (e.entryTime != null)
                  Text(DateFormat('dd MMM').format(e.entryTime!), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ]),
              Container(height: 28, width: 1, color: Colors.grey.shade300),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('EXIT TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(e.exitTime != null ? fmt.format(e.exitTime!) : '--:--',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: hasExit ? Colors.orange : Colors.grey.shade400)),
                if (e.exitTime != null)
                  Text(DateFormat('dd MMM').format(e.exitTime!), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(children: [
      const SizedBox(height: 32),
      Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      const Text('No records found', style: TextStyle(color: Color(0xFF0E1424), fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('No students from Section $_selectedSection ($_selectedYear) have checked in yet.',
          style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 40),
    ]),
  );

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((s) => s[0].toUpperCase()).join();
  }

  Color _nameColor(String name) {
    final colors = [const Color(0xFFC62828), Colors.indigo, Colors.teal, Colors.orange, Colors.purple, const Color(0xFF0E1424)];
    return colors[name.hashCode.abs() % colors.length];
  }
}
