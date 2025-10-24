// lib/screens/reports/reports_dashboard_page.dart
import 'dart:ui'; // for FontFeature (kept to avoid breaking imports)
import 'package:flutter/material.dart';

import 'filters.dart';
import 'keyMetrics.dart';
import 'symptomsActivity.dart';
import 'clinicalManagement.dart';
import 'patientExperience.dart';
// REMOVED: import 'adverseDrugEffects.dart';
import 'geoTable.dart';

class ReportsDashboardPage extends StatefulWidget {
  const ReportsDashboardPage({super.key});

  @override
  State<ReportsDashboardPage> createState() => _ReportsDashboardPageState();
}

class _ReportsDashboardPageState extends State<ReportsDashboardPage> {
  // Dropdown options
  final _timeframes = const [
    'All-time',
    'Past year',
    'Past 90 days',
    'Past 30 days',
    'Past 7 days',
  ];
  final _people = const ['All', 'Adults', 'Seniors', 'Children', 'Pregnant'];
  final _medicines = const [
    'All',
    'Paracetamol',
    'Omeprazole',
    'Ibuprofen',
    'Cetirizine',
  ];

  // Current selections
  String _selectedTimeframe = 'All-time';
  String _selectedPeople = 'All';
  String _selectedMedicine = 'All';

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

        // Adaptive axis and spacing
        final Axis axisForTwoUp =
            (isDesktop || isTablet) ? Axis.horizontal : Axis.vertical;
        final double outerPadding = isDesktop ? 24 : (isTablet ? 20 : 16);
        final double gap = isDesktop ? 16 : (isTablet ? 12 : 10);

        // Fallback heights used only before we get a real measurement
        final double overviewFallbackHeight = isPhone ? 340 : 360;
        final double midRowHeight = isPhone ? 300 : 280;

        // Schedule a post-frame read of the Key Metrics size each build.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _captureKeyMetricsHeight(),
        );

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
                    timeframes: _timeframes,
                    people: _people,
                    medicines: _medicines,
                    selectedTimeframe: _selectedTimeframe,
                    selectedPeople: _selectedPeople,
                    selectedMedicine: _selectedMedicine,
                    onTimeframeChanged:
                        (v) => setState(() => _selectedTimeframe = v),
                    onPeopleChanged: (v) => setState(() => _selectedPeople = v),
                    onMedicineChanged:
                        (v) => setState(() => _selectedMedicine = v),
                  ),
                  SizedBox(height: gap),

                  // === Overview row (Key Metrics + Symptoms Activity) ===
                  if (axisForTwoUp == Axis.horizontal)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT: Key Metrics (measured)
                        Expanded(
                          child: KeyedSubtree(
                            key: _keyMetricsKey,
                            child: const KeyMetricsPanel(),
                          ),
                        ),
                        SizedBox(width: gap),
                        // RIGHT: Symptoms (match measured height)
                        Expanded(
                          child: SizedBox(
                            height:
                                _measuredKeyMetricsHeight ??
                                overviewFallbackHeight,
                            child: SymptomsActivityPanel(
                              height:
                                  _measuredKeyMetricsHeight ??
                                  overviewFallbackHeight,
                              timeframe: _selectedTimeframe,
                              people: _selectedPeople,
                              medicine: _selectedMedicine,
                            ),
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
                            timeframe: _selectedTimeframe,
                            people: _selectedPeople,
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

/// --- Lightweight "copyWithHeight" helpers ---
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
