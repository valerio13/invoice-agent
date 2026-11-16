import 'package:material_ui/material_ui.dart';

import 'api/api_client.dart';
import 'api/models.dart';

/// What every screen shares: whether the backend answers, demo mode, and the figures.
class AppState extends ChangeNotifier {
  AppState(this.api);

  final ApiClient api;

  Health? health;
  Metrics? metrics;
  String? error;
  bool busy = false;

  bool get demoMode => health?.demoMode ?? false;

  /// Ask the backend again. Errors are kept in [error] for the screens to show.
  Future<void> refresh() => _run(() async {
    health = await api.health();
    metrics = await api.metrics();
  });

  /// Replace every invoice with the demo set, then refresh.
  Future<void> loadDemo() => _run(() async {
    await api.loadDemo();
    metrics = await api.metrics();
  });

  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    notifyListeners();
    try {
      await action();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
