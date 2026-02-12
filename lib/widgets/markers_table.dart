import 'package:flutter/material.dart';
import '../models/marker_row.dart';

class MarkersTable extends StatelessWidget {
  final List<MarkerRow> rows;

  const MarkersTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No data to display'),
      );
    }

    return SizedBox(
      width: MediaQuery.of(context).size.width, // 🔥 المفتاح
      child: DataTable(
        columnSpacing: 32,
        headingRowColor:
        MaterialStateProperty.all(Colors.grey.shade200),
        columns: const [
          DataColumn(label: Text('User ID')),
          DataColumn(label: Text('Marker Name')),
          DataColumn(label: Text('File #')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('File Ref')),
          DataColumn(label: Text('Subject')),
          DataColumn(label: Text('Shift')),
          DataColumn(label: Text('Location')),
          DataColumn(label: Text('Gender')),
        ],
        rows: rows.map((row) {
          return DataRow(
            cells: [
              DataCell(Text(row.userId)),
              DataCell(Text(row.markerName)),
              DataCell(Text(row.fileNumber)),
              DataCell(Text(row.role)),
              DataCell(Text(row.fileRef)),
              DataCell(Text(row.subject)),
              DataCell(Text(row.shift)),
              DataCell(Text(row.location)),
              DataCell(Text(row.gender)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
