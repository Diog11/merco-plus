import 'package:flutter/material.dart';

/// Décrit une entrée de navigation (utilisée par la navbar horizontale
/// dans lib/widgets/mp_top_nav.dart).
class MpNavEntry {
  final String label;
  final IconData icon;
  const MpNavEntry(this.label, this.icon);
}
