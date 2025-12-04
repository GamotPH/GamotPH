// lib/screens/reports/reports_dashboard_page.dart
import 'dart:ui'; // for FontFeature (kept to avoid breaking imports)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'filters.dart';
import 'keyMetrics.dart';
import 'symptomsActivity.dart';
import 'clinicalManagement.dart';
import 'patientExperience.dart';
import 'geoTable.dart';

class ReportsDashboardPage extends StatefulWidget {
  const ReportsDashboardPage({super.key});

  @override
  State<ReportsDashboardPage> createState() => _ReportsDashboardPageState();
}

class _ReportsDashboardPageState extends State<ReportsDashboardPage> {
  // Dropdown options
  // Time frame choices for the entire dashboard.
  final _timeFrames = const ['Daily', 'Weekly', 'Monthly', 'Yearly'];

  // Regions – align these with the regions used in your heat maps.
  final _regions = const [
    'All',
    'Ilocos Region',
    'Cagayan Valley',
    'Central Luzon',
    'CALABARZON',
    'MIMAROPA',
    'Bicol Region',
    'Western Visayas',
    'Central Visayas',
    'Eastern Visayas',
    'Zamboanga Peninsula',
    'Northern Mindanao',
    'Davao Region',
    'SOCCSKSARGEN',
    'CAR',
    'BARMM',
    'NCR',
  ];

  List<String> _medicines = ['All'];

  // Current selections
  String _selectedTimeFrame = 'Monthly';
  String _selectedRegion = 'All';
  String _selectedMedicine = 'All';

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
  }

  Future<void> _fetchMedicines() async {
    try {
      final supabase = Supabase.instance.client;

      // NOTE: column name is genericName, not generic_name
      final data = await supabase.from('Medicines').select('genericName');

      // data should be a List<dynamic>
      final uniqueNames = <String>{};

      for (final row in data as List<dynamic>) {
        // use the correct key from your table: 'genericName'
        final name = (row['genericName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          uniqueNames.add(name);
        }
      }

      final sortedNames =
          uniqueNames.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      setState(() {
        _medicines = ['All', ...sortedNames];

        // make sure the selected value is still valid
        if (!_medicines.contains(_selectedMedicine)) {
          _selectedMedicine = 'All';
        }
      });

      // Optional debug:
      // debugPrint('Loaded medicines: $_medicines');
    } catch (e, st) {
      // Optional: log so you can see errors in the console
      // debugPrint('Error loading medicines: $e\n$st');
    }
  }

  // --- Measure Key Metrics height and mirror it onto Symptoms ---
  final GlobalKey _keyMetricsKey = GlobalKey();
  double? _measuredKeyMetricsHeight;

  void _captureKeyMetricsHeight() {
    final ctx = _keyMetricsKey.currentContext;
    if (ctx == null) return;
    final h = ctx.size?.height;
    if (h != null && h != _measuredKeyMetricsHeight) {
      setState(() {
        _measuredKeyMetricsHeight = h;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;

        // Simple breakpoints (no new dependencies)
        final bool isDesktop = width >= 1200;
        final bool isTablet = width >= 800 && width < 1200;
        final bool isPhone = width < 800;

        final Axis axisForTwoUp =
            (isDesktop || isTablet) ? Axis.horizontal : Axis.vertical;

        // Page padding
        final double outerPadding = isPhone ? 16.0 : 24.0;
        final double gap = isPhone ? 16.0 : 20.0;

        // Card heights (tweak as needed)
        const double overviewFallbackHeight = 320;
        const double midRowHeight = 360;

        // Helper: Row on wide screens (with Expanded). Column on narrow (no Expanded).
        Widget responsiveGroup({
          required Axis axis,
          required List<Widget> children,
          required double gap,
          CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
        }) {
          if (axis == Axis.horizontal) {
            final rowChildren = <Widget>[];
            for (var i = 0; i < children.length; i++) {
              rowChildren.add(Expanded(child: children[i]));
              if (i != children.length - 1) {
                rowChildren.add(SizedBox(width: gap));
              }
            }
            return Row(
              crossAxisAlignment: crossAxisAlignment,
              children: rowChildren,
            );
          } else {
            final colChildren = <Widget>[];
            for (var i = 0; i < children.length; i++) {
              colChildren.add(children[i]);
              if (i != children.length - 1) {
                colChildren.add(SizedBox(height: gap));
              }
            }
            return Column(
              crossAxisAlignment: crossAxisAlignment,
              children: colChildren,
            );
          }
        }

        // measure the Key Metrics height after layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _captureKeyMetricsHeight();
        });

        return Container(
          color: const Color(0xFFF7F7FB),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(outerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters (full-width)
                  ReportsFilters(
                    timeFrames: _timeFrames,
                    regions: _regions,
                    medicines: _medicines,
                    selectedTimeFrame: _selectedTimeFrame,
                    selectedRegion: _selectedRegion,
                    selectedMedicine: _selectedMedicine,
                    onTimeFrameChanged:
                        (v) => setState(() => _selectedTimeFrame = v),
                    onRegionChanged: (v) => setState(() => _selectedRegion = v),
                    onMedicineChanged:
                        (v) => setState(() => _selectedMedicine = v),
                  ),
                  SizedBox(height: gap),

                  // === Overview row (Key Metrics + Symptoms Activity) ===
                  if (axisForTwoUp == Axis.horizontal)
                    responsiveGroup(
                      axis: axisForTwoUp,
                      gap: gap,
                      children: [
                        // Key Metrics
                        KeyedSubtree(
                          key: _keyMetricsKey,
                          child: const KeyMetricsPanel(),
                        ),

                        // Symptoms Activity
                        SizedBox(
                          height:
                              _measuredKeyMetricsHeight ??
                              overviewFallbackHeight,
                          child: SymptomsActivityPanel(
                            height:
                                _measuredKeyMetricsHeight ??
                                overviewFallbackHeight,
                            timeframe: _selectedTimeFrame,
                            // pass region through the existing "people" prop
                            people: _selectedRegion,
                            medicine: _selectedMedicine,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KeyedSubtree(
                          key: _keyMetricsKey,
                          child: const KeyMetricsPanel(),
                        ),
                        SizedBox(height: gap),
                        SizedBox(
                          height:
                              _measuredKeyMetricsHeight ??
                              overviewFallbackHeight,
                          child: SymptomsActivityPanel(
                            height:
                                _measuredKeyMetricsHeight ??
                                overviewFallbackHeight,
                            timeframe: _selectedTimeFrame,
                            people: _selectedRegion,
                            medicine: _selectedMedicine,
                          ),
                        ),
                      ],
                    ),

                  SizedBox(height: gap),

                  // === Clinical Management + Patient Experience ===
                  responsiveGroup(
                    axis: axisForTwoUp,
                    gap: gap,
                    children: [
                      const ClinicalManagementPanel().copyWithHeight(
                        midRowHeight,
                      ),
                      const PatientExperiencePanel().copyWithHeight(
                        midRowHeight,
                      ),
                    ],
                  ),
                  SizedBox(height: gap),

                  // === Geo Distribution (full width) ===
                  responsiveGroup(
                    axis: axisForTwoUp,
                    gap: gap,
                    // Only one child -> Expanded in horizontal mode makes it fill the row.
                    children: const [GeoTablePanel()],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// === Helper extensions to easily tweak card heights without changing constructors ===
extension _PanelHeight on KeyMetricsPanel {
  KeyMetricsPanel copyWithHeight(double h) =>
      KeyMetricsPanel(height: h, key: key);
}

extension _PanelHeight3 on ClinicalManagementPanel {
  ClinicalManagementPanel copyWithHeight(double h) =>
      ClinicalManagementPanel(height: h, key: key);
}

extension _PanelHeight4 on PatientExperiencePanel {
  PatientExperiencePanel copyWithHeight(double h) =>
      PatientExperiencePanel(height: h, key: key);
}
