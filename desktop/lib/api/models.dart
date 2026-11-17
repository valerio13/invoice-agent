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

enum InvoiceStatus {
  ok('ok', 'OK'),
  needsReview('needs_review', 'To review'),
  duplicate('duplicate', 'Duplicate');

  const InvoiceStatus(this.json, this.label);

  final String json;
  final String label;

  static InvoiceStatus fromJson(String value) =>
      values.firstWhere((status) => status.json == value);
}

class Invoice {
  const Invoice({
    required this.id,
    required this.fileName,
    required this.supplier,
    required this.invoiceNumber,
    required this.issueDate,
    required this.netAmount,
    required this.vatRate,
    required this.vatAmount,
    required this.total,
    required this.currency,
    required this.confidence,
    required this.status,
    required this.reviewReasons,
    required this.approved,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] as int,
    fileName: json['file_name'] as String,
    supplier: json['supplier'] as String,
    invoiceNumber: json['invoice_number'] as String,
    issueDate: DateTime.parse(json['issue_date'] as String),
    netAmount: _amount(json['net_amount']),
    vatRate: _amount(json['vat_rate']),
    vatAmount: _amount(json['vat_amount']),
    total: _amount(json['total']),
    currency: json['currency'] as String,
    confidence: (json['confidence'] as num).toDouble(),
    status: InvoiceStatus.fromJson(json['status'] as String),
    reviewReasons: [for (final reason in json['review_reasons'] as List) reason as String],
    approved: json['approved'] as bool,
  );

  final int id;
  final String fileName;
  final String supplier;
  final String invoiceNumber;
  final DateTime issueDate;
  final double netAmount;
  final double vatRate;
  final double vatAmount;
  final double total;
  final String currency;
  final double confidence;
  final InvoiceStatus status;
  final List<String> reviewReasons;
  final bool approved;

  bool get isPdf => fileName.toLowerCase().endsWith('.pdf');
}
