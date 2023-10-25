import 'package:flutter/material.dart';

class EmptyWidget extends StatelessWidget {
  const EmptyWidget({super.key});

  static const String type = "EmptyWidget";

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
