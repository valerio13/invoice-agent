import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../app_state.dart';
import '../files.dart';
import '../format.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/ticket.dart';

/// What the Excel workbook will hold, and the button that saves it.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.state, required this.files, required this.onReview});

  final AppState state;
  final FileAccess files;
  final VoidCallback onReview;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _saving = false;
  String? _savedTo;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Built at this moment, so it holds what was approved a second ago.
      final workbook = await widget.state.api.export();
      final path = await widget.files.saveWorkbook(workbook);
      // Only the name of the folder: the full path says more about the disk than needed.
      if (mounted && path != null) {
        final folder = File(path).parent.uri.pathSegments.where((part) => part.isNotEmpty);
        setState(() => _savedTo = folder.isEmpty ? '/' : folder.last);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = 'The workbook could not be saved: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.state.exportSummary;
    if (summary == null) {
      return AppCard(
        radius: AppSizes.rRow,
        child: Center(child: Text(widget.state.error ?? 'Loading…', style: AppText.body(size: 13))),
      );
    }
    final sheets = summary.sheets.length;

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
                  label: 'In the Excel',
                  figure: '${summary.invoices}',
                  note: '$sheets ${sheets == 1 ? 'sheet' : 'sheets'}, one per month',
                ),
                StatTile(
                  label: 'To review',
                  figure: '${summary.needsReview}',
                  note: summary.needsReview == 0 ? 'All clear' : 'Left out until approved',
                ),
                StatTile(
                  label: 'Duplicates',
                  figure: '${summary.duplicates}',
                  note: 'Left out of Excel',
                ),
              ].indexed) ...[if (index > 0) const SizedBox(width: 20), Expanded(child: tile)],
            ],
          ),
        ),
        const SizedBox(height: 26),
        ListHead(title: 'Sheets ($sheets)'),
        const SizedBox(height: 30),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: summary.sheets.isEmpty
                    ? AppCard(
                        radius: AppSizes.rRow,
                        child: Center(
                          child: Text(
                            'No invoice is ready for the Excel yet.',
                            style: AppText.body(size: 13),
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(AppSizes.rRow),
                        child: ListView.separated(
                          itemCount: summary.sheets.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 2),
                          itemBuilder: (context, index) => _SheetRow(
                            sheet: summary.sheets[index],
                            first: index == 0,
                            last: index == summary.sheets.length - 1,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 24),
              SizedBox(width: AppSizes.wPanel, child: _panel(summary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel(ExportSummary summary) {
    final status = _error ?? (_savedTo == null ? null : 'Saved to $_savedTo');
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.rPanel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: AppColors.ink,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PanelFigure(label: 'Workbook', figure: '${summary.invoices} invoices'),
                    const SizedBox(height: 14),
                    Text(summary.fileName, style: AppText.body(color: AppColors.onInk, size: 12)),
                    const SizedBox(height: 26),
                    for (final point in const [
                      'One sheet per month, newest first.',
                      'Totals per currency at the end of each sheet.',
                      'Only invoices that passed the checks or that you approved.',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Icons.check_rounded, size: 14, color: AppColors.accent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                point,
                                style: AppText.body(color: AppColors.onInkMuted, size: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: AppColors.inkDeep,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: _saving ? 'Saving…' : 'Save Excel',
                  kind: ButtonKind.primary,
                  icon: Icons.download_rounded,
                  expand: true,
                  onPressed: _saving || summary.invoices == 0 ? null : _save,
                ),
                if (summary.needsReview > 0) ...[
                  const SizedBox(height: 10),
                  LineButton(
                    label: 'Review ${summary.needsReview} first',
                    onPressed: widget.onReview,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  status ?? 'Built from the database each time you save it.',
                  style: AppText.body(
                    color: _error == null ? AppColors.onInkMuted : AppColors.accent,
                    size: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One sheet of the workbook, as a ticket: the month, its invoices and its totals.
class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.sheet, required this.first, required this.last});

  final SheetSummary sheet;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    Widget amounts(double Function(CurrencyTotal line) value, String caption, {bool end = false}) =>
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: end ? Alignment.centerRight : Alignment.center,
          child: Column(
            crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.center,
            children: [
              for (final line in sheet.totals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    moneyExact(value(line), line.currency),
                    style: end
                        ? AppText.label(size: AppSizes.fsTotal).copyWith(letterSpacing: 0)
                        : AppText.body(size: 12).copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                caption,
                style: AppText.body(
                  color: end ? AppColors.accent : AppColors.text,
                ).copyWith(letterSpacing: 0.5),
              ),
            ],
          ),
        );

    final row = Container(
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: ticketDecoration(first: first, last: last),
      child: Row(
        children: [
          Expanded(
            flex: 96,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: [
                  Text(monthShort(sheet.month), style: AppText.figure()),
                  const SizedBox(height: 12),
                  Text('${sheet.month.year}', style: AppText.body().copyWith(letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 120,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: [
                  Text('SHEET ${sheet.name}', style: AppText.label(size: 9)),
                  const SizedBox(height: 9),
                  Text(
                    '${sheet.invoices} ${sheet.invoices == 1 ? 'INVOICE' : 'INVOICES'}',
                    style: AppText.label(color: AppColors.accent, size: 10.5),
                  ),
                ],
              ),
            ),
          ),
          Expanded(flex: 120, child: amounts((line) => line.netAmount, 'NET')),
          Expanded(flex: 110, child: amounts((line) => line.vatAmount, 'VAT')),
          Expanded(flex: 140, child: amounts((line) => line.total, 'TOTAL', end: true)),
        ],
      ),
    );
    return first ? row : Notched(child: row);
  }
}
