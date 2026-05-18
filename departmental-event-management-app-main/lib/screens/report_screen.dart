import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional import for web
import 'dart:html' as html;
import 'package:flutter/services.dart';

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
      final attSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventId)
          .collection('attendance')
          .get();

      if (attSnap.docs.isEmpty) {
        setState(() { _entries = []; _loading = false; _generated = true; });
        _fadeCtrl.forward();
        return;
      }

      final List<_AttendanceEntry> results = [];
      final futures = attSnap.docs.map((doc) async {
        try {
          final data = doc.data();
          final userId = data['userId']?.toString() ?? '';
          if (userId.isEmpty) return;

          // Try to get details from attendance doc first (faster)
          final sd = (data['studentDetails'] as Map<dynamic, dynamic>?)
                  ?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
          
          Map<String, dynamic> rd = {};
          String name = (sd['name'] ?? 'Unknown').toString();
          String branch = (sd['branch'] ?? sd['department'] ?? '').toString();
          String section = (sd['section'] ?? '').toString();
          String year = (sd['year'] ?? '').toString();

          // If details missing, fetch from user profile
          if (name == 'Unknown' || section.isEmpty || year.isEmpty) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
            if (userDoc.exists) {
              final ud = userDoc.data() ?? {};
              name = (ud['name'] ?? name).toString();
              final roleData = (ud['roleData'] as Map<dynamic, dynamic>?)
                      ?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
              rd = roleData;
              if (branch.isEmpty) branch = (rd['branch'] ?? rd['department'] ?? '').toString();
              if (section.isEmpty) section = (rd['section'] ?? '').toString();
              if (year.isEmpty) year = (rd['year'] ?? '').toString();
            }
          }

          // Robust Section Matching
          final normProfileSec = section.toUpperCase().replaceAll('SECTION', '').trim();
          final normSelectedSec = _selectedSection!.toUpperCase().replaceAll('SECTION', '').trim();
          if (normProfileSec != normSelectedSec && !section.contains(_selectedSection!)) return;

          // Robust Year Matching
          final normProfileYear = _normaliseYear(year);
          final normSelectedYear = _normaliseYear(_selectedYear!);
          if (normProfileYear != normSelectedYear) return;

          final Timestamp? entryTs = data['entryTime'] as Timestamp?;
          final Timestamp? exitTs  = data['exitTime']  as Timestamp?;

          results.add(_AttendanceEntry(
            studentName: name,
            uid: userId,
            branch: branch.isEmpty ? (_selectedBranch ?? '') : branch,
            section: section.isEmpty ? _selectedSection! : section,
            year: year.isEmpty ? _selectedYear! : year,
            entryTime: entryTs?.toDate(),
            exitTime:  exitTs?.toDate(),
          ));
        } catch (e) {
          debugPrint('Error processing attendance doc ${doc.id}: $e');
        }
      });

      await Future.wait(futures);
      results.sort((a, b) => a.studentName.compareTo(b.studentName));

      setState(() { _entries = results; _loading = false; _generated = true; });
      _fadeCtrl.forward();
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('Fetch failed: $e');
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
    setState(() => _loading = true);
    
    // Create a workbook
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Attendance_Report';

    // Load logo bytes
    Uint8List? logoBytes;
    try {
      logoBytes = (await rootBundle.load('assets/images/college_logo_blue.png')).buffer.asUint8List();
    } catch (e) {
      debugPrint('Excel logo load error: $e');
    }

    final blueColor = '0D47A1'; // Deep Blue (Hex for XlsIO)

    // 1. Add Logo
    if (logoBytes != null) {
      try {
        final xlsio.Picture picture = sheet.pictures.addStream(1, 1, logoBytes);
        picture.height = 70;
        picture.width = 70;
      } catch (e) {
        debugPrint('Error adding image to Excel: $e');
      }
    }

    // 2. Institutional Header
    // Merge cells for titles
    sheet.getRangeByName('B1:H1').merge();
    final title1 = sheet.getRangeByName('B1');
    title1.setText('ST. VINCENT PALLOTTI');
    title1.cellStyle.bold = true;
    title1.cellStyle.fontSize = 18;
    title1.cellStyle.fontColor = '#$blueColor';
    title1.cellStyle.hAlign = xlsio.HAlignType.center;

    sheet.getRangeByName('B2:H2').merge();
    final title2 = sheet.getRangeByName('B2');
    title2.setText('COLLEGE OF ENGINEERING & TECHNOLOGY, NAGPUR');
    title2.cellStyle.bold = true;
    title2.cellStyle.fontSize = 12;
    title2.cellStyle.fontColor = '#$blueColor';
    title2.cellStyle.hAlign = xlsio.HAlignType.center;

    sheet.getRangeByName('B3:H3').merge();
    final title3 = sheet.getRangeByName('B3');
    title3.setText('(AN AUTONOMOUS INSTITUTION)');
    title3.cellStyle.bold = true;
    title3.cellStyle.fontSize = 9;
    title3.cellStyle.fontColor = '#FFFFFF';
    title3.cellStyle.backColor = '#$blueColor';
    title3.cellStyle.hAlign = xlsio.HAlignType.center;

    // 3. Report Info
    sheet.getRangeByName('A5:H5').merge();
    final dept = sheet.getRangeByName('A5');
    dept.setText('Department of Computer Science Engineering');
    dept.cellStyle.bold = true;
    dept.cellStyle.fontSize = 14;
    dept.cellStyle.hAlign = xlsio.HAlignType.center;

    sheet.getRangeByName('A6:H6').merge();
    final reportTitle = sheet.getRangeByName('A6');
    reportTitle.setText('Activity/ Event Report — Session: 2024 - 25');
    reportTitle.cellStyle.bold = true;
    reportTitle.cellStyle.fontSize = 12;
    reportTitle.cellStyle.hAlign = xlsio.HAlignType.center;

    sheet.getRangeByName('A7:H7').merge();
    final eventName = sheet.getRangeByName('A7');
    eventName.setText('Event: ${_selectedEventTitle ?? "N/A"}');
    eventName.cellStyle.bold = true;
    eventName.cellStyle.hAlign = xlsio.HAlignType.center;

    // Filter info
    sheet.getRangeByName('A9').setText('Filters Applied:');
    sheet.getRangeByName('B9:H9').merge();
    sheet.getRangeByName('B9').setText('Section: $_selectedSection, Year: $_selectedYear, Branch: $_selectedBranch');

    // 4. Data Table Header
    int startRow = 11;
    final headers = ['#', 'Student Name', 'UID', 'Branch', 'Section', 'Year', 'Entry Time', 'Exit Time'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(startRow, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.backColor = '#$blueColor';
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.bold = true;
    }

    // 5. Data Table Content
    final fmt = DateFormat('dd MMM yyyy HH:mm');
    for (int i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      final row = startRow + 1 + i;
      sheet.getRangeByIndex(row, 1).setNumber((i + 1).toDouble());
      sheet.getRangeByIndex(row, 2).setText(entry.studentName);
      sheet.getRangeByIndex(row, 3).setText(entry.uid);
      sheet.getRangeByIndex(row, 4).setText(entry.branch);
      sheet.getRangeByIndex(row, 5).setText(entry.section);
      sheet.getRangeByIndex(row, 6).setText(entry.year);
      sheet.getRangeByIndex(row, 7).setText(entry.entryTime != null ? fmt.format(entry.entryTime!) : '-');
      sheet.getRangeByIndex(row, 8).setText(entry.exitTime != null ? fmt.format(entry.exitTime!) : '-');
    }

    // Summary
    int summaryRow = startRow + _entries.length + 2;
    sheet.getRangeByIndex(summaryRow, 1).setText('Total Participants:');
    sheet.getRangeByIndex(summaryRow, 2).setNumber(_entries.length.toDouble());
    sheet.getRangeByIndex(summaryRow + 2, 1).setText('This is a system-generated report');

    // Fast column width setting (Avoid autoFitColumn for performance)
    sheet.setColumnWidthInPixels(1, 40);  // #
    sheet.setColumnWidthInPixels(2, 200); // Name
    sheet.setColumnWidthInPixels(3, 100); // UID
    sheet.setColumnWidthInPixels(4, 150); // Branch
    sheet.setColumnWidthInPixels(5, 70);  // Section
    sheet.setColumnWidthInPixels(6, 70);  // Year
    sheet.setColumnWidthInPixels(7, 130); // Entry
    sheet.setColumnWidthInPixels(8, 130); // Exit

    try {
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      if (kIsWeb) {
        // Web Download Logic
        try {
          final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', 'Attendance_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx')
            ..click();
          html.Url.revokeObjectUrl(url);
          _showSnack('Excel Report Downloaded Successfully');
        } catch (e) {
          _showSnack('Web Download Error: $e');
        }
      } else {
        // Mobile/Desktop Logic
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Attendance_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
        await file.writeAsBytes(bytes);
        
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _showSnack('Excel generated but could not be opened: ${result.message}');
        } else {
          _showSnack('Excel Report Exported Successfully');
        }
      }
    } catch (e) {
      debugPrint('Excel Export Error: $e');
      _showSnack('Failed to export Excel: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── PDF Export ──
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final fmt = DateFormat('dd MMM yyyy, HH:mm');

    // Try to load college logo (Arise & Shine)
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/college_logo_blue.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Logo not found at assets/images/college_logo_blue.png');
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (ctx) => pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // ── Left: Exact College Logo ──
              if (logoImage != null)
                pw.Container(
                  width: 85, // Slightly larger for better readability
                  height: 85,
                  child: pw.Image(logoImage),
                ),
              pw.SizedBox(width: 25),

              // ── Center: Formal Institutional Header ──
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('ST. VINCENT PALLOTTI',
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                    pw.Text('COLLEGE OF ENGINEERING & TECHNOLOGY, NAGPUR',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900),
                        textAlign: pw.TextAlign.center),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue900,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                      ),
                      child: pw.Text('(AN AUTONOMOUS INSTITUTION)',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                    ),
                  ],
                ),
              ),
              // Balancing spacer
              pw.SizedBox(width: 110), 
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Department of Computer Science Engineering',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
          pw.SizedBox(height: 6),
          pw.Text('Activity/ Event Report',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline, color: PdfColors.blueGrey900)),
          pw.SizedBox(height: 6),
          pw.Text('Session: 2024 - 25',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
          pw.SizedBox(height: 15),
          pw.Divider(thickness: 2, color: PdfColors.blue900),
          pw.SizedBox(height: 12),
        ],
      ),
      footer: (ctx) => pw.Column(
        children: [
          pw.Divider(thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('This is a system-generated report',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ],
          ),
        ],
      ),
      build: (ctx) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Event: ${_selectedEventTitle ?? 'Event'}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('Section: $_selectedSection | Year: $_selectedYear',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Branch: $_selectedBranch',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Date: ${fmt.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Total Participants: ${_entries.length}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: ['#', 'Student Name', 'UID', 'Branch', 'Section', 'Year', 'Entry', 'Exit'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          headerAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
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
        pw.SizedBox(height: 50),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              children: [
                pw.Container(width: 120, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1)))),
                pw.SizedBox(height: 5),
                pw.Text('Faculty In-charge', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Column(
              children: [
                pw.Container(width: 120, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1)))),
                pw.SizedBox(height: 5),
                pw.Text('HOD, CSE', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
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
      backgroundColor: const Color(0xFF0D47A1),
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
          decoration: BoxDecoration(color: const Color(0xFF0D47A1).withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.analytics_rounded, color: Color(0xFF0D47A1)),
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
      borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
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
              child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
            ))
          : DropdownButtonFormField<String>(
              value: _selectedEventId,
              decoration: inputDeco.copyWith(
                labelText: 'Select Event',
                prefixIcon: const Icon(Icons.event_rounded, color: Color(0xFF0D47A1)),
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
          prefixIcon: const Icon(Icons.class_outlined, color: Color(0xFF0D47A1)),
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
          prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFF0D47A1)),
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
        color: const Color(0xFF0D47A1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.auto_awesome, color: Color(0xFF0D47A1), size: 16),
        const SizedBox(width: 8),
        Text('Auto-detected branch: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(_selectedBranch ?? '', style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 13)),
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
          backgroundColor: const Color(0xFF0D47A1),
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
      const CircularProgressIndicator(color: Color(0xFF0D47A1)),
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
          _buildSummaryCard('Students', '${_entries.length}', Icons.groups_rounded, const Color(0xFF0D47A1)),
          const SizedBox(width: 12),
          _buildSummaryCard('Section', _selectedSection ?? '-', Icons.class_rounded, Colors.indigo),
        ]),
        const SizedBox(height: 16),

        // Export buttons row
        Row(children: [
          Expanded(child: _exportButton(
            icon: Icons.picture_as_pdf_rounded,
            label: 'Export PDF',
            color: const Color(0xFF0D47A1),
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
    final colors = [const Color(0xFF0D47A1), Colors.indigo, Colors.teal, Colors.orange, Colors.purple, const Color(0xFF0E1424)];
    return colors[name.hashCode.abs() % colors.length];
  }
}
