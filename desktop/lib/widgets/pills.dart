import 'package:material_ui/material_ui.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';

/// A rounded field of the filter card. With [onTap] it behaves as a button.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.child,
    this.icon,
    this.onTap,
    this.center = false,
    this.onClear,
  });

  final Widget child;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool center;

  /// When set, a small cross at the end clears what the pill holds.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.field,
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Container(
        height: AppSizes.hField,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Row(
          mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.text),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: DefaultTextStyle(
                style: AppText.label(size: AppSizes.fsLabel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: child,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Clear',
                child: InkResponse(
                  onTap: onClear,
                  radius: 16,
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.text),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// A pill with a text field inside, for searching.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSizes.hField,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const ShapeDecoration(color: AppColors.field, shape: StadiumBorder()),
    child: Row(
      children: [
        const Icon(Icons.search_rounded, size: 18, color: AppColors.text),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            onChanged: onChanged,
            cursorColor: AppColors.ink,
            style: AppText.label(size: AppSizes.fsLabel),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint.toUpperCase(),
              hintStyle: AppText.label(size: AppSizes.fsLabel),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Segmented control: one option active, dark on the light track, or gold on ink.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.onInk = false,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelect;
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    final height = onInk ? 34.0 : AppSizes.hField;
    return Container(
      height: height,
      padding: EdgeInsets.all(onInk ? 0 : 3),
      decoration: ShapeDecoration(
        color: onInk ? Colors.transparent : AppColors.field,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(value),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: value == selected
                          ? (onInk ? AppColors.accent : AppColors.ink)
                          : Colors.transparent,
                      shape: const StadiumBorder(),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          style: onInk
                              ? AppText.panelLabel()
                              : AppText.label(
                                  size: AppSizes.fsLabel,
                                  color: value == selected ? AppColors.onInk : AppColors.text,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
