import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/pills.dart';

/// The invoices waiting for review, one at a time: the document next to its fields.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.state, this.initialId});

  final AppState state;

  /// The invoice to open first, when the reviewer came from the Invoices screen.
  final int? initialId;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  // 100% fits the page in the card; the viewer allows up to 400%.
  static const _zoomLevels = [1.0, 1.25, 1.5, 2.0, 3.0, 4.0];

  int? _currentId;
  // An invoice opened from the Invoices screen stays in the queue even if it needs nothing.
  int? _pinnedId;
  final Map<int, Future<Uint8List>> _previews = {};
  final Map<String, TextEditingController> _controllers = {};
  final _transform = TransformationController();
  int _zoom = 0;
  // Size of the document card and keys to find the page in it, to anchor the zoom.
  Size _viewport = Size.zero;
  final _canvasKey = GlobalKey();
  final _pageKey = GlobalKey();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pinnedId = widget.initialId;
    _currentId = widget.initialId;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _transform.dispose();
    super.dispose();
  }

  List<Invoice> get _queue => [
    for (final invoice in widget.state.invoices)
      if (invoice.status == InvoiceStatus.needsReview || invoice.id == _pinnedId) invoice,
  ];

  Invoice? _current(List<Invoice> queue) =>
      queue.where((invoice) => invoice.id == _currentId).firstOrNull ?? queue.firstOrNull;

  void _open(Invoice invoice) {
    setState(() {
      _currentId = invoice.id;
      _error = null;
      _zoom = 0;
      _transform.value = Matrix4.identity();
      _fillFields(invoice);
    });
  }

  void _fillFields(Invoice invoice) {
    final values = InvoiceFields.of(invoice).values;
    for (final entry in values.entries) {
      (_controllers[entry.key] ??= TextEditingController()).text = entry.value;
    }
    _filledFor = invoice.id;
  }

  int? _filledFor;

  InvoiceFields _fields(Invoice invoice) => InvoiceFields({
    for (final name in fieldLabels.keys) name: _controllers[name]!.text,
  }, confidence: invoice.confidence);

  Future<void> _act(
    Invoice invoice,
    List<Invoice> queue,
    Future<Invoice> Function(ApiClient api) action,
  ) async {
    final index = queue.indexOf(invoice);
    final next = index + 1 < queue.length
        ? queue[index + 1]
        : (index > 0 ? queue[index - 1] : null);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action(widget.state.api);
      if (_pinnedId == invoice.id) _pinnedId = null;
      await widget.state.reload();
      if (!mounted) return;
      setState(() => _currentId = next?.id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Top of the page inside the card, before any zoom.
  double _pageTop() {
    final page = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    final card = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (page == null || card == null) return 0;
    return page.localToGlobal(Offset.zero, ancestor: card).dy;
  }

  void _setZoom(int level) {
    setState(() {
      _zoom = level;
      // Keep the top edge of the page where it is and grow evenly left and right,
      // so the reviewer starts reading at the header of the invoice.
      final scale = _zoomLevels[level];
      final shift = Offset(_viewport.width / 2, _pageTop()) * (1 - scale);
      _transform.value = Matrix4.translationValues(shift.dx, shift.dy, 0)
        ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
    });
  }

  static String _percent(double scale) => '${(scale * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    final invoice = _current(queue);
    if (invoice == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListHead(title: 'Review'),
          const SizedBox(height: 30),
          Expanded(
            child: AppCard(
              radius: AppSizes.rRow,
              child: Center(
                child: Text(
                  widget.state.invoices.isEmpty
                      ? 'No invoices yet.'
                      : 'Nothing is waiting for review. Every invoice is ready for the Excel.',
                  style: AppText.body(size: 13),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_filledFor != invoice.id) _fillFields(invoice);
    final index = queue.indexOf(invoice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 30),
          child: Row(
            children: [
              Expanded(
                flex: 428,
                child: Pill(
                  icon: Icons.description_outlined,
                  child: Row(
                    children: [
                      Flexible(child: Text(invoice.supplier.toUpperCase())),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          invoice.fileName,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 178,
                child: Pill(
                  center: true,
                  onTap: index > 0 && !_saving ? () => _open(queue[index - 1]) : null,
                  child: Text('PREVIOUS', style: _navStyle(index > 0)),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 178,
                child: Pill(
                  center: true,
                  onTap: index < queue.length - 1 && !_saving
                      ? () => _open(queue[index + 1])
                      : null,
                  child: Text('NEXT', style: _navStyle(index < queue.length - 1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        ListHead(
          title: 'Review (${index + 1} of ${queue.length})',
          actions: [
            MenuAnchor(
              menuChildren: [
                for (final (level, scale) in _zoomLevels.indexed)
                  MenuItemButton(
                    onPressed: () => _setZoom(level),
                    leadingIcon: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: level == _zoom ? AppColors.text : Colors.transparent,
                    ),
                    child: Text(_percent(scale), style: AppText.body()),
                  ),
              ],
              builder: (context, controller, _) => AppButton(
                label: 'Zoom ${_percent(_zoomLevels[_zoom])}',
                icon: Icons.zoom_in_rounded,
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _documentView(invoice)),
              const SizedBox(width: 24),
              SizedBox(width: AppSizes.wPanel, child: _panel(invoice, queue)),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _navStyle(bool enabled) =>
      AppText.label(size: AppSizes.fsLabel, color: enabled ? AppColors.text : AppColors.textMuted);

  Widget _documentView(Invoice invoice) {
    final preview = _previews[invoice.id] ??= widget.state.api.preview(invoice.id);
    return AppCard(
      radius: AppSizes.rRow,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.rRow),
        child: FutureBuilder<Uint8List>(
          future: preview,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: AppText.body(),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.ink));
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                _viewport = constraints.biggest;
                return InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 4,
                  child: Padding(
                    key: _canvasKey,
                    padding: const EdgeInsets.all(26),
                    child: Center(
                      child: DecoratedBox(
                        key: _pageKey,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          border: Border.all(color: const Color(0xFFDBE5E4)),
                          boxShadow: const [BoxShadow(color: AppColors.surface, spreadRadius: 10)],
                        ),
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          semanticLabel: 'Invoice ${invoice.fileName}',
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _panel(Invoice invoice, List<Invoice> queue) {
    final doubtful = invoice.doubtfulFields.toSet();
    final reasons = invoice.reviewReasons;
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: PanelFigure(
                            label: 'Read by the model',
                            figure: '${fieldLabels.length} fields',
                          ),
                        ),
                        const SizedBox(width: 12),
                        PanelFigure(
                          label: 'To check',
                          figure: '${doubtful.length}',
                          color: doubtful.isEmpty ? AppColors.onInk : AppColors.accent,
                          end: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _fieldGrid(doubtful),
                    if (reasons.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      for (final reason in reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            reason,
                            style: AppText.body(color: AppColors.accent, size: 10.5),
                          ),
                        ),
                    ],
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
                  label: 'Save and approve',
                  kind: ButtonKind.primary,
                  expand: true,
                  onPressed: _saving
                      ? null
                      : () => _act(
                          invoice,
                          queue,
                          (api) => api.review(invoice.id, _fields(invoice), approve: true),
                        ),
                ),
                const SizedBox(height: 10),
                LineButton(
                  label: 'Mark as duplicate',
                  onPressed: _saving || invoice.status == InvoiceStatus.duplicate
                      ? null
                      : () => _act(invoice, queue, (api) => api.markDuplicate(invoice.id)),
                ),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Nothing reaches the Excel until you approve it.',
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

  Widget _fieldGrid(Set<String> doubtful) {
    Widget field(String name, {String? label}) => _Field(
      label: label ?? fieldLabels[name]!,
      controller: _controllers[name]!,
      doubt: doubtful.contains(name),
    );
    Widget pair(Widget left, Widget right) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
    return Column(
      children: [
        field('supplier'),
        pair(field('invoice_number'), field('issue_date', label: 'Date (YYYY-MM-DD)')),
        pair(field('net_amount'), field('vat_rate')),
        pair(field('vat_amount'), field('total')),
        pair(field('currency'), const SizedBox()),
      ],
    );
  }
}

/// A labelled field on ink. A doubtful one has a gold label and outline.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, required this.doubt});

  final String label;
  final TextEditingController controller;
  final bool doubt;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.panelLabel(
            size: 9,
            color: doubt ? AppColors.accent : AppColors.onInkMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppColors.inkDeep,
            borderRadius: BorderRadius.circular(12),
            border: doubt ? Border.all(color: AppColors.accent, width: 1.5) : null,
          ),
          child: TextField(
            controller: controller,
            cursorColor: AppColors.accent,
            style: AppText.body(
              color: AppColors.onInk,
              size: 12,
            ).copyWith(fontWeight: FontWeight.w500, height: 1.2),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              semanticCounterText: label,
            ),
          ),
        ),
      ],
    ),
  );
}
