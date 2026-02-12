import 'package:flutter/material.dart';
import '../core/constants.dart';

class DropdownLocation extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const DropdownLocation({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Location',
        border: OutlineInputBorder(),
      ),
      items: locations
          .map((loc) => DropdownMenuItem(
        value: loc,
        child: Text(loc.toUpperCase()),
      ))
          .toList(),
      onChanged: (v) => onChanged(v!),
    );
  }
}
