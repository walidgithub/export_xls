import 'package:flutter/material.dart';
import '../core/constants.dart';

class DropdownShift extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const DropdownShift({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Shift',
        border: OutlineInputBorder(),
      ),
      items: shifts
          .map((shift) => DropdownMenuItem(
        value: shift,
        child: Text(shift.toUpperCase()),
      ))
          .toList(),
      onChanged: (v) => onChanged(v!),
    );
  }
}
