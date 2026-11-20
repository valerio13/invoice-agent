import 'package:material_ui/material_ui.dart';

import 'package:desktop_drop/desktop_drop.dart';

import '../api/models.dart';
import '../app_state.dart';
import '../files.dart';
import '../screens/export_screen.dart';
import '../screens/invoices_screen.dart';
import '../screens/overview_screen.dart';
import '../screens/review_screen.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'drop_zone.dart';
import 'reading_scene.dart';
import 'sidebar.dart';

/// Smallest size the layout is drawn at. A smaller window scrolls.
const minCanvas = Size(1180, 820);

const _entries = [
  NavEntry('Overview', Icons.home_outlined),
  NavEntry('Invoices', Icons.receipt_outlined),
  NavEntry('Review', Icons.check_circle_outline_rounded),
  NavEntry('Export', Icons.download_rounded),
];

/// The page background, the app window, the sidebar and the selected screen.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.state,
    this.files = const FileAccess(),
    this.sceneTiming = const SceneTiming(),
  });

  final AppState state;
  final FileAccess files;
  final SceneTiming sceneTiming;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;
  // The invoice the Review screen opens with.
  int? _reviewId;

  @override
  void initState() {
    super.initState();
    widget.state.refresh();
  }

  void _select(int index) => setState(() {
    _selected = index;
    // The sidebar opens Review on the first invoice waiting, not the last one picked.
    if (index == 2) _reviewId = null;
  });

  bool _reading = false;

  Future<void> _pickFiles() async {
    final uploads = await widget.files.pickInvoices();
    await _addFiles(uploads);
  }

  Future<void> _dropFiles(List<DropItem> items) async {
    final List<InvoiceUpload> uploads;
    try {
      uploads = await widget.files.readDropped(items);
    } on Exception catch (e) {
      _notify('The dropped files could not be read: $e');
      return;
    }
    await _addFiles(uploads);
  }

  // What the reading scene shows: how many files, then the invoices just read.
  int _sceneFiles = 0;
  List<Invoice> _justRead = const [];

  Future<void> _addFiles(List<InvoiceUpload> uploads) async {
    if (uploads.isEmpty || _reading) return;
    final timing = widget.sceneTiming;
    final before = {for (final invoice in widget.state.invoices) invoice.id};
    final names = {for (final upload in uploads) upload.name};
    setState(() {
      _reading = true;
      _sceneFiles = uploads.length;
      _justRead = const [];
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final started = DateTime.now();
    final result = await widget.state.addFiles(uploads);
    // A fast answer still lets the robot read for a moment, so the scene does not flash.
    final left = timing.minReading - DateTime.now().difference(started);
    if (left > Duration.zero) await Future<void>.delayed(left);
    if (!mounted) return;
    final read = [
      for (final invoice in widget.state.invoices)
        if (!before.contains(invoice.id) && names.contains(invoice.fileName)) invoice,
    ];
    if (read.isNotEmpty) {
      setState(() => _justRead = read);
      await Future<void>.delayed(timing.hold);
      if (!mounted) return;
    }
    setState(() => _reading = false);
    _notify(
      result == null ? widget.state.error ?? 'The files were not read.' : uploadNotice(result),
    );
  }

  void _notify(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 560,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.rRow)),
        content: Text(message, style: AppText.body(color: AppColors.onInk, size: 12)),
      ),
    );
  }

  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _PageBackground(),
          LayoutBuilder(
            builder: (context, constraints) {
              // Below the minimum size the layout keeps its size and scroll bars appear.
              final width = constraints.maxWidth < minCanvas.width
                  ? minCanvas.width
                  : constraints.maxWidth;
              final height = constraints.maxHeight < minCanvas.height
                  ? minCanvas.height
                  : constraints.maxHeight;
              // The margin around the window shrinks on small screens, as in the mockup on large ones.
              final margin = height >= 1000 && width >= 1336 ? 48.0 : 24.0;
              return Scrollbar(
                controller: _vertical,
                thumbVisibility: height > constraints.maxHeight,
                child: SingleChildScrollView(
                  controller: _vertical,
                  child: Scrollbar(
                    controller: _horizontal,
                    thumbVisibility: width > constraints.maxWidth,
                    notificationPredicate: (notification) => notification.depth == 0,
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: Padding(
                          padding: EdgeInsets.all(margin),
                          child: DropZone(
                            enabled: !_reading,
                            onDrop: _dropFiles,
                            child: Stack(
                              children: [
                                _window(),
                                if (_reading)
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.horizontal(
                                        left: Radius.circular(AppSizes.rWindow),
                                        right: Radius.circular(AppSizes.rPanel),
                                      ),
                                      child: ReadingScene(
                                        files: _sceneFiles,
                                        read: _justRead.firstOrNull,
                                        moreRead: _justRead.isEmpty ? 0 : _justRead.length - 1,
                                        timing: widget.sceneTiming,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _window() => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.horizontal(
        left: Radius.circular(AppSizes.rWindow),
        right: Radius.circular(AppSizes.rPanel),
      ),
      boxShadow: AppShadows.window,
    ),
    child: ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Sidebar(
            entries: _entries,
            selected: _selected,
            onSelect: _select,
            subtitle: widget.state.demoMode ? 'demo workspace' : 'workspace',
            suppliers: widget.state.metrics?.suppliers ?? 0,
          ),
          const SizedBox(width: 38),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 40, top: 34, bottom: 32),
              child: _screen(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _screen() => switch (_selected) {
    0 => OverviewScreen(
      state: widget.state,
      onReview: () => _select(2),
      onExport: () => _select(3),
    ),
    1 => InvoicesScreen(
      state: widget.state,
      onReview: (id) => setState(() {
        _reviewId = id;
        _selected = 2;
      }),
      onExport: () => _select(3),
      onAddFiles: _reading ? null : _pickFiles,
    ),
    // A new key per invoice, so opening another one from Invoices starts the screen afresh.
    2 => ReviewScreen(key: ValueKey(_reviewId), state: widget.state, initialId: _reviewId),
    _ => ExportScreen(state: widget.state, files: widget.files, onReview: () => _select(2)),
  };
}

class _PageBackground extends StatelessWidget {
  const _PageBackground();

  @override
  Widget build(BuildContext context) => const Positioned.fill(
    child: ColoredBox(
      color: AppColors.page,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(left: -320, bottom: -280, child: _Blob(760)),
          Positioned(right: -460, top: -600, child: _Blob(1100)),
        ],
      ),
    ),
  );
}

class _Blob extends StatelessWidget {
  const _Blob(this.size);

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(color: AppColors.pageLight, shape: BoxShape.circle),
  );
}
