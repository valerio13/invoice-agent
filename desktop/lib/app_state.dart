import 'package:material_ui/material_ui.dart';

import 'api/api_client.dart';
import 'api/models.dart';

/// What every screen shares: whether the backend answers, demo mode, and the figures.
class AppState extends ChangeNotifier {
  AppState(this.api);

  final ApiClient api;

  Health? health;
  Metrics? metrics;
  List<Invoice> invoices = const [];
  ExportSummary? exportSummary;
  String? error;
  bool busy = false;

  bool get demoMode => health?.demoMode ?? false;

  /// Ask the backend again. Errors are kept in [error] for the screens to show.
  Future<void> refresh() => _run(() async {
    health = await api.health();
    await _reload();
  });

  /// Replace every invoice with the demo set, then refresh.
  Future<void> loadDemo() => _run(() async {
    await api.loadDemo();
    await _reload();
  });

  /// Reload the figures and the list after a change made on a screen.
  Future<void> reload() => _run(_reload);

  /// Send files to be read, then refresh. Null when it failed: the reason is in [error].
  Future<IngestResult?> addFiles(List<InvoiceUpload> files) async {
    IngestResult? result;
    await _run(() async {
      result = await api.upload(files);
      await _reload();
    });
    return result;
  }

  Future<void> _reload() async {
    metrics = await api.metrics();
    invoices = await api.invoices();
    exportSummary = await api.exportSummary();
  }

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
