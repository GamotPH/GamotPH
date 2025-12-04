// lib/screens/reports/filters.dart
import 'package:flutter/material.dart';

class ReportsFilters extends StatelessWidget {
  final List<String> timeFrames;
  final List<String> regions;
  final List<String> medicines;

  final String selectedTimeFrame;
  final String selectedRegion;
  final String selectedMedicine;

  final ValueChanged<String> onTimeFrameChanged;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onMedicineChanged;

  const ReportsFilters({
    super.key,
    required this.timeFrames,
    required this.regions,
    required this.medicines,
    required this.selectedTimeFrame,
    required this.selectedRegion,
    required this.selectedMedicine,
    required this.onTimeFrameChanged,
    required this.onRegionChanged,
    required this.onMedicineChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        const gap = 12.0;

        if (isNarrow) {
          // Phone / narrow tablet: stack vertically, each fills width
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterField(
                label: 'Time frame',
                child: GenericDropdown<String>(
                  items: timeFrames,
                  value: selectedTimeFrame,
                  onChanged: onTimeFrameChanged,
                ),
              ),
              const SizedBox(height: gap),
              _FilterField(
                label: 'Region',
                child: GenericDropdown<String>(
                  items: regions,
                  value: selectedRegion,
                  onChanged: onRegionChanged,
                ),
              ),
              const SizedBox(height: gap),
              _FilterField(
                label: 'Medicine',
                child: GenericDropdown<String>(
                  items: medicines,
                  value: selectedMedicine,
                  onChanged: onMedicineChanged,
                ),
              ),
            ],
          );
        } else {
          // Desktop / wide tablet: three equal columns spanning full width
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _FilterField(
                  label: 'Time frame',
                  child: GenericDropdown<String>(
                    items: timeFrames,
                    value: selectedTimeFrame,
                    onChanged: onTimeFrameChanged,
                  ),
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: _FilterField(
                  label: 'Region',
                  child: GenericDropdown<String>(
                    items: regions,
                    value: selectedRegion,
                    onChanged: onRegionChanged,
                  ),
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: _FilterField(
                  label: 'Medicine',
                  child: GenericDropdown<String>(
                    items: medicines,
                    value: selectedMedicine,
                    onChanged: onMedicineChanged,
                  ),
                ),
              ),
            ],
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

/// Simple reusable dropdown used by the filters.
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
