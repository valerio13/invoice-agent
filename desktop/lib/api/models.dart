// The JSON the backend returns, as Dart classes. Amounts arrive as decimal strings and are kept
// as strings: the app only shows them, it never adds money up.

double _amount(Object? value) => double.parse(value as String);

class Health {
  const Health({required this.demoMode});

  factory Health.fromJson(Map<String, dynamic> json) => Health(demoMode: json['demo_mode'] as bool);

  final bool demoMode;
}

class MonthSpend {
  const MonthSpend({required this.month, required this.total});

  factory MonthSpend.fromJson(Map<String, dynamic> json) =>
      MonthSpend(month: DateTime.parse(json['month'] as String), total: _amount(json['total']));

  final DateTime month;
  final double total;
}

class SupplierSpend {
  const SupplierSpend({required this.supplier, required this.total});

  factory SupplierSpend.fromJson(Map<String, dynamic> json) =>
      SupplierSpend(supplier: json['supplier'] as String, total: _amount(json['total']));

  final String supplier;
  final double total;
}

class Metrics {
  const Metrics({
    required this.invoices,
    required this.ok,
    required this.needsReview,
    required this.duplicates,
    required this.invoicesThisMonth,
    required this.spendThisMonth,
    required this.spendLastMonth,
    required this.spendByMonth,
    required this.suppliers,
    required this.topSuppliers,
  });

  factory Metrics.fromJson(Map<String, dynamic> json) => Metrics(
    invoices: json['invoices'] as int,
    ok: json['ok'] as int,
    needsReview: json['needs_review'] as int,
    duplicates: json['duplicates'] as int,
    invoicesThisMonth: json['invoices_this_month'] as int,
    spendThisMonth: _amount(json['spend_this_month']),
    spendLastMonth: _amount(json['spend_last_month']),
    spendByMonth: [
      for (final item in json['spend_by_month'] as List)
        MonthSpend.fromJson(item as Map<String, dynamic>),
    ],
    suppliers: json['suppliers'] as int,
    topSuppliers: [
      for (final item in json['top_suppliers'] as List)
        SupplierSpend.fromJson(item as Map<String, dynamic>),
    ],
  );

  final int invoices;
  final int ok;
  final int needsReview;
  final int duplicates;
  final int invoicesThisMonth;
  final double spendThisMonth;
  final double spendLastMonth;
  final List<MonthSpend> spendByMonth;
  final int suppliers;
  final List<SupplierSpend> topSuppliers;
}

class IngestResult {
  const IngestResult({required this.stored, required this.skipped, required this.failed});

  factory IngestResult.fromJson(Map<String, dynamic> json) => IngestResult(
    stored: json['stored'] as int,
    skipped: json['skipped'] as int,
    failed: [for (final name in json['failed'] as List) name as String],
  );

  final int stored;
  final int skipped;
  final List<String> failed;
}
