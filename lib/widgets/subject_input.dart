import 'package:flutter/material.dart';

class SubjectInput extends StatelessWidget {
  final TextEditingController controller;

  const SubjectInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Subject Code',
        hintText: 'e.g. mbm',
        border: OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.none,
    );
  }
}
