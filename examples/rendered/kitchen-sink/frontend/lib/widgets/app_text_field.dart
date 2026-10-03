import 'package:flutter/material.dart';

/// A labelled text field with consistent styling. Local building block.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    super.key,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
