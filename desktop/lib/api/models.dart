// The JSON the backend returns, as Dart classes. Amounts arrive as decimal strings and are kept
// as strings: the app only shows them, it never adds money up.

import 'dart:typed_data';

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
  const IngestResult({
    required this.stored,
    required this.skipped,
    required this.failed,
    this.rejected = const [],
  });

  factory IngestResult.fromJson(Map<String, dynamic> json) => IngestResult(
    stored: json['stored'] as int,
    skipped: json['skipped'] as int,
    failed: [for (final name in json['failed'] as List) name as String],
    rejected: [for (final name in json['rejected'] as List? ?? []) name as String],
  );

  /// Invoices stored in this run, duplicates included.
  final int stored;

  /// Documents that were already stored and were left alone.
  final int skipped;

  /// Documents the model could not read.
  final List<String> failed;

  /// Uploaded files that are not a PDF or an image, are empty or are too large.
  final List<String> rejected;
}

/// A file picked or dropped on the app, read into memory to send it to the backend.
class InvoiceUpload {
  const InvoiceUpload(this.name, this.bytes);

  final String name;
  final List<int> bytes;
}

/// The totals of one currency at the end of a sheet.
class CurrencyTotal {
  const CurrencyTotal({
    required this.currency,
    required this.netAmount,
    required this.vatAmount,
    required this.total,
  });

  factory CurrencyTotal.fromJson(Map<String, dynamic> json) => CurrencyTotal(
    currency: json['currency'] as String,
    netAmount: _amount(json['net_amount']),
    vatAmount: _amount(json['vat_amount']),
    total: _amount(json['total']),
  );

  final String currency;
  final double netAmount;
  final double vatAmount;
  final double total;
}

/// One sheet of the workbook: the ok invoices of a month.
class SheetSummary {
  const SheetSummary({
    required this.name,
    required this.month,
    required this.invoices,
    required this.totals,
  });

  factory SheetSummary.fromJson(Map<String, dynamic> json) => SheetSummary(
    name: json['name'] as String,
    month: DateTime.parse(json['month'] as String),
    invoices: json['invoices'] as int,
    totals: [
      for (final line in json['totals'] as List)
        CurrencyTotal.fromJson(line as Map<String, dynamic>),
    ],
  );

  final String name;
  final DateTime month;
  final int invoices;
  final List<CurrencyTotal> totals;
}

/// What the workbook will hold, as the backend sees it, before saving it.
class ExportSummary {
  const ExportSummary({
    required this.fileName,
    required this.sheets,
    required this.needsReview,
    required this.duplicates,
  });

  factory ExportSummary.fromJson(Map<String, dynamic> json) => ExportSummary(
    fileName: json['file_name'] as String,
    sheets: [
      for (final sheet in json['sheets'] as List)
        SheetSummary.fromJson(sheet as Map<String, dynamic>),
    ],
    needsReview: json['needs_review'] as int,
    duplicates: json['duplicates'] as int,
  );

  final String fileName;
  final List<SheetSummary> sheets;
  final int needsReview;
  final int duplicates;

  int get invoices => sheets.fold(0, (sum, sheet) => sum + sheet.invoices);
}

/// The Excel workbook as the backend built it, with the name it suggests.
class Workbook {
  const Workbook(this.fileName, this.bytes);

  final String fileName;
  final Uint8List bytes;
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
    this.doubtfulFields = const [],
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
    doubtfulFields: [for (final name in json['doubtful_fields'] as List? ?? []) name as String],
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

  /// Names of the fields the reviewer should look at, as the backend sees them.
  final List<String> doubtfulFields;

  bool get isPdf => fileName.toLowerCase().endsWith('.pdf');
}

/// How each field is called on screen.
const fieldLabels = {
  'supplier': 'Supplier',
  'invoice_number': 'Number',
  'issue_date': 'Date',
  'net_amount': 'Net',
  'vat_rate': 'VAT %',
  'vat_amount': 'VAT',
  'total': 'Total',
  'currency': 'Currency',
};

/// The fields of an invoice as the reviewer leaves them. Values are the text typed on screen:
/// the backend checks them.
class InvoiceFields {
  const InvoiceFields(this.values, {required this.confidence});

  factory InvoiceFields.of(Invoice invoice) => InvoiceFields({
    'supplier': invoice.supplier,
    'invoice_number': invoice.invoiceNumber,
    'issue_date': _isoDate(invoice.issueDate),
    'net_amount': invoice.netAmount.toStringAsFixed(2),
    'vat_rate': _trim(invoice.vatRate),
    'vat_amount': invoice.vatAmount.toStringAsFixed(2),
    'total': invoice.total.toStringAsFixed(2),
    'currency': invoice.currency,
  }, confidence: invoice.confidence);

  final Map<String, String> values;
  final double confidence;

  Map<String, Object?> toJson() => {
    for (final entry in values.entries) entry.key: entry.value.trim(),
    'confidence': confidence,
  };

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
}
