import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class BbmTable extends StatelessWidget {
  final List<Widget> headers;
  final List<Widget> rows;
  final List<double> columnWidths; // Width per column
  final double minWidth; // Minimum total width to trigger scroll

  const BbmTable({
    super.key,
    required this.headers,
    required this.rows,
    required this.columnWidths,
    this.minWidth = 500.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth = constraints.maxWidth > minWidth 
            ? constraints.maxWidth 
            : minWidth;

        Widget tableContent = SizedBox(
          width: tableWidth,
          child: Column(
            children: [
              // Header Row
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 2),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: List.generate(
                    headers.length,
                    (index) => SizedBox(
                      width: _getColumnWidth(index, tableWidth),
                      child: headers[index],
                    ),
                  ),
                ),
              ),
              // Body Rows
              ...rows.map(
                (row) => Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: row,
                ),
              ),
            ],
          ),
        );

        if (constraints.maxWidth < minWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: tableContent,
          );
        }

        return tableContent;
      },
    );
  }

  double _getColumnWidth(int index, double totalWidth) {
    final double sumRatio = columnWidths.reduce((a, b) => a + b);
    return (columnWidths[index] / sumRatio) * totalWidth;
  }
}

class BbmTableRow extends StatelessWidget {
  final List<Widget> cells;
  final List<double> columnWidths;
  final VoidCallback? onTap;

  const BbmTableRow({
    super.key,
    required this.cells,
    required this.columnWidths,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double rowWidth = constraints.maxWidth;
            final double sumRatio = columnWidths.reduce((a, b) => a + b);
            return Row(
              children: List.generate(
                cells.length,
                (index) => SizedBox(
                  width: (columnWidths[index] / sumRatio) * rowWidth,
                  child: cells[index],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
