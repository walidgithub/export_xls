import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/marker_row.dart';
import '../widgets/dropdown_location.dart';
import '../widgets/dropdown_shift.dart';
import '../widgets/file_picker_widget.dart';
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

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  String locationCode(String location) {
    switch (location.toLowerCase()) {
      case 'sohar':
        return 's';
      case 'muscat':
        return 'm';
      case 'nizwa':
        return 'n';
      case 'ibri':
        return 'i';
      case 'rostaq':
        return 'r';
      default:
        return 'x';
    }
  }

  String shiftCode(String shift) {
    return shift.toLowerCase() == 'morning' ? '1' : '2';
  }

  String roleCode(String role) {
    final r = role.toLowerCase();
    if (r.contains('chief')) return 'c';
    if (r.contains('assistant')) return 'a';
    if (r.contains('group')) return 'g';
    return 'm';
  }

  void generateUserIds() {

    if (subjectController.text.trim() == "") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كود المادة أولاً'),
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
    String firstFileNumber = ''; // 👈 أول رقم في عمود File #
    String currentGroupCode = '';
    String currentGroupFileRef = ''; // رقم ملف Group Leader الحالي

    final subject = subjectController.text.trim().toLowerCase();
    final locCode = locationCode(location);
    final shCode = shiftCode(shift);

    // 👇 حفظ أول رقم ملف قبل بداية الـ loop
    if (rows.isNotEmpty) {
      firstFileNumber = rows.first.fileNumber;
    }

    for (final row in rows) {
      final rCode = roleCode(row.role);

      // ===== CHIEF MARKER =====
      if (rCode == 'c') {
        final counter = chiefCount.toString().padLeft(2, '0');
        row.userId = '$subject$locCode$shCode' 'c$counter';

        row.fileRef = '';

        chiefCount++;
        continue;
      }

      // ===== ASSISTANT =====
      if (rCode == 'a') {
        final counter = assistantCount.toString().padLeft(2, '0');
        row.userId = '$subject$locCode$shCode' 'a$counter';

        row.fileRef = firstFileNumber; // 👈 Assistant يأخذ أول رقم
        assistantCount++;
        continue;
      }

      // ===== GROUP LEADER =====
      if (rCode == 'g') {
        groupCount++;
        markerCount = 0;

        currentGroupCode = groupCount.toString().padLeft(2, '0');
        currentGroupFileRef = row.fileNumber; // حفظ رقم ملف Group Leader نفسه

        row.userId = '$subject$locCode$shCode' 'g$currentGroupCode';

        row.fileRef = firstFileNumber; // 👈 Group Leader يأخذ أول رقم (السهم الأخضر)

        continue;
      }

      // ===== MARKER =====
      markerCount++;

      final markerSeq = markerCount.toString().padLeft(2, '0');

      row.userId = '$subject$locCode$shCode' 'm$currentGroupCode$markerSeq';

      row.fileRef = currentGroupFileRef; // 👈 Marker يأخذ رقم Group Leader (السهم البني)
    }

    setState(() {});
  }

  Future<void> exportToExcel() async {
    try {
      var excel = excel_pkg.Excel.createExcel();
      excel_pkg.Sheet sheetObject = excel['Sheet1'];

      // إضافة الـ Headers
      sheetObject.appendRow([
        excel_pkg.TextCellValue('User ID'),
        excel_pkg.TextCellValue('Marker Name'),
        excel_pkg.TextCellValue('File #'),
        excel_pkg.TextCellValue('Role'),
        excel_pkg.TextCellValue('File Ref'),
        excel_pkg.TextCellValue('Subject'),
        excel_pkg.TextCellValue('Shift'),
        excel_pkg.TextCellValue('Location'),
        excel_pkg.TextCellValue('Gender'),
      ]);

      // إضافة البيانات
      for (var row in rows) {
        sheetObject.appendRow([
          excel_pkg.TextCellValue(row.userId ?? ''),
          excel_pkg.TextCellValue(row.markerName ?? ''),
          excel_pkg.TextCellValue(row.fileNumber ?? ''),
          excel_pkg.TextCellValue(row.role ?? ''),
          excel_pkg.TextCellValue(row.fileRef ?? ''),
          excel_pkg.TextCellValue(subjectController.text.trim()),
          excel_pkg.TextCellValue(shift ?? ''),
          excel_pkg.TextCellValue(location ?? ''),
          excel_pkg.TextCellValue(row.gender ?? ''),
        ]);
      }

      // تحويل الـ Excel إلى bytes
      var fileBytes = excel.encode();

      if (fileBytes != null) {
        // إنشاء Blob من الـ bytes
        final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

        // إنشاء رابط تحميل
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'markers_${DateTime.now().millisecondsSinceEpoch}.xlsx')
          ..click();

        // تنظيف الـ URL
        html.Url.revokeObjectUrl(url);

        // عرض رسالة نجاح
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحميل الملف بنجاح'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // عرض رسالة خطأ
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
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

  Future<void> readExcel(Uint8List bytes, String name) async {
    // 🛑 Guard مهم جدًا
    if (bytes.isEmpty) return;

    setState(() {
      loading = true;
      hasFile = true;
      rows.clear();
    });

    await Future.delayed(const Duration(milliseconds: 100)); // UX + تأكيد repaint

    final excel = excel_pkg.Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first]!;

    String normalize(String text) {
      return text
          .toLowerCase()
          .replaceAll(RegExp(r"[^\w]"), '')
          .trim();
    }

    // 👇 البحث عن صف الـ Headers (تخطي الصفوف الفارغة والعناوين)
    int headerRowIndex = -1;
    List<excel_pkg.Data?>? headerRow;

    for (int i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];

      // التحقق من وجود أعمدة في الصف
      bool hasValidColumns = false;
      for (var cell in row) {
        final cellValue = cell?.value?.toString().trim() ?? '';
        if (cellValue.isNotEmpty) {
          // 👇 استخدام toLowerCase بدلاً من normalize للحفاظ على النص العربي
          final lowerCase = cellValue.toLowerCase();

          if (lowerCase.contains('marker') ||
              lowerCase.contains('file') ||
              lowerCase.contains('role') ||
              lowerCase.contains('رقم') ||
              lowerCase.contains('ملف') ||
              lowerCase.contains('اسم') ||
              lowerCase.contains('إسم') ||
              lowerCase.contains('مصحح') ||
              lowerCase.contains('وظيف') ||
              lowerCase.contains('مهم')) {
            hasValidColumns = true;
            break;
          }
        }
      }

      if (hasValidColumns) {
        headerRowIndex = i;
        headerRow = row;
        break;
      }
    }

    // 👇 إذا لم يتم العثور على Headers
    if (headerRowIndex == -1 || headerRow == null) {
      setState(() {
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم العثور على أعمدة صحيحة في الملف'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 👇 بناء خريطة الأعمدة
    final Map<String, int> columnIndex = {};

    for (int i = 0; i < headerRow.length; i++) {
      final cellValue = headerRow[i]?.value?.toString();
      if (cellValue != null && cellValue.trim().isNotEmpty) {
        columnIndex[normalize(cellValue)] = i;
      }
    }

    // 👇 دالة القراءة بالاسم
    String readByName(
        List<excel_pkg.Data?> row,
        Map<String, int> map,
        List<String> possibleNames,
        ) {
      for (final key in possibleNames) {
        final normalized = normalize(key);
        if (map.containsKey(normalized)) {
          final index = map[normalized]!;
          if (index < row.length) {
            return row[index]?.value?.toString().trim() ?? '';
          }
        }
      }
      return '';
    }

    // 👇 قراءة البيانات (تخطي الصفوف قبل الـ Headers والصفوف الفارغة)
    for (var i = headerRowIndex + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];

      // 👇 قراءة البيانات الأساسية
      final markerName = readByName(row, columnIndex, [
        "marker name",
        "marker's name",
        "markername",
        "name",
        "اسم المصحح",
        "إسم المصحح",
        "الاسم",
        "الأسم",
        "الإسم",
      ]);

      final fileNumber = readByName(row, columnIndex, [
        "file",
        "file number",
        "file#",
        "filenumber",
        "رقم الملف",
        "ملف",
        "الملف",
      ]);

      final role = readByName(row, columnIndex, [
        "role",
        "position",
        "الوظيفة",
        "الوظيفه",
        "المهمة",
        "المهمه",
      ]);

      // 👇 تخطي الصف إذا كانت البيانات الأساسية فارغة
      if (markerName.isEmpty || fileNumber.isEmpty || role.isEmpty) {
        continue;
      }

      // 👇 تخطي الصف إذا كان يحتوي على أرقام فقط (1, 2, 3...)
      if (RegExp(r'^\d+$').hasMatch(markerName) &&
          RegExp(r'^\d+$').hasMatch(fileNumber)) {
        continue;
      }

      // 👇 التحقق من أن الصف ليس فارغاً تماماً
      bool isEmptyRow = true;
      for (var cell in row) {
        if (cell?.value?.toString().trim().isNotEmpty ?? false) {
          isEmptyRow = false;
          break;
        }
      }

      if (isEmptyRow) continue;

      // 👇 إضافة الصف
      rows.add(
        MarkerRow(
          markerName: markerName,
          fileNumber: fileNumber,
          role: role,
          gender: readByName(row, columnIndex, [
            "gender",
            "sex",
            "النوع",
            "الجنس",
          ]),
        )
          ..subject = readByName(row, columnIndex, [
            "subject",
            "course",
            "الماد"
          ]).isNotEmpty
              ? readByName(row, columnIndex, ["subject", "course", "المادة"])
              : subjectController.text.trim()
          ..location = readByName(row, columnIndex, [
            "location",
            "place",
            "المكان",
            "مركز",
          ]).isNotEmpty
              ? readByName(row, columnIndex, ["location", "place", "المركز"])
              : location
          ..shift = readByName(row, columnIndex, [
            "shift",
            "period",
            "الوردية",
            "فتر",
          ]).isNotEmpty
              ? readByName(row, columnIndex, ["shift", "period", "الفترة"])
              : shift
          ..userId = ''
          ..fileRef = '',
      );
    }

    setState(() {
      fileName = name;
      loading = false;
    });

    // 👇 رسالة إذا لم يتم إضافة أي صفوف
    if (rows.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على بيانات صالحة في الملف'),
          backgroundColor: Colors.orange,
        ),
      );
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
      appBar: AppBar(
        title: const Text('Markers Generator'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ==== CONTROLS ====
            Row(
              children: [
                Expanded(
                  child: DropdownLocation(
                    value: location,
                    onChanged: (v) => setState(() => location = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownShift(
                    value: shift,
                    onChanged: (v) => setState(() => shift = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SubjectInput(controller: subjectController),
                ),
              ],
            ),

            const SizedBox(height: 16),

            FilePickerWidget(
              onFileLoaded: (bytes, name) => readExcel(bytes, name),
            ),


            if (fileName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Loaded file: $fileName',
                style: const TextStyle(color: Colors.green),
              ),
            ],

            const SizedBox(height: 12),

            /// ==== LOADING INDICATOR ====
            if (hasFile && loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),


            /// ==== TABLE ====
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

            /// ==== ACTION BUTTONS ====
            Row(
              children: [
                ElevatedButton(
                  onPressed: rows.isEmpty ? null : generateUserIds,
                  child: const Text('Generate User IDs and File Ref'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: rows.isEmpty ? null : exportToExcel,
                  child: const Text('Export Excel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
