// lib/screens/reports/reports_dashboard_page.dart
import 'dart:ui'; // for FontFeature (kept to avoid breaking imports)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/backend_config.dart';

import 'filters.dart';
import 'keyMetrics.dart';
import 'symptomsActivity.dart';
import 'clinicalManagement.dart';
import 'patientExperience.dart';
import 'geoTable.dart';
import '../../data/providers.dart'; // <-- ensure this is imported for updateDashboardFilter()

class ReportsDashboardPage extends ConsumerStatefulWidget {
  const ReportsDashboardPage({super.key});

  @override
  ConsumerState<ReportsDashboardPage> createState() =>
      _ReportsDashboardPageState();
}

class _ReportsDashboardPageState extends ConsumerState<ReportsDashboardPage> {
  // Dropdown options
  final List<String> _timeFrames = ['Yearly', 'Monthly'];
  String _selectedTimeFrame = 'Yearly'; // still used only for passing down
  // (the panels ignore it now)

  String _selectedMedicine = 'All';
  bool _isFiltersLoading = true;
  List<String> _medicines = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
  }

  Future<void> _fetchMedicines() async {
    try {
      // GET /api/v1/analytics/medicine-names from the Python backend
      final uri = BackendConfig.uri('/api/v1/analytics/medicine-names');
      final resp = await http.get(uri);

      if (resp.statusCode != 200) {
        debugPrint(
          'Failed to fetch medicines: '
          '${resp.statusCode} ${resp.body}',
        );
        return;
      }

      final decoded = jsonDecode(resp.body);

      final names = <String>{};
      if (decoded is List) {
        for (final item in decoded) {
          if (item is String && item.trim().isNotEmpty) {
            names.add(item.trim());
          }
        }
      }

      final list =
          names.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _medicines = ['All', ...list];
        _isFiltersLoading = false;
      });
    } catch (e, st) {
      debugPrint('Error fetching medicines: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isFiltersLoading = false;
      });
    }
  }

  // --- Measure Key Metrics height and sync to Symptoms panel ---
  final GlobalKey _keyMetricsKey = GlobalKey();
  double? _measuredKeyMetricsHeight;

  void _captureKeyMetricsHeight() {
    final ctx = _keyMetricsKey.currentContext;
    if (ctx == null) return;
    final h = ctx.size?.height;
    if (h != null && h != _measuredKeyMetricsHeight) {
      setState(() => _measuredKeyMetricsHeight = h);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;

        final bool isDesktop = width >= 1200;
        final bool isTablet = width >= 800 && width < 1200;
        final bool isPhone = width < 800;
        final Axis axisForTwoUp =
            (isDesktop || isTablet) ? Axis.horizontal : Axis.vertical;

        final double outerPadding = isPhone ? 16.0 : 24.0;
        final double gap = isPhone ? 16.0 : 20.0;

        const double overviewFallbackHeight = 320;
        const double midRowHeight = 360;

        Widget responsiveGroup({
          required Axis axis,
          required List<Widget> children,
          required double gap,
          CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
        }) {
          if (axis == Axis.horizontal) {
            final rowKids = <Widget>[];
            for (var i = 0; i < children.length; i++) {
              rowKids.add(Expanded(child: children[i]));
              if (i != children.length - 1) {
                rowKids.add(SizedBox(width: gap));
              }
            }
            return Row(
              crossAxisAlignment: crossAxisAlignment,
              children: rowKids,
            );
          } else {
            final colKids = <Widget>[];
            for (var i = 0; i < children.length; i++) {
              colKids.add(children[i]);
              if (i != children.length - 1) {
                colKids.add(SizedBox(height: gap));
              }
            }
            return Column(
              crossAxisAlignment: crossAxisAlignment,
              children: colKids,
            );
          }
        }

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
                  // Filters
                  ReportsFilters(
                    medicines: _medicines,
                    selectedMedicine: _selectedMedicine,
                    onMedicineChanged: (value) {
                      setState(() => _selectedMedicine = value);

                      // Update global dashboard filter (medicine only).
                      updateDashboardFilter(ref, medicine: value);
                    },
                  ),

                  SizedBox(height: gap),

                  // Key Metrics + Symptoms Activity
                  if (axisForTwoUp == Axis.horizontal)
                    responsiveGroup(
                      axis: axisForTwoUp,
                      gap: gap,
                      children: [
                        KeyedSubtree(
                          key: _keyMetricsKey,
                          child: const KeyMetricsPanel(),
                        ),
                        SizedBox(
                          height:
                              _measuredKeyMetricsHeight ??
                              overviewFallbackHeight,
                          child: SymptomsActivityPanel(
                            height:
                                _measuredKeyMetricsHeight ??
                                overviewFallbackHeight,
                            timeframe: _selectedTimeFrame,
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
                            medicine: _selectedMedicine,
                          ),
                        ),
                      ],
                    ),

                  SizedBox(height: gap),

                  // Clinical Mgmt + Patient Experience
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

                  // Geo Table
                  responsiveGroup(
                    axis: axisForTwoUp,
                    gap: gap,
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

// --- panel height helpers ---
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
