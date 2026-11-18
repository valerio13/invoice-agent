import 'package:desktop_drop/desktop_drop.dart';
import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';

/// Takes files dropped anywhere on [child], and covers it with a hint while they hover.
class DropZone extends StatefulWidget {
  const DropZone({super.key, required this.child, required this.onDrop, this.enabled = true});

  final Widget child;
  final ValueChanged<List<DropItem>> onDrop;
  final bool enabled;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) => DropTarget(
    enable: widget.enabled,
    onDragEntered: (_) => setState(() => _hovering = true),
    onDragExited: (_) => setState(() => _hovering = false),
    onDragDone: (details) {
      setState(() => _hovering = false);
      if (details.files.isNotEmpty) widget.onDrop(details.files);
    },
    child: Stack(
      children: [
        widget.child,
        if (_hovering)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppSizes.rWindow),
                    right: Radius.circular(AppSizes.rPanel),
                  ),
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload_file_rounded, size: 48, color: AppColors.accent),
                    const SizedBox(height: 18),
                    Text(
                      'DROP TO READ THE INVOICES',
                      style: AppText.label(color: AppColors.onInk, size: AppSizes.fsTitle),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'PDF, PNG or JPG, up to 10 MB each. A folder adds the files inside it.',
                      style: AppText.body(color: AppColors.onInkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// One sentence on what the backend did with the files.
String uploadNotice(IngestResult result) {
  final parts = <String>[
    switch (result.stored) {
      0 => 'No new invoices',
      1 => '1 new invoice read',
      final n => '$n new invoices read',
    },
    if (result.skipped > 0) '${result.skipped} already stored',
    if (result.failed.isNotEmpty) 'Could not read ${result.failed.join(', ')}',
    if (result.rejected.isNotEmpty)
      'Left out ${result.rejected.join(', ')} (only PDF, PNG or JPG up to 10 MB)',
  ];
  return '${parts.join('. ')}.';
}
