import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class BbmTable extends StatefulWidget {
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
  State<BbmTable> createState() => _BbmTableState();
}

class _BbmTableState extends State<BbmTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _getColumnWidth(int index, double totalWidth) {
    final double sumRatio = widget.columnWidths.reduce((a, b) => a + b);
    return (widget.columnWidths[index] / sumRatio) * totalWidth;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth = constraints.maxWidth > widget.minWidth
            ? constraints.maxWidth
            : widget.minWidth;

        Widget tableContent = SizedBox(
          width: tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    widget.headers.length,
                    (index) => SizedBox(
                      width: _getColumnWidth(index, tableWidth),
                      child: widget.headers[index],
                    ),
                  ),
                ),
              ),
              // Body Rows
              ...widget.rows.map(
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

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: tableContent,
            ),
          ),
        );
      },
    );
  }
}

class BbmTableRow extends StatelessWidget {
  final List<Widget> cells;
  final List<double> columnWidths;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const BbmTableRow({
    super.key,
    required this.cells,
    required this.columnWidths,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget rowContent = Padding(
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
    );

    if (onTap != null) {
      return Material(
        color: backgroundColor ?? Colors.transparent,
        child: InkWell(onTap: onTap, child: rowContent),
      );
    }

    return Container(color: backgroundColor, child: rowContent);
  }
}
