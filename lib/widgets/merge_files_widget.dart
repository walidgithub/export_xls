import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:async';
import 'dart:html' as html;

/// Alternative Excel merger with dialog prompts between file selections
/// This approach works better on web by giving clear prompts between file picks
class ExcelMergerAltWidget extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Function(String)? onError;
  final String? buttonText;
  final Color? buttonColor;
  final String? outputFileName;

  const ExcelMergerAltWidget({
    super.key,
    this.onSuccess,
    this.onError,
    this.buttonText,
    this.buttonColor,
    this.outputFileName,
  });

  @override
  State<ExcelMergerAltWidget> createState() => _ExcelMergerAltWidgetState();
}

class _ExcelMergerAltWidgetState extends State<ExcelMergerAltWidget> {
  bool _isProcessing = false;

  Future<void> _startMergeFlow() async {
    setState(() => _isProcessing = true);

    try {
      // Step 1: Show dialog and pick first file
      final file1Result = await _showPickerDialog(
        context,
        'Step 1 of 2',
        'Select the FIRST Excel file to merge',
        Icons.looks_one,
      );

      if (file1Result == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Step 2: Show dialog and pick second file
      final file2Result = await _showPickerDialog(
        context,
        'Step 2 of 2',
        'Select the SECOND Excel file to merge',
        Icons.looks_two,
      );

      if (file2Result == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Show merging progress
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Merging files...'),
              ],
            ),
          ),
        );
      }

      // Step 3: Merge files
      await _mergeFiles(file1Result, file2Result);

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Files merged successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onSuccess?.call();
    } catch (e) {
      // Close any open dialogs
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      final errorMessage = 'Error: $e';
      widget.onError?.call(errorMessage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<FilePickerResult?> _showPickerDialog(
      BuildContext context,
      String title,
      String message,
      IconData icon,
      ) async {
    // Show dialog first
    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: Colors.blue[700]),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'Click "Continue" to open the file picker.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (shouldContinue != true) return null;

    // Small delay then open file picker
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      debugPrint('Opening file picker');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      debugPrint('File picker closed: ${result != null ? "File selected" : "Cancelled"}');
      return result;
    } catch (e) {
      debugPrint('File picker error: $e');
      rethrow;
    }
  }

  Future<void> _mergeFiles(FilePickerResult file1, FilePickerResult file2) async {
    if (file1.files.first.bytes == null || file2.files.first.bytes == null) {
      throw 'File data not available';
    }

    // Read first file
    var excel1 = Excel.decodeBytes(file1.files.first.bytes!);
    var sheet1 = excel1.tables[excel1.tables.keys.first]!;

    // Read second file
    var excel2 = Excel.decodeBytes(file2.files.first.bytes!);
    var sheet2 = excel2.tables[excel2.tables.keys.first]!;

    // Create new Excel file
    var mergedExcel = Excel.createExcel();
    var mergedSheet = mergedExcel['Sheet1'];

    // Define styles
    // Header style: Bold, larger font (16pt), centered, background color
    CellStyle headerStyle = CellStyle(
      bold: true,
      fontSize: 16,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );

    // Data style: Regular font (12pt), centered
    CellStyle dataStyle = CellStyle(
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Get headers from first file
    List<CellValue?> headers = sheet1.rows.first.map((cell) => cell?.value).toList();

    // Add header row with styling
    for (int col = 0; col < headers.length; col++) {
      var cell = mergedSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = headers[col];
      cell.cellStyle = headerStyle;
    }

    // Add data from first file (skip header) with styling
    int currentRow = 1;
    for (int i = 1; i < sheet1.rows.length; i++) {
      List<CellValue?> row = sheet1.rows[i].map((cell) => cell?.value).toList();
      for (int col = 0; col < row.length; col++) {
        var cell = mergedSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        cell.value = row[col];
        cell.cellStyle = dataStyle;
      }
      currentRow++;
    }

    // Add 2 empty rows for spacing (no styling needed)
    currentRow += 2;

    // Add data from second file (skip header) with styling
    for (int i = 1; i < sheet2.rows.length; i++) {
      List<CellValue?> row = sheet2.rows[i].map((cell) => cell?.value).toList();
      for (int col = 0; col < row.length; col++) {
        var cell = mergedSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow));
        cell.value = row[col];
        cell.cellStyle = dataStyle;
      }
      currentRow++;
    }

    // Note: Column width auto-sizing is not available in the Excel package
    // The Excel viewer will auto-adjust column widths when opening the file

    // Save the file
    var fileBytes = mergedExcel.save();

    if (fileBytes != null) {
      _downloadFile(fileBytes, widget.outputFileName ?? 'merged_markers.xlsx');
    } else {
      throw 'Failed to create merged file';
    }
  }

  void _downloadFile(List<int> bytes, String filename) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isProcessing ? null : () => scheduleMicrotask(_startMergeFlow),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
        backgroundColor: widget.buttonColor ?? Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: (widget.buttonColor ?? Colors.blue[700])!.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: Colors.grey[300],
        disabledForegroundColor: Colors.grey[500],
      ),
      child: _isProcessing
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'PROCESSING...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      )
          : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.merge_type, size: 24),
          const SizedBox(width: 12),
          Text(
            widget.buttonText ?? 'MERGE EXCEL FILES',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}