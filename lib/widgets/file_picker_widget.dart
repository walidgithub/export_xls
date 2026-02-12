import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FilePickerWidget extends StatelessWidget {
  final Function(Uint8List bytes, String name) onFileLoaded;

  const FilePickerWidget({super.key, required this.onFileLoaded});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xls', 'xlsx'],
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          if (file.bytes != null) {
            onFileLoaded(file.bytes!, file.name);
          }
        }
      },
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'Click to select Excel file',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

