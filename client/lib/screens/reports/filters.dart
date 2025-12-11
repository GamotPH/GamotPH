// lib/screens/reports/filters.dart
import 'package:flutter/material.dart';

class ReportsFilters extends StatelessWidget {
  final List<String> medicines;
  final String selectedMedicine;
  final ValueChanged<String> onMedicineChanged;

  const ReportsFilters({
    super.key,
    required this.medicines,
    required this.selectedMedicine,
    required this.onMedicineChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        if (isNarrow) {
          // Phone / narrow tablet: full width
          return _FilterField(
            label: 'Medicine',
            child: GenericDropdown<String>(
              items: medicines,
              value: selectedMedicine,
              onChanged: onMedicineChanged,
            ),
          );
        } else {
          // Desktop: medicine dropdown ~¼ of the analytics width, aligned left
          final totalWidth = constraints.maxWidth;
          final targetWidth = totalWidth * 0.25; // 25%

          return Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: targetWidth,
                minWidth: 260, // don't get too tiny on smaller screens
              ),
              child: _FilterField(
                label: 'Medicine',
                child: GenericDropdown<String>(
                  items: medicines,
                  value: selectedMedicine,
                  onChanged: onMedicineChanged,
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

class _FilterField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FilterField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class GenericDropdown<T> extends StatelessWidget {
  final List<T> items;
  final T value;
  final ValueChanged<T> onChanged;

  const GenericDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      items:
          items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(e.toString(), overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
    );
  }
}
