import 'package:material_ui/material_ui.dart';

import '../theme/text.dart';
import '../widgets/cards.dart';

/// A screen that is not built yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListHead(title: title),
      const SizedBox(height: 30),
      Expanded(
        child: AppCard(
          radius: 20,
          child: Center(child: Text('This screen comes in the next step.', style: AppText.body())),
        ),
      ),
    ],
  );
}
