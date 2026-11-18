import 'package:material_ui/material_ui.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';

/// A white card with the large radius of the design.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.radius = AppSizes.rCard});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(radius)),
    child: child,
  );
}

/// A figure with its label and a gold note, as in the top card of the Overview screen.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.figure,
    this.note,
    this.ink = false,
  });

  final String label;
  final String figure;
  final String? note;
  final bool ink;

  @override
  Widget build(BuildContext context) {
    final color = ink ? AppColors.onInk : AppColors.text;
    return Container(
      height: 132,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: ink ? AppColors.ink : AppColors.field,
        borderRadius: BorderRadius.circular(AppSizes.rPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(color: color),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              figure,
              style: AppText.figure(
                color: ink ? AppColors.onInk : AppColors.textSoft,
                size: AppSizes.fsStat,
              ),
            ),
          ),
          Text(
            (note ?? '').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(color: AppColors.accent, size: 10),
          ),
        ],
      ),
    );
  }
}

/// The page title row: a title on the left and actions on the right.
class ListHead extends StatelessWidget {
  const ListHead({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppSizes.hGhost,
    child: Row(
      children: [
        Expanded(child: Text(title.toUpperCase(), style: AppText.title())),
        for (final action in actions) ...[const SizedBox(width: 14), action],
      ],
    ),
  );
}

/// A label over a figure, on the ink panel.
class PanelFigure extends StatelessWidget {
  const PanelFigure({
    super.key,
    required this.label,
    required this.figure,
    this.color = AppColors.onInk,
    this.end = false,
  });

  final String label;
  final String figure;
  final Color color;
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
        style: AppText.figure(color: color).copyWith(fontWeight: FontWeight.w500),
      ),
    ],
  );
}
