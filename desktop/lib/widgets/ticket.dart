import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// The row of a ticket list: rounded at the ends of the list, square where rows meet.
BoxDecoration ticketDecoration({required bool first, required bool last, Color? color}) =>
    BoxDecoration(
      color: color ?? AppColors.card,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(first ? AppSizes.rRow : 0),
        bottom: Radius.circular(last ? AppSizes.rRow : 0),
      ),
    );

/// Where two tickets meet, a half circle of the window colour is cut on each side.
class Notched extends StatelessWidget {
  const Notched({super.key, required this.child});

  final Widget child;

  static const _size = 20.0;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      for (final left in [true, false])
        Positioned(
          top: -_size / 2 - 1,
          left: left ? -_size / 2 : null,
          right: left ? null : -_size / 2,
          child: Container(
            width: _size,
            height: _size,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
          ),
        ),
    ],
  );
}
