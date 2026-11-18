import 'package:material_ui/material_ui.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';

enum ButtonKind { primary, ghost, small }

/// The pill buttons of the design: gold primary, white ghost and small gold.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = ButtonKind.ghost,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final IconData? icon;

  /// Fill the width it is given, with the label centred.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (height, padding, fontSize, background, foreground) = switch (kind) {
      ButtonKind.primary => (
        AppSizes.hField,
        28.0,
        AppSizes.fsLabel,
        AppColors.accent,
        AppColors.onAccent,
      ),
      ButtonKind.ghost => (AppSizes.hGhost, 28.0, 10.0, AppColors.card, AppColors.text),
      ButtonKind.small => (AppSizes.hSmall, 16.0, 9.0, AppColors.accent, AppColors.onAccent),
    };
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.button(foreground, fontSize),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 10),
                    Icon(icon, size: 14, color: foreground),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The outlined button on ink, for the second action.
class LineButton extends StatelessWidget {
  const LineButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? 0.5 : 1,
    child: Material(
      color: Colors.transparent,
      shape: const StadiumBorder(side: BorderSide(color: Color(0x59FFFFFF), width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: 34,
          child: Center(
            child: Text(label.toUpperCase(), style: AppText.button(AppColors.onInk, 9.5)),
          ),
        ),
      ),
    ),
  );
}
