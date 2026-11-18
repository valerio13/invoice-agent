import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../app_state.dart';
import '../format.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/pills.dart';
import '../widgets/supplier_icon.dart';
import '../widgets/ticket.dart';

enum _FileType { any, pdf, image }

/// Every invoice as a ticket, with filters on top and the selected one in the dark panel.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key,
    required this.state,
    required this.onReview,
    required this.onExport,
    required this.onAddFiles,
  });

  final AppState state;
  final ValueChanged<int> onReview;
  final VoidCallback onExport;

  /// Opens the file dialog. Null while files are being read.
  final VoidCallback? onAddFiles;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  DateTimeRange? _dates;
  String? _supplier;
  String? _currency;
  InvoiceStatus? _status;
  String _search = '';
  bool _newestFirst = true;
  _FileType _fileType = _FileType.any;
  RangeValues? _totals;
  int? _selectedId;

  List<Invoice> get _all => widget.state.invoices;

  double get _highestTotal =>
      _all.fold(0.0, (top, invoice) => invoice.total > top ? invoice.total : top).ceilToDouble();

  List<Invoice> _filtered() {
    final search = _search.trim().toLowerCase();
    final totals = _totals;
    final result = _all.where((invoice) {
      if (_status != null && invoice.status != _status) return false;
      if (_supplier != null && invoice.supplier != _supplier) return false;
      if (_currency != null && invoice.currency != _currency) return false;
      if (_fileType == _FileType.pdf && !invoice.isPdf) return false;
      if (_fileType == _FileType.image && invoice.isPdf) return false;
      if (_dates != null &&
          (invoice.issueDate.isBefore(_dates!.start) || invoice.issueDate.isAfter(_dates!.end))) {
        return false;
      }
      if (totals != null && (invoice.total < totals.start || invoice.total > totals.end)) {
        return false;
      }
      if (search.isNotEmpty &&
          !invoice.invoiceNumber.toLowerCase().contains(search) &&
          !invoice.supplier.toLowerCase().contains(search)) {
        return false;
      }
      return true;
    }).toList();
    result.sort(
      (a, b) =>
          _newestFirst ? b.issueDate.compareTo(a.issueDate) : a.issueDate.compareTo(b.issueDate),
    );
    return result;
  }

  Future<void> _pickDates() async {
    if (_all.isEmpty) return;
    final dates = _all.map((invoice) => invoice.issueDate);
    final first = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: _dates ?? DateTimeRange(start: first, end: last),
    );
    if (picked != null) setState(() => _dates = picked);
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _filtered();
    final selected =
        invoices.where((invoice) => invoice.id == _selectedId).firstOrNull ?? invoices.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filters(),
        const SizedBox(height: 26),
        ListHead(
          title: 'Invoices (${invoices.length})',
          actions: [
            AppButton(label: 'Add files', icon: Icons.add_rounded, onPressed: widget.onAddFiles),
            AppButton(
              label: _newestFirst ? 'Newest first' : 'Oldest first',
              icon: Icons.swap_vert_rounded,
              onPressed: () => setState(() => _newestFirst = !_newestFirst),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: invoices.isEmpty
                    ? AppCard(
                        radius: AppSizes.rRow,
                        child: Center(
                          child: Text(
                            _all.isEmpty ? 'No invoices yet.' : 'No invoice matches these filters.',
                            style: AppText.body(size: 13),
                          ),
                        ),
                      )
                    : _TicketList(
                        invoices: invoices,
                        selectedId: selected?.id,
                        onSelect: (id) => setState(() => _selectedId = id),
                        onReview: widget.onReview,
                      ),
              ),
              const SizedBox(width: 24),
              SizedBox(width: AppSizes.wPanel, child: _panel(selected)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filters() {
    final suppliers = {for (final invoice in _all) invoice.supplier}.toList()..sort();
    final currencies = {for (final invoice in _all) invoice.currency}.toList()..sort();
    final dateFormat = DateFormat('dd MMM yyyy', 'en_US');
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 30),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 428,
                child: Pill(
                  icon: Icons.calendar_today_rounded,
                  onTap: _pickDates,
                  onClear: _dates == null ? null : () => setState(() => _dates = null),
                  child: Text(
                    _dates == null
                        ? 'ALL DATES'
                        : '${dateFormat.format(_dates!.start)}  -  ${dateFormat.format(_dates!.end)}'
                              .toUpperCase(),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 178,
                child: _Choice<String>(
                  icon: Icons.apartment_rounded,
                  label: _supplier ?? 'Suppliers',
                  active: _supplier != null,
                  allLabel: 'All suppliers',
                  options: suppliers,
                  onSelect: (value) => setState(() => _supplier = value),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 178,
                child: _Choice<String>(
                  icon: Icons.euro_rounded,
                  label: _currency ?? 'Currency',
                  active: _currency != null,
                  allLabel: 'All currencies',
                  options: currencies,
                  onSelect: (value) => setState(() => _currency = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 428,
                child: Segmented<InvoiceStatus?>(
                  options: const [
                    (null, 'All'),
                    (InvoiceStatus.needsReview, 'To review'),
                    (InvoiceStatus.duplicate, 'Duplicates'),
                  ],
                  selected: _status,
                  onSelect: (value) => setState(() => _status = value),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 178,
                child: SearchPill(
                  hint: 'Find number',
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 178,
                child: AppButton(
                  label: 'Export Excel',
                  kind: ButtonKind.primary,
                  expand: true,
                  onPressed: widget.onExport,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panel(Invoice? invoice) {
    final highest = _highestTotal;
    final totals = _totals ?? RangeValues(0, highest);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.rPanel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: AppColors.ink,
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 20),
              child: invoice == null
                  ? Center(
                      child: Text(
                        'Pick an invoice to see it here.',
                        style: AppText.body(color: AppColors.onInkMuted),
                      ),
                    )
                  : _InvoiceSummary(invoice: invoice),
            ),
          ),
          Container(
            color: AppColors.inkDeep,
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Segmented<_FileType>(
                  onInk: true,
                  options: const [
                    (_FileType.any, 'Any type'),
                    (_FileType.pdf, 'PDF'),
                    (_FileType.image, 'Image'),
                  ],
                  selected: _fileType,
                  onSelect: (value) => setState(() => _fileType = value),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('TOTAL', style: AppText.panelLabel()),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: const Color(0x4DFFFFFF),
                    thumbColor: AppColors.accent,
                    overlayColor: const Color(0x33C99C35),
                    trackHeight: 2,
                  ),
                  child: RangeSlider(
                    min: 0,
                    max: highest <= 0 ? 1 : highest,
                    values: highest <= 0 ? const RangeValues(0, 1) : totals,
                    onChanged: highest <= 0 ? null : (values) => setState(() => _totals = values),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [_Badge(money(totals.start)), _Badge(money(totals.end))],
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

/// A pill that opens a menu of options, with "all" first.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.label,
    required this.allLabel,
    required this.options,
    required this.onSelect,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final String allLabel;
  final List<T> options;
  final ValueChanged<T?> onSelect;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      MenuItemButton(
        onPressed: () => onSelect(null),
        child: Text(allLabel, style: AppText.body()),
      ),
      for (final option in options)
        MenuItemButton(
          onPressed: () => onSelect(option),
          child: Text('$option', style: AppText.body()),
        ),
    ],
    builder: (context, controller, _) => Pill(
      icon: icon,
      onTap: () => controller.isOpen ? controller.close() : controller.open(),
      onClear: active ? () => onSelect(null) : null,
      child: Text(label.toUpperCase()),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(7)),
    child: Text(text, style: AppText.label(color: AppColors.onAccent, size: 9)),
  );
}

class _InvoiceSummary extends StatelessWidget {
  const _InvoiceSummary({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final figure = AppText.figure(color: AppColors.onInk).copyWith(fontWeight: FontWeight.w500);
    final label = AppText.panelLabel(size: 10).copyWith(fontWeight: FontWeight.w500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NET', style: label),
                  const SizedBox(height: 9),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(amount(invoice.netAmount), style: figure),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('VAT ${percent(invoice.vatRate)}', style: AppText.panelLabel()),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TOTAL', style: label),
                  const SizedBox(height: 9),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(amount(invoice.total), style: figure),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Expanded(child: CustomPaint(painter: _DocumentArt())),
        Text(
          invoice.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.panelLabel(),
        ),
        const SizedBox(height: 6),
        Text(
          invoice.reviewReasons.isEmpty
              ? 'Read with ${(invoice.confidence * 100).round()}% confidence. Nothing to check.'
              : invoice.reviewReasons.first,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(color: AppColors.onInkMuted, size: 10.5),
        ),
      ],
    );
  }
}

/// A dotted document with a gold line from the net amount to the total, as in the mockup.
class _DocumentArt extends CustomPainter {
  const _DocumentArt();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height < 60) return;
    final height = size.height - 20;
    final width = height * 0.75;
    final left = (size.width - width) / 2;
    final top = 10.0;
    final fold = width * 0.22;
    final page = Path()
      ..moveTo(left, top)
      ..lineTo(left + width - fold, top)
      ..lineTo(left + width, top + fold)
      ..lineTo(left + width, top + height)
      ..lineTo(left, top + height)
      ..close();
    canvas.save();
    canvas.clipPath(page);
    final dot = Paint()..color = AppColors.inkDot;
    for (var y = top + 3; y < top + height; y += 6) {
      for (var x = left + 3; x < left + width; x += 6) {
        canvas.drawCircle(Offset(x, y), 1.25, dot);
      }
    }
    canvas.restore();
    final from = Offset(left + width * 0.2, top + height * 0.66);
    final to = Offset(left + width * 0.82, top + height * 0.56);
    final gold = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo((from.dx + to.dx) / 2, top + height * 0.2, to.dx, to.dy),
      gold,
    );
    final fill = Paint()..color = AppColors.accent;
    canvas.drawCircle(from, 4.5, fill);
    canvas.drawCircle(to, 4.5, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TicketList extends StatelessWidget {
  const _TicketList({
    required this.invoices,
    required this.selectedId,
    required this.onSelect,
    required this.onReview,
  });

  final List<Invoice> invoices;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onReview;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppSizes.rRow),
    child: ListView.separated(
      itemCount: invoices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) => _Ticket(
        invoice: invoices[index],
        first: index == 0,
        last: index == invoices.length - 1,
        selected: invoices[index].id == selectedId,
        onTap: () => onSelect(invoices[index].id),
        onReview: () => onReview(invoices[index].id),
      ),
    ),
  );
}

class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.invoice,
    required this.first,
    required this.last,
    required this.selected,
    required this.onTap,
    required this.onReview,
  });

  final Invoice invoice;
  final bool first;
  final bool last;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (invoice.status) {
      InvoiceStatus.ok => AppColors.text,
      InvoiceStatus.needsReview => AppColors.accent,
      InvoiceStatus.duplicate => AppColors.textMuted,
    };
    final row = GestureDetector(
      onTap: onTap,
      child: Container(
        height: 136,
        padding: const EdgeInsets.only(right: 28),
        // The selected ticket gets a light gold tint, the one shown in the panel.
        decoration: ticketDecoration(
          first: first,
          last: last,
          color: selected ? AppColors.accentTint : null,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 116,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SupplierIcon(supplier: invoice.supplier),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      invoice.supplier,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(size: 9.5).copyWith(letterSpacing: 0.1, height: 1.15),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 92,
              child: _Figure(
                DateFormat('dd MMM', 'en_US').format(invoice.issueDate).toUpperCase(),
                '${invoice.issueDate.year}',
              ),
            ),
            Expanded(
              flex: 96,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    Text(invoice.invoiceNumber, style: AppText.label(size: 9)),
                    const SizedBox(height: 9),
                    Text(
                      'VAT ${percent(invoice.vatRate)}',
                      style: AppText.label(color: AppColors.accent, size: 10.5),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      invoice.status.label.toUpperCase(),
                      style: AppText.label(color: statusColor, size: 10.5).copyWith(
                        fontWeight: invoice.status == InvoiceStatus.ok
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(flex: 108, child: _Figure(amount(invoice.netAmount), 'NET')),
            Expanded(
              flex: 120,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      moneyExact(invoice.total, invoice.currency),
                      style: AppText.label(size: AppSizes.fsTotal).copyWith(letterSpacing: 0),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppButton(label: 'Review', kind: ButtonKind.small, onPressed: onReview),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return first ? row : Notched(child: row);
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.figure, this.caption);

  final String figure;
  final String caption;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Column(
      children: [
        Text(figure, style: AppText.figure()),
        const SizedBox(height: 12),
        Text(caption, style: AppText.body().copyWith(letterSpacing: 0.5)),
      ],
    ),
  );
}
