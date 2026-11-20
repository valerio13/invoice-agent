import 'package:material_ui/material_ui.dart';

import 'api/api_client.dart';
import 'app_state.dart';
import 'files.dart';
import 'shell/app_shell.dart';
import 'shell/reading_scene.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(InvoiceAgentApp(state: AppState(ApiClient())));
}

class InvoiceAgentApp extends StatelessWidget {
  const InvoiceAgentApp({
    super.key,
    required this.state,
    this.files = const FileAccess(),
    this.sceneTiming = const SceneTiming(),
  });

  final AppState state;
  final FileAccess files;
  final SceneTiming sceneTiming;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Invoice agent',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: AppShell(state: state, files: files, sceneTiming: sceneTiming),
  );
}
