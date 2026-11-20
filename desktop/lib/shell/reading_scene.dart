import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';

/// How long the scene stays up. Tests use [SceneTiming.instant], so nothing waits or loops.
class SceneTiming {
  const SceneTiming({
    this.minReading = const Duration(milliseconds: 2200),
    this.hold = const Duration(milliseconds: 1800),
    this.animate = true,
  });

  /// Shortest time the robot reads, so a fast answer does not flash the scene.
  final Duration minReading;

  /// How long what was read stays on screen.
  final Duration hold;
  final bool animate;

  static const instant = SceneTiming(
    minReading: Duration.zero,
    hold: Duration.zero,
    animate: false,
  );
}

const _glow = Color(0xFF4FD8E0);
const _glowText = Color(0xFF1E8F98);
const _shell = Color(0xFFF6F9FA);
const _shellLine = Color(0xFFB9C9CC);
const _shellShade = Color(0xFFDBE6E8);
const _visor = Color(0xFF1C2A37);

/// The robot that reads the invoices while they are sent, then what it read from the first one.
class ReadingScene extends StatefulWidget {
  const ReadingScene({
    super.key,
    required this.files,
    this.read,
    this.moreRead = 0,
    this.timing = const SceneTiming(),
  });

  /// How many files are being read.
  final int files;

  /// The first invoice read, once the backend answered. Null while it reads.
  final Invoice? read;

  /// How many more invoices were read besides [read].
  final int moreRead;
  final SceneTiming timing;

  @override
  State<ReadingScene> createState() => _ReadingSceneState();
}

class _ReadingSceneState extends State<ReadingScene> with TickerProviderStateMixin {
  // Bobbing, blinking and the glow: one slow loop.
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  // The scan line, up and down the sheet.
  late final _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  // The field bars, filling one after another; again and again until the answer comes.
  late final _fill = AnimationController(
    vsync: this,
    duration: widget.timing.minReading > const Duration(seconds: 1)
        ? widget.timing.minReading
        : const Duration(seconds: 1),
  );
  late final _arrive = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.timing.animate) {
      _loop.repeat();
      _fill.repeat();
      _scan.repeat(reverse: true);
      _arrive.forward();
    } else {
      _arrive.value = 1;
    }
    if (widget.read != null) _showRead();
  }

  @override
  void didUpdateWidget(ReadingScene old) {
    super.didUpdateWidget(old);
    if (old.read == null && widget.read != null) _showRead();
  }

  void _showRead() {
    _scan.stop();
    if (widget.timing.animate) {
      // The bars finish quickly once the answer is in.
      _fill.animateTo(1, duration: const Duration(milliseconds: 700));
      _reveal.forward(from: 0);
    } else {
      _fill.value = 1;
      _reveal.value = 1;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _fill.dispose();
    _scan.dispose();
    _arrive.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surface.withValues(alpha: 0.96),
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 760,
          height: 340,
          child: Row(
            children: [
              SizedBox(
                width: 480,
                height: 340,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: RobotPainter(
                      loop: _loop,
                      scan: _scan,
                      arrive: _arrive,
                      reveal: _reveal,
                      reading: widget.read == null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: _fields()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _fields() {
    final invoice = widget.read;
    final status = invoice == null
        ? 'AI IS READING…'
        : 'READ BY AI · ${(invoice.confidence * 100).round()}% SURE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(status, style: AppText.label(color: _glowText, size: 12)),
        const SizedBox(height: 6),
        Text(
          invoice == null
              ? '${widget.files} ${widget.files == 1 ? 'file' : 'files'}'
              : widget.moreRead > 0
              ? '+${widget.moreRead} more read'
              : invoice.fileName,
          style: AppText.body(color: AppColors.textMuted, size: 11),
        ),
        const SizedBox(height: 18),
        for (final (index, label) in const ['SUPPLIER', 'NUMBER', 'DATE', 'TOTAL'].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _FieldRow(
              label: label,
              // One after another, as if the robot found them in turn.
              progress: CurvedAnimation(
                parent: _fill,
                curve: Interval(index * 0.2, index * 0.2 + 0.4, curve: Curves.easeInOut),
              ),
            ),
          ),
      ],
    );
  }
}

/// A field the robot is looking for: its name and a bar that fills as it is found.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.progress});

  final String label;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.label(color: AppColors.textMuted, size: 10.5)),
      const SizedBox(height: 8),
      AnimatedBuilder(
        animation: progress,
        builder: (context, _) => Row(
          children: [
            Container(
              width: 200,
              height: 10,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: AppColors.page,
                borderRadius: BorderRadius.circular(5),
              ),
              child: FractionallySizedBox(
                widthFactor: progress.value,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(color: _glow, borderRadius: BorderRadius.circular(5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              child: progress.value >= 1
                  ? const Icon(Icons.check_rounded, size: 16, color: _glowText)
                  : null,
            ),
          ],
        ),
      ),
    ],
  );
}

/// The robot holding the sheet, drawn in a 480 x 340 box.
class RobotPainter extends CustomPainter {
  RobotPainter({
    required this.loop,
    required this.scan,
    required this.arrive,
    required this.reveal,
    required this.reading,
  }) : super(repaint: Listenable.merge([loop, scan, arrive, reveal]));

  final Animation<double> loop;
  final Animation<double> scan;
  final Animation<double> arrive;
  final Animation<double> reveal;
  final bool reading;

  static final _line = Paint()
    ..color = _shellLine
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _fill = Paint()..color = _shell;

  @override
  void paint(Canvas canvas, Size size) {
    final wave = math.sin(loop.value * math.pi * 2);
    final bob = -2.5 - 2.5 * wave;

    // The shadow on the floor shrinks as the robot rises.
    canvas.save();
    canvas.translate(210, 316);
    canvas.scale(1 - 0.06 * (1 + wave) / 2, 1);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 124, height: 14),
      Paint()..color = AppColors.ink.withValues(alpha: 0.16),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(0, bob);

    // Left arm, hanging and swaying a little.
    canvas.save();
    canvas.translate(166, 180);
    canvas.rotate(0.035 * (1 + wave));
    canvas.translate(-166, -180);
    _arm(canvas, const Offset(166, 182), const Offset(140, 222), const Offset(150, 262));
    _circle(canvas, const Offset(151, 266), 11);
    canvas.restore();

    // Right arm, reaching for the sheet. The hand is drawn over the sheet, at the end.
    _arm(canvas, const Offset(254, 182), const Offset(292, 238), const Offset(322, 198));

    _body(canvas);
    _head(canvas);
    _sheet(canvas);
    _circle(canvas, const Offset(324, 196), 12);

    canvas.restore();
  }

  void _arm(Canvas canvas, Offset from, Offset control, Offset to) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = _shellLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 21
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _shell
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.round,
    );
  }

  void _circle(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, _fill);
    canvas.drawCircle(center, radius, _line);
  }

  void _body(Canvas canvas) {
    final torso = Path()
      ..moveTo(172, 160)
      ..quadraticBezierTo(210, 152, 248, 160)
      ..quadraticBezierTo(270, 164, 264, 192)
      ..lineTo(248, 248)
      ..quadraticBezierTo(210, 286, 172, 248)
      ..lineTo(156, 192)
      ..quadraticBezierTo(150, 164, 172, 160)
      ..close();
    canvas.drawPath(torso, _fill);
    canvas.drawPath(torso, _line);
    // A softer side, so the shell reads as round.
    canvas.drawPath(
      Path()
        ..moveTo(164, 172)
        ..quadraticBezierTo(172, 166, 182, 166)
        ..lineTo(180, 236)
        ..quadraticBezierTo(170, 220, 164, 172)
        ..close(),
      Paint()..color = const Color(0xFFE6EEF0),
    );
    canvas.drawPath(
      Path()
        ..moveTo(176, 244)
        ..quadraticBezierTo(210, 262, 244, 244),
      Paint()
        ..color = _shellShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // The core on the chest glows harder while it reads.
    const core = Offset(210, 200);
    final pulse = 0.5 + 0.5 * math.sin(loop.value * math.pi * 4);
    canvas.drawCircle(
      core,
      26,
      Paint()
        ..color = _glow.withValues(alpha: 0.18 + 0.2 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(core, 19, Paint()..color = _shellShade);
    canvas.drawCircle(
      core,
      19,
      Paint()
        ..color = _shellLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(core, 12, Paint()..color = _glow.withValues(alpha: 0.55 + 0.45 * pulse));
    canvas.drawCircle(core - const Offset(4, 4), 3.5, Paint()..color = const Color(0xCCFFFFFF));

    canvas.drawRRect(
      RRect.fromLTRBR(197, 146, 223, 162, const Radius.circular(6)),
      Paint()..color = const Color(0xFFCFDDE0),
    );
  }

  void _head(Canvas canvas) {
    final head = RRect.fromLTRBR(142, 40, 278, 152, const Radius.circular(54));
    canvas.drawRRect(head, _fill);
    canvas.drawRRect(head, _line);
    canvas.drawPath(
      Path()
        ..moveTo(160, 70)
        ..quadraticBezierTo(180, 46, 214, 46),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(210, 56), 4, Paint()..color = const Color(0xFF24323F));

    canvas.drawRRect(
      RRect.fromLTRBR(156, 66, 264, 138, const Radius.circular(34)),
      Paint()..color = _visor,
    );
    canvas.drawPath(
      Path()
        ..moveTo(170, 80)
        ..quadraticBezierTo(184, 72, 200, 72),
      Paint()
        ..color = const Color(0xFF3A4B5B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Eyes on the sheet while reading, back to the front once done.
    final look = reading ? 5.0 : 5.0 * (1 - reveal.value);
    // A blink at the same moment of each loop.
    final phase = loop.value;
    final blink = phase > 0.44 && phase < 0.5 ? 1 - math.sin((phase - 0.44) / 0.06 * math.pi) : 1.0;
    final eyeHeight = 24 * (0.12 + 0.88 * blink);
    for (final x in const [188.0, 232.0]) {
      final center = Offset(x + look, 98);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 30, height: 34),
        Paint()
          ..color = _glow.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 18, height: eyeHeight),
        Paint()..color = _glow,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(200 + look, 121)
        ..quadraticBezierTo(210 + look, 128, 220 + look, 121),
      Paint()
        ..color = _glow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _sheet(Canvas canvas) {
    final t = Curves.easeOutCubic.transform(arrive.value);
    canvas.save();
    // It flies in from the right, turned, and settles in the hand.
    canvas.translate(260 * (1 - t), 40 * (1 - t));
    canvas.translate(386, 155);
    canvas.rotate(0.21 * (1 - t));
    canvas.translate(-386, -155);
    canvas.saveLayer(
      const Rect.fromLTWH(300, 50, 180, 210),
      Paint()..color = Colors.white.withValues(alpha: t),
    );

    final sheet = RRect.fromLTRBR(322, 70, 450, 240, const Radius.circular(6));
    canvas.drawRRect(sheet, Paint()..color = Colors.white);
    canvas.drawRRect(
      sheet,
      Paint()
        ..color = const Color(0xFF9FB3B2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawRect(const Rect.fromLTWH(334, 84, 6, 22), Paint()..color = const Color(0xFF1E6E78));
    void bar(double x, double y, double w, double h, Color color) => canvas.drawRRect(
      RRect.fromLTRBR(x, y, x + w, y + h, const Radius.circular(3)),
      Paint()..color = color,
    );
    bar(346, 86, 60, 7, AppColors.ink);
    bar(346, 98, 40, 5, const Color(0xFFB8C7C6));
    bar(334, 122, 70, 5, const Color(0xFFB8C7C6));
    bar(334, 134, 56, 5, const Color(0xFFB8C7C6));
    bar(334, 156, 104, 5, const Color(0xFFD5DFDE));
    bar(334, 168, 104, 5, const Color(0xFFD5DFDE));
    bar(394, 194, 44, 6, const Color(0xFFB8C7C6));
    bar(384, 208, 54, 9, AppColors.ink);

    if (reading) {
      final y = 76 + 158 * Curves.easeInOut.transform(scan.value);
      canvas.drawRRect(
        RRect.fromLTRBR(318, y - 4, 454, y + 4, const Radius.circular(4)),
        Paint()
          ..color = _glow.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawRRect(
        RRect.fromLTRBR(318, y - 2, 454, y + 2, const Radius.circular(2)),
        Paint()..color = _glow,
      );
    } else {
      // The gold check: this one is read.
      final done = Curves.easeOutBack.transform(reveal.value.clamp(0, 0.25) / 0.25);
      canvas.drawCircle(const Offset(444, 76), 15 * done, Paint()..color = AppColors.accent);
      if (done > 0.6) {
        canvas.drawPath(
          Path()
            ..moveTo(437, 76)
            ..lineTo(442, 81)
            ..lineTo(451, 71),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(RobotPainter old) => old.reading != reading;
}
