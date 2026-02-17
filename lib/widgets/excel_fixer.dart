import 'dart:typed_data';
import 'package:archive/archive.dart';

class ExcelFixer {
  /// Fixes problematic numFmt IDs in Excel files before parsing
  /// Removes built-in format IDs (like 42, 44) that the excel package
  /// incorrectly treats as custom formats
  static Uint8List fixExcelBytes(Uint8List originalBytes) {
    try {
      // Decode the Excel file (which is a ZIP archive)
      final archive = ZipDecoder().decodeBytes(originalBytes);

      // Find and modify styles.xml
      final newArchive = Archive();

      for (final file in archive.files) {
        if (file.name == 'xl/styles.xml' && file.content != null) {
          // Get the XML content
          String content = String.fromCharCodes(file.content as List<int>);

          // Fix the problematic numFmt entries
          content = _fixStylesXml(content);

          // Create new file with fixed content
          final fixedFile = ArchiveFile(
            file.name,
            content.length,
            content.codeUnits,
          );
          newArchive.addFile(fixedFile);
        } else {
          // Keep other files as-is
          newArchive.addFile(file);
        }
      }

      // Encode back to ZIP
      final fixedBytes = ZipEncoder().encode(newArchive);
      return Uint8List.fromList(fixedBytes!);

    } catch (e) {
      // If fixing fails, return original bytes
      print('Warning: Could not fix Excel file: $e');
      return originalBytes;
    }
  }

  static String _fixStylesXml(String content) {
    // Remove problematic built-in format IDs (0-163 are built-in)
    // Common problematic IDs: 42, 44 (currency formats)

    // Pattern to match numFmt entries with IDs below 164
    final builtInIds = [42, 44, 43, 41]; // Add more if needed

    for (final id in builtInIds) {
      // Remove the numFmt definition
      content = content.replaceAll(
        RegExp('<numFmt numFmtId="$id"[^>]*?/>'),
        '',
      );

      // Replace references to this ID with 0 (General format)
      content = content.replaceAll(
        'numFmtId="$id"',
        'numFmtId="0"',
      );
    }

    // Update the count in <numFmts count="X">
    final numFmtsPattern = RegExp(r'<numFmts count="\d+">(.*?)</numFmts>',
        dotAll: true);

    content = content.replaceAllMapped(numFmtsPattern, (match) {
      final numFmtsContent = match.group(1) ?? '';

      // Count remaining numFmt entries
      final remaining = '<numFmt'.allMatches(numFmtsContent).length;

      if (remaining == 0) {
        // Remove entire numFmts section if empty
        return '';
      } else {
        // Update count
        return '<numFmts count="$remaining">$numFmtsContent</numFmts>';
      }
    });

    return content;
  }
}