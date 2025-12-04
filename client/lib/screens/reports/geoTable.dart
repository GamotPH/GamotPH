// lib/screens/reports/geoTable.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/providers.dart';

class GeoTablePanel extends ConsumerStatefulWidget {
  const GeoTablePanel({super.key});

  @override
  ConsumerState<GeoTablePanel> createState() => _GeoTablePanelState();
}

class _GeoTablePanelState extends ConsumerState<GeoTablePanel> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(geoDistributionProvider);
    final nf = NumberFormat.decimalPattern();

    return _Panel(
      title: 'Geo Distribution',
      child: rowsAsync.when(
        loading:
            () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
        error:
            (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load geo data: $e'),
            ),
        data: (rows) {
          if (rows.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No data for the selected range.'),
            );
          }

          // rows are already sorted by reports desc in the provider
          final visibleRows =
              _showAll ? rows : rows.take(5).toList(growable: false);

          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final bool isPhone = w < 640;

              // Make the table fill the available width; scroll only if it grows wider.
              final double minTableWidth = w;
              final double columnSpacing = isPhone ? 18.0 : 24.0;
              final double headingRowHeight = isPhone ? 40.0 : 48.0;
              final double dataRowHeight = isPhone ? 36.0 : 44.0;

              final table = DataTable(
                columnSpacing: columnSpacing,
                columns: const [
                  DataColumn(label: _Hdr('Location')),
                  // not numeric so we can center the text ourselves
                  DataColumn(label: _Hdr('Active users'), numeric: false),
                  DataColumn(label: _Hdr('Reports'), numeric: true),
                ],
                rows:
                    visibleRows
                        .map(
                          (r) => DataRow(
                            cells: [
                              // Location – left, with widest area
                              DataCell(_Cell(r.location)),
                              // Active users – centered in its column
                              DataCell(
                                _Cell(
                                  nf.format(r.activeUsers),
                                  align: TextAlign.center,
                                ),
                              ),
                              // Reports – right aligned
                              DataCell(
                                _Cell(
                                  nf.format(r.reports),
                                  align: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top row: "showing X of Y" + toggle button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _showAll
                            ? 'Showing all ${rows.length} locations'
                            : 'Showing top ${visibleRows.length} of ${rows.length} locations',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showAll = !_showAll;
                          });
                        },
                        child: Text(_showAll ? 'Show top 5' : 'Show all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DataTableTheme(
                    data: DataTableThemeData(
                      headingRowHeight: headingRowHeight,
                      dataRowMinHeight: dataRowHeight,
                      dataRowMaxHeight: dataRowHeight,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: minTableWidth),
                        child: table,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  final String text;
  const _Hdr(this.text);
  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: isPhone ? 12.0 : 13.0,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _Cell(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    return Text(
      text,
      textAlign: align,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontSize: isPhone ? 12.0 : 13.0),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 640;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isPhone ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: isPhone ? 15.0 : 16.0,
              ),
            ),
            SizedBox(height: isPhone ? 10 : 12),
            child,
          ],
        ),
      ),
    );
  }
}
