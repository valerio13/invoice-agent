import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../app_state.dart';
import '../format.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';

/// Figures, spend by month and suppliers, with a way into the invoices waiting for review.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.state,
    required this.onReview,
    required this.onExport,
  });

  final AppState state;
  final VoidCallback onReview;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final metrics = state.metrics;
    if (metrics == null) {
      return _Message(
        text: state.error ?? 'Loading\u2026',
        action: state.error == null
            ? null
            : AppButton(label: 'Try again', kind: ButtonKind.primary, onPressed: state.refresh),
      );
    }
    final current = metrics.spendByMonth.last.month;
    final previous = metrics.spendByMonth.length > 1
        ? metrics.spendByMonth[metrics.spendByMonth.length - 2].month
        : null;
    final trend = change(metrics.spendThisMonth, metrics.spendLastMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 30),
          child: Row(
            children: [
              for (final (index, tile) in [
                StatTile(
                  ink: true,
                  label: 'Spend in ${monthName(current)}',
                  figure: money(metrics.spendThisMonth),
                  note: trend == null || previous == null
                      ? null
                      : '$trend vs ${monthName(previous)}',
                ),
                StatTile(
                  label: 'Invoices',
                  figure: '${metrics.invoices}',
                  note: '${metrics.invoicesThisMonth} this month',
                ),
                StatTile(
                  label: 'To review',
                  figure: '${metrics.needsReview}',
                  note: metrics.needsReview == 0 ? 'All clear' : 'Waiting for you',
                ),
                StatTile(
                  label: 'Duplicates',
                  figure: '${metrics.duplicates}',
                  note: 'Left out of Excel',
                ),
              ].indexed) ...[if (index > 0) const SizedBox(width: 20), Expanded(child: tile)],
            ],
          ),
        ),
        const SizedBox(height: 26),
        ListHead(
          title: 'Spend by month',
          actions: [
            if (state.demoMode)
              AppButton(
                label: 'Load demo',
                icon: Icons.refresh_rounded,
                onPressed: state.busy ? null : state.loadDemo,
              ),
            AppButton(label: 'Export Excel', onPressed: metrics.ok == 0 ? null : onExport),
          ],
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: metrics.invoices == 0
                    ? _Message(
                        text: state.demoMode
                            ? 'No invoices yet. Load the demo set to see the agent at work.'
                            : 'No invoices yet. Drop some on the Invoices screen.',
                      )
                    : _SpendChart(months: metrics.spendByMonth),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: AppSizes.wPanel,
                child: _SuppliersPanel(metrics: metrics, month: current, onReview: onReview),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: AppSizes.rRow,
    padding: const EdgeInsets.all(40),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center, style: AppText.body(size: 13)),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    ),
  );
}

class _SpendChart extends StatelessWidget {
  const _SpendChart({required this.months});

  final List<MonthSpend> months;

  @override
  Widget build(BuildContext context) {
    final total = months.fold(0.0, (sum, month) => sum + month.total);
    final highest = months.fold(0.0, (top, month) => month.total > top ? month.total : top);
    final range = '${monthName(months.first.month)} to ${monthName(months.last.month)}';
    return AppCard(
      radius: AppSizes.rRow,
      padding: const EdgeInsets.fromLTRB(36, 34, 36, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _HeadFigure(label: 'Total, $range', figure: money(total)),
              ),
              const SizedBox(width: 20),
              _HeadFigure(
                label: 'Monthly average',
                figure: money(total / months.length),
                end: true,
              ),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.field, width: 2)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (index, month) in months.indexed) ...[
                      if (index > 0) const SizedBox(width: 22),
                      Expanded(
                        child: _Bar(
                          value: month.total,
                          // Room is left above the tallest bar for its label.
                          height: highest == 0
                              ? 0
                              : (constraints.maxHeight - 24) * month.total / highest,
                          current: index == months.length - 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (index, month) in months.indexed) ...[
                if (index > 0) const SizedBox(width: 22),
                Expanded(
                  child: Text(
                    monthShort(month.month),
                    textAlign: TextAlign.center,
                    style: AppText.label(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeadFigure extends StatelessWidget {
  const _HeadFigure({required this.label, required this.figure, this.end = false});

  final String label;
  final String figure;
  final bool end;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: AppText.label()),
      const SizedBox(height: 10),
      Text(figure, style: AppText.figure(size: AppSizes.fsStat)),
    ],
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.height, required this.current});

  final double value;
  final double height;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = current ? AppColors.accent : AppColors.ink;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 14,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              moneyShort(value),
              maxLines: 1,
              style: AppText.label(color: current ? AppColors.accent : AppColors.text, size: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
        ),
      ],
    );
  }
}

const _supplierRowHeight = 56.0;

class _SuppliersPanel extends StatelessWidget {
  const _SuppliersPanel({required this.metrics, required this.month, required this.onReview});

  final Metrics metrics;
  final DateTime month;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final top = metrics.topSuppliers.take(4).toList();
    final share = metrics.spendThisMonth == 0 || top.isEmpty
        ? '-'
        : '${(top.first.total / metrics.spendThisMonth * 100).round()}%';
    final settled = metrics.invoices == 0 ? 0.0 : metrics.ok / metrics.invoices;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.rPanel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: AppColors.ink,
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _PanelFigure(label: 'Suppliers', figure: '${metrics.suppliers}'),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            monthName(month).toUpperCase(),
                            textAlign: TextAlign.center,
                            style: AppText.panelLabel(),
                          ),
                        ),
                      ),
                      _PanelFigure(label: 'Top share', figure: share, end: true),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    // Only the suppliers that fit are shown, so a short window never cuts a row.
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (top.isEmpty) {
                          return Text(
                            'No invoices this month yet.',
                            style: AppText.body(color: AppColors.onInkMuted),
                          );
                        }
                        final fit = (constraints.maxHeight / _supplierRowHeight).floor();
                        return ClipRect(
                          child: Column(
                            children: [
                              for (final supplier in top.take(fit))
                                SizedBox(
                                  height: _supplierRowHeight,
                                  child: _SupplierBar(
                                    supplier: supplier,
                                    fraction: supplier.total / top.first.total,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: AppColors.inkDeep,
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('WAITING FOR YOU', style: AppText.panelLabel()),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${metrics.needsReview} ${metrics.needsReview == 1 ? 'invoice' : 'invoices'}',
                        style: AppText.figure(
                          color: AppColors.onInk,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    AppButton(
                      label: 'Review now',
                      kind: ButtonKind.small,
                      onPressed: metrics.needsReview == 0 ? null : onReview,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Totals that do not add up and fields the model was not sure about.',
                  style: AppText.body(color: AppColors.onInkMuted, size: 10.5),
                ),
                const SizedBox(height: 18),
                _Track(fraction: settled),
                const SizedBox(height: 12),
                Text(
                  '${metrics.ok} of ${metrics.invoices} invoices need nothing from you.',
                  style: AppText.body(color: AppColors.onInkMuted, size: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelFigure extends StatelessWidget {
  const _PanelFigure({required this.label, required this.figure, this.end = false});

  final String label;
  final String figure;
  final bool end;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: AppText.panelLabel(size: 10).copyWith(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 9),
      Text(
        figure,
        style: AppText.figure(color: AppColors.onInk).copyWith(fontWeight: FontWeight.w500),
      ),
    ],
  );
}

class _SupplierBar extends StatelessWidget {
  const _SupplierBar({required this.supplier, required this.fraction});

  final SupplierSpend supplier;
  final double fraction;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              supplier.supplier.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: AppText.panelLabel(),
            ),
          ),
          Text(money(supplier.total), style: AppText.panelLabel()),
        ],
      ),
      const SizedBox(height: 9),
      _Track(fraction: fraction, height: 8, background: const Color(0x29FFFFFF)),
    ],
  );
}

class _Track extends StatelessWidget {
  const _Track({
    required this.fraction,
    this.height = 2,
    this.background = const Color(0x4DFFFFFF),
  });

  final double fraction;
  final double height;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(height / 2)),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: fraction.clamp(0, 1),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    ),
  );
}
