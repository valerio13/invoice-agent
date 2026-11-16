import 'package:material_ui/material_ui.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';

class NavEntry {
  const NavEntry(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The dark sidebar: the brand, the navigation and the top suppliers.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.entries,
    required this.selected,
    required this.onSelect,
    required this.subtitle,
    required this.suppliers,
  });

  final List<NavEntry> entries;
  final int selected;
  final ValueChanged<int> onSelect;
  final String subtitle;
  final int suppliers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.wSidebar,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppSizes.rWindow),
      ),
      // A column with flexible gaps, so the parts never overlap when the window is short.
      child: Column(
        children: [
          const Spacer(flex: 6),
          _Brand(subtitle: subtitle),
          const Spacer(flex: 5),
          for (final (index, entry) in entries.indexed)
            _NavItem(entry: entry, active: index == selected, onTap: () => onSelect(index)),
          const Spacer(flex: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 40),
              child: SizedBox(
                height: 82,
                child: suppliers > 0 ? _SupplierStack(suppliers: suppliers) : null,
              ),
            ),
          ),
          const Spacer(flex: 2),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 34),
              child: CustomPaint(size: Size(204, 132), painter: _SideArt()),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const CustomPaint(size: Size(100, 100), painter: _BrandRing()),
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_rounded, size: 46, color: AppColors.onInk),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text('INVOICE AGENT', style: AppText.brand()),
      const SizedBox(height: 9),
      Text(subtitle, style: AppText.body(color: AppColors.onInkMuted)),
    ],
  );
}

/// A gold ring, open on one side, around the brand disc.
class _BrandRing extends CustomPainter {
  const _BrandRing();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Offset.zero & size;
    // Three quarters of a circle, the gap turned like the mockup.
    canvas.drawArc(rect.deflate(1), -0.6 - 3.1416 / 2 * 3, 3.1416 * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.entry, required this.active, required this.onTap});

  final NavEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: AppSizes.hNav,
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.only(left: 23),
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(29)),
          ),
          child: Row(
            children: [
              Icon(entry.icon, size: 22, color: AppColors.accent),
              const SizedBox(width: 23),
              Text(
                entry.label.toUpperCase(),
                style: AppText.nav(active ? AppColors.text : AppColors.onInk),
              ),
            ],
          ),
        ),
      ),
    );
    if (!active) return item;
    // Two inverted corners join the active item to the content area.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        item,
        const Positioned(
          right: 0,
          top: -26,
          child: CustomPaint(size: Size(26, 26), painter: _InvertedCorner(top: true)),
        ),
        const Positioned(
          right: 0,
          bottom: -26,
          child: CustomPaint(size: Size(26, 26), painter: _InvertedCorner(top: false)),
        ),
      ],
    );
  }
}

class _InvertedCorner extends CustomPainter {
  const _InvertedCorner({required this.top});

  final bool top;

  @override
  void paint(Canvas canvas, Size size) {
    final square = Path()..addRect(Offset.zero & size);
    final center = top ? Offset.zero : Offset(0, size.height);
    final circle = Path()..addOval(Rect.fromCircle(center: center, radius: size.width));
    canvas.drawPath(
      Path.combine(PathOperation.difference, square, circle),
      Paint()..color = AppColors.surface,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SupplierStack extends StatelessWidget {
  const _SupplierStack({required this.suppliers});

  final int suppliers;

  static const _icons = [
    (Icons.landscape_rounded, AppColors.card, AppColors.accent),
    (Icons.cloud_rounded, AppColors.surface, AppColors.ink),
    (Icons.local_shipping_rounded, AppColors.inkDot, AppColors.onInk),
    (Icons.edit_rounded, AppColors.card, AppColors.accent),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = suppliers < _icons.length ? suppliers : _icons.length;
    final more = suppliers - shown;
    final discs = <Widget>[
      for (final (icon, background, color) in _icons.take(shown))
        _disc(background, Icon(icon, size: 22, color: color)),
      if (more > 0)
        _disc(
          AppColors.accent,
          Text('+$more', style: AppText.label(color: AppColors.onAccent, size: 11)),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOP SUPPLIERS',
          style: AppText.panelLabel(color: AppColors.accent, size: AppSizes.fsBody),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 42,
          width: 42.0 + 30 * (discs.length - 1),
          child: Stack(
            children: [
              for (final (index, disc) in discs.indexed)
                Positioned(left: index * 30.0, child: disc),
            ],
          ),
        ),
      ],
    );
  }

  Widget _disc(Color background, Widget child) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.ink, width: 2),
    ),
    child: child,
  );
}

/// Dotted bars with a gold line over them, at the foot of the sidebar.
class _SideArt extends CustomPainter {
  const _SideArt();

  static const _bars = [
    (6.0, 84.0),
    (40.0, 60.0),
    (74.0, 78.0),
    (108.0, 42.0),
    (142.0, 54.0),
    (176.0, 18.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = AppColors.inkDot;
    for (final (x, top) in _bars) {
      for (var y = top + 3; y < size.height - 3; y += 6) {
        for (var dx = 3.0; dx < 24; dx += 6) {
          canvas.drawCircle(Offset(x + dx, y), 1.25, dot);
        }
      }
    }
    final gold = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final line = Path()
      ..moveTo(18, 84)
      ..quadraticBezierTo(34, 44, 52, 60)
      ..quadraticBezierTo(82, 20, 120, 42)
      ..quadraticBezierTo(156, -4, 188, 18);
    canvas.drawPath(line, gold);
    final fill = Paint()..color = AppColors.accent;
    for (final point in const [Offset(18, 84), Offset(52, 60), Offset(120, 42), Offset(188, 18)]) {
      canvas.drawCircle(point, 3.2, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
