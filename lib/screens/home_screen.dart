import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/marker_row.dart';
import '../widgets/dropdown_location.dart';
import '../widgets/dropdown_shift.dart';
import '../widgets/excel_fixer.dart';
import '../widgets/file_picker_widget.dart';
import '../widgets/merge_files_widget.dart';
import '../widgets/subject_input.dart';
import '../widgets/markers_table.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:html' as html;

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String location = 'sohar';
  String shift = 'evening';
  final subjectController = TextEditingController();

  List<MarkerRow> rows = [];
  bool loading = false;
  String? fileName;
  bool hasFile = false;
  bool _isCancelled = false;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  String locationCode(String location) {
    switch (location.toLowerCase()) {
      case 'sohar':   return 's';
      case 'muscat':  return 'm';
      case 'nizwa':   return 'n';
      case 'ibri':    return 'i';
      case 'rostaq':  return 'r';
      default:        return 'x';
    }
  }

  String shiftCode(String shift) => shift.toLowerCase() == 'morning' ? '1' : '2';

  String roleCode(String role) {
    final r = role.toLowerCase();
    if (r.contains('chief'))   return 'c';
    if (r.contains('assistant')) return 'a';
    if (r.contains('group'))   return 'g';
    if (r.contains('marke'))   return 'm';
    return '';
  }

  void _stopReading() {
    setState(() {
      _isCancelled = true;
      loading = false;
      hasFile = false;
      rows.clear();
      fileName = '';
    });
  }

  void generateUserIds() {
    if (subjectController.text.trim() == "") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please insert subject code'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    int chiefCount = 1;
    int assistantCount = 1;
    int groupCount = 0;
    int markerCount = 0;
    String firstFileNumber = '';
    String currentGroupCode = '';
    String currentGroupFileRef = '';

    final subject = subjectController.text.trim().toLowerCase();
    final locCode = locationCode(location);
    final shCode = shiftCode(shift);

    if (rows.isNotEmpty) firstFileNumber = rows.first.fileNumber;

    for (final row in rows) {
      final rCode = roleCode(row.role);

      if (rCode == 'c') {
        final counter = chiefCount.toString().padLeft(2, '0');
        row.userId = '$subject${locCode}${shCode}c$counter';
        row.fileRef = '';
        chiefCount++;
        continue;
      }

      if (rCode == 'a') {
        final counter = assistantCount.toString().padLeft(2, '0');
        row.userId = '$subject${locCode}${shCode}a$counter';
        row.fileRef = firstFileNumber;
        assistantCount++;
        continue;
      }

      if (rCode == 'g') {
        groupCount++;
        markerCount = 0;
        currentGroupCode = groupCount.toString().padLeft(2, '0');
        currentGroupFileRef = row.fileNumber;
        row.userId = '$subject${locCode}${shCode}g$currentGroupCode';
        row.fileRef = firstFileNumber;
        continue;
      }

      if (rCode == '') continue;

      markerCount++;
      final markerSeq = markerCount.toString().padLeft(2, '0');
      row.userId = '$subject${locCode}${shCode}m$currentGroupCode$markerSeq';
      row.fileRef = currentGroupFileRef;
    }

    setState(() {});
  }

  Future<void> exportToExcel() async {
    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Sheet1'];

      final headerStyle = excel_pkg.CellStyle(
        bold: true,
        fontSize: 12,
        horizontalAlign: excel_pkg.HorizontalAlign.Center,
        verticalAlign: excel_pkg.VerticalAlign.Center,
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('E3F2FD'),
      );

      final dataStyle = excel_pkg.CellStyle(
        fontSize: 11,
        horizontalAlign: excel_pkg.HorizontalAlign.Center,
        verticalAlign: excel_pkg.VerticalAlign.Center,
      );

      final headers = ['User ID','Password','Marker Name','File #','Role','File Ref','Subject','Shift','Location','Gender'];
      sheet.appendRow(headers.map((e) => excel_pkg.TextCellValue(e)).toList());

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
        sheet.setColumnWidth(i, 18);
      }

      for (int r = 0; r < rows.length; r++) {
        final row = rows[r];
        final values = [row.userId ?? '', row.password ?? '', row.markerName ?? '', row.fileNumber ?? '', row.role ?? '', row.fileRef ?? '', row.subject ?? '', shift, location, row.gender ?? ''];
        sheet.appendRow(values.map((e) => excel_pkg.TextCellValue(e)).toList());
        for (int c = 0; c < values.length; c++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).cellStyle = dataStyle;
        }
      }

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'markers_${location}_${shift}_${subjectController.text.trim()}.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File Successfully Downloaded'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    subjectController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, String>>> _parseExcelStream(Uint8List bytes) async* {
    // ─── Step 1: yield so the UI renders the stop button BEFORE any blocking work ───
    await Future.delayed(const Duration(milliseconds: 200));
    if (_isCancelled) return;

    // ─── Step 2: fix bytes (sync + heavy) ───
    final fixedBytes = ExcelFixer.fixExcelBytes(bytes);
    await Future.delayed(Duration.zero); // yield between heavy calls
    if (_isCancelled) return;

    // ─── Step 3: decode (sync + heavy) ───
    final excel = excel_pkg.Excel.decodeBytes(fixedBytes);
    await Future.delayed(Duration.zero); // yield before processing
    if (_isCancelled) return;

    final sheet = excel.tables[excel.tables.keys.first]!;

    // ─── helpers ───
    String normalize(String text) {
      return text
          .toLowerCase()
          .replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '')
          .replaceAll('.', '').replaceAll(',', '').replaceAll(':', '')
          .replaceAll(';', '').replaceAll('،', '').replaceAll('؛', '')
          .replaceAll('(', '').replaceAll(')', '').replaceAll('[', '')
          .replaceAll(']', '').replaceAll("'", '').replaceAll('"', '')
          .replaceAll('#', '').trim();
    }

    String translateRole(String role) {
      final trimmedRole = role.trim();
      final lowerRole = trimmedRole.toLowerCase();
      if (lowerRole.contains('chief marker') || lowerRole.contains('assistant') ||
          lowerRole.contains('group leader') ||
          (lowerRole.contains('marker') && !lowerRole.contains('رئيس') &&
              !lowerRole.contains('مساعد') && !lowerRole.contains('مجموعة') &&
              !lowerRole.contains('مشرف'))) {
        String cleaned = trimmedRole
            .replaceAll(RegExp(r'رئيس قاعات التصحيح'), '')
            .replaceAll(RegExp(r'مساعد الرئيس'), '')
            .replaceAll(RegExp(r'رئيس مجموعة\d*'), '')
            .replaceAll(RegExp(r'مشرف المجموعة'), '')
            .replaceAll(RegExp(r'مصحح\d*'), '').trim();
        return cleaned.isNotEmpty ? cleaned : trimmedRole;
      }
      if (lowerRole.contains('رئيس قاعات') || lowerRole.contains('رئيس القاعات')) return 'Chief Marker';
      if (lowerRole.contains('مساعد الرئيس') || lowerRole.contains('مساعدالرئيس')) return 'Assistant Chief Marker';
      if (lowerRole.contains('رئيس مجموعة') || lowerRole.contains('رئيسمجموعة') ||
          lowerRole.contains('مشرف المجموعة') || lowerRole.contains('مشرفالمجموعة')) {
        final match = RegExp(r'\d+').firstMatch(role);
        return match != null ? 'Group Leader${match.group(0)}' : 'Group Leader';
      }
      if (lowerRole.contains('مصحح')) {
        final match = RegExp(r'\d+').firstMatch(role);
        return match != null ? 'Marker${match.group(0)}' : 'Marker';
      }
      return trimmedRole;
    }

    String getCellValue(excel_pkg.Data? cell) {
      if (cell == null) return '';
      final value = cell.value;
      if (value == null) return '';
      final valueStr = value.toString().trim();
      if (valueStr.contains('!') && valueStr.contains('\$')) return '';
      return valueStr;
    }

    // ─── find header row ───
    int headerRowIndex = -1;
    List<excel_pkg.Data?>? headerRow;
    for (int i = 0; i < sheet.rows.length; i++) {
      for (var cell in sheet.rows[i]) {
        final v = cell?.value?.toString().trim().toLowerCase() ?? '';
        if (v.contains('marker') || v.contains('name') || v.contains('file') ||
            v.contains('role') || v.contains('position') || v.contains('رقم') ||
            v.contains('ملف') || v.contains('اسم') || v.contains('إسم') ||
            v.contains('مهم') || v.contains('وظيف') || v.contains('قاع')) {
          headerRowIndex = i;
          headerRow = sheet.rows[i];
          break;
        }
      }
      if (headerRowIndex != -1) break;
    }
    if (headerRowIndex == -1 || headerRow == null) return;

    // ─── build column index ───
    final Map<String, int> columnIndex = {};
    for (int i = 0; i < headerRow.length; i++) {
      final v = headerRow[i]?.value?.toString();
      if (v != null && v.trim().isNotEmpty) columnIndex[normalize(v)] = i;
    }

    String readByName(List<excel_pkg.Data?> row, List<String> keys) {
      for (final key in keys) {
        final normalized = normalize(key);
        if (columnIndex.containsKey(normalized)) {
          final idx = columnIndex[normalized]!;
          if (idx < row.length) {
            final v = getCellValue(row[idx]);
            if (v.isNotEmpty) return v;
          }
        }
        for (final entry in columnIndex.entries) {
          if (entry.key.contains(normalized)) {
            final idx = entry.value;
            if (idx < row.length) {
              final v = getCellValue(row[idx]);
              if (v.isNotEmpty) return v;
            }
          }
        }
      }
      return '';
    }

    // ─── yield rows in batches ───
    const batchSize = 10;
    final batch = <Map<String, String>>[];

    for (var i = headerRowIndex + 1; i < sheet.rows.length; i++) {
      if (_isCancelled) return;

      final row = sheet.rows[i];
      final markerName = readByName(row, ["markersname","markersnameالاسم","markername","name","الإسم","الاسم","اسمالمصحح","إسمالمصحح","اسم","إسم"]);
      final fileNumber = readByName(row, ["fileرقمالملف","file","filenumber","رقمالملف","ملف","الملف"]);
      final roleRaw    = readByName(row, ["roleالمهمة","role","position","المهمة","المهمه","الوظيفة","الوظيفه","مهمة","مهمه"]);
      final role       = translateRole(roleRaw);

      if (markerName.isEmpty || fileNumber.isEmpty || role.isEmpty) continue;
      if (RegExp(r'^\d+$').hasMatch(markerName) && RegExp(r'^\d+$').hasMatch(fileNumber)) continue;

      batch.add({
        'markerName': markerName,
        'fileNumber': fileNumber,
        'role':       role,
        'gender':     readByName(row, ["genderالجنس","gender","sex","الجنس","النوع","جنس"]),
        'subject':    readByName(row, ["subjectالمادة","subject","course","المادة","الماده","مادة","ماده"]),
        'location':   readByName(row, ["locationالمركز","location","place","المركز","المكان","مركزالتصحيح","مركز","مكان"]),
        'shift':      readByName(row, ["shiftالفترة","shift","period","فترةالتصحيح","الفترة","الفتره","الوردية","فترة","فتره"]),
      });

      if (batch.length >= batchSize) {
        yield List.of(batch);
        batch.clear();
        await Future.delayed(Duration.zero); // 👈 give Flutter a frame
      }
    }

    if (batch.isNotEmpty) yield batch;
  }

  Future<void> readExcel(Uint8List bytes, String name) async {
    if (bytes.isEmpty) return;

    _isCancelled = false;

    // ─── render loading + stop button FIRST before any work ───
    setState(() {
      loading = true;
      hasFile = true;
      rows.clear();
    });

    // Wait 2 frames so Flutter fully renders the stop button
    await Future.delayed(const Duration(milliseconds: 100));
    await Future.delayed(Duration.zero);

    try {
      await for (final batch in _parseExcelStream(bytes)) {
        if (_isCancelled) return;

        for (final data in batch) {
          rows.add(
            MarkerRow(
              markerName: data['markerName']!,
              fileNumber: data['fileNumber']!,
              role:       data['role']!,
              gender:     data['gender']!,
            )
              ..subject  = data['subject']!.isNotEmpty  ? data['subject']!  : subjectController.text.trim()
              ..location = data['location']!.isNotEmpty ? data['location']! : location
              ..shift    = data['shift']!.isNotEmpty    ? data['shift']!    : shift
              ..password = 'moe.1234'
              ..userId   = ''
              ..fileRef  = '',
          );
        }
      }

      if (_isCancelled) return;

      if (rows.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('There are no correct columns or data'), backgroundColor: Colors.orange),
        );
      }

      setState(() {
        fileName = name;
        loading  = false;
      });

    } catch (e) {
      if (_isCancelled) return;
      setState(() {
        loading = false;
        hasFile = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في قراءة الملف\nError: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    loading = false;
    hasFile = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? _stopReading : null,
        backgroundColor: loading ? Colors.red : Colors.grey,
        icon: const Icon(Icons.stop_rounded, color: Colors.white),
        label: const Text(
          'Stop',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      appBar: AppBar(title: const Text('Markers Generator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blueAccent, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
                          children: [
                            const TextSpan(text: 'Important Notice\n', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const TextSpan(text: 'Please before selecting excel file → create a new empty Excel file, then copy data from the old file using '),
                            const TextSpan(text: 'Paste Values only ', style: TextStyle(fontWeight: FontWeight.w600)),
                            const TextSpan(text: '(Ctrl + C → Ctrl + Alt + V → Values).'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(child: DropdownLocation(value: location, onChanged: (v) => setState(() => location = v))),
                const SizedBox(width: 12),
                Expanded(child: DropdownShift(value: shift, onChanged: (v) => setState(() => shift = v))),
                const SizedBox(width: 12),
                Expanded(child: SubjectInput(controller: subjectController)),
              ],
            ),

            const SizedBox(height: 16),

            FilePickerWidget(onFileLoaded: (bytes, name) => readExcel(bytes, name)),

            if (fileName != null) ...[
              const SizedBox(height: 8),
              Text('Loaded file: $fileName', style: const TextStyle(color: Colors.green)),
            ],

            const SizedBox(height: 12),

            if (hasFile && loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    child: Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: MarkersTable(rows: rows),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: Colors.blue.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                      ),
                      onPressed: rows.isEmpty ? null : generateUserIds,
                      child: const Text('Generate User IDs and File Ref'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: Colors.blue.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                      ),
                      onPressed: rows.isEmpty ? null : exportToExcel,
                      child: const Text('Export Excel'),
                    ),
                  ],
                ),
                ExcelMergerAltWidget(
                  buttonText: 'START MERGING',
                  buttonColor: Colors.green[700],
                  outputFileName: 'merged_markers_${location}_${subjectController.text.trim()}.xlsx',
                  onSuccess: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Merging done'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
                    );
                  },
                  onError: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error in merging'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}