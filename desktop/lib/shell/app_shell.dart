import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../screens/invoices_screen.dart';
import '../screens/overview_screen.dart';
import '../screens/placeholder_screen.dart';
import '../theme/tokens.dart';
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
  const AppShell({super.key, required this.state});

  final AppState state;

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

  void _select(int index) => setState(() => _selected = index);

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
                        child: Padding(padding: EdgeInsets.all(margin), child: _window()),
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
    ),
    2 => PlaceholderScreen(
      title: _entries[_selected].label,
      note: _reviewId == null ? null : 'Invoice $_reviewId will open here.',
    ),
    _ => PlaceholderScreen(title: _entries[_selected].label),
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
