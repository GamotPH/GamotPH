// lib/screens/reports/filters.dart
import 'package:flutter/material.dart';

class ReportsFilters extends StatelessWidget {
  final List<String> timeframes;
  final List<String> people;
  final List<String> medicines;

  final String selectedTimeframe;
  final String selectedPeople;
  final String selectedMedicine;

  final ValueChanged<String> onTimeframeChanged;
  final ValueChanged<String> onPeopleChanged;
  final ValueChanged<String> onMedicineChanged;

  const ReportsFilters({
    super.key,
    required this.timeframes,
    required this.people,
    required this.medicines,
    required this.selectedTimeframe,
    required this.selectedPeople,
    required this.selectedMedicine,
    required this.onTimeframeChanged,
    required this.onPeopleChanged,
    required this.onMedicineChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;

        // Breakpoints: 3 cols (desktop), 2 cols (tablet), 1 col (phone)
        final int cols = w >= 1000 ? 3 : (w >= 640 ? 2 : 1);
        const double spacing = 12.0;
        final double itemWidth =
            cols == 1 ? w : (w - spacing * (cols - 1)) / cols;

        List<Widget> fields = [
          SizedBox(
            width: itemWidth,
            child: _FilterDropdown<String>(
              label: 'Timeframe',
              value: selectedTimeframe,
              items: timeframes,
              onChanged: (v) => onTimeframeChanged(v!),
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _FilterDropdown<String>(
              label: 'People',
              value: selectedPeople,
              items: people,
              onChanged: (v) => onPeopleChanged(v!),
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _FilterDropdown<String>(
              label: 'Medicine',
              value: selectedMedicine,
              items: medicines,
              onChanged: (v) => onMedicineChanged(v!),
            ),
          ),
        ];

        return Wrap(spacing: spacing, runSpacing: spacing, children: fields);
      },
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      isDense: true,
      icon: const Icon(Icons.expand_more),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isPhone ? 8 : 10,
        ),
      ),
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
