import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';

import 'api/models.dart';

/// The file types the backend reads. It checks them again: this only filters the dialog.
const invoiceTypes = XTypeGroup(
  label: 'Invoices',
  extensions: ['pdf', 'png', 'jpg', 'jpeg'],
  uniformTypeIdentifiers: ['com.adobe.pdf', 'public.png', 'public.jpeg'],
);

const _excel = XTypeGroup(
  label: 'Excel workbook',
  extensions: ['xlsx'],
  uniformTypeIdentifiers: ['org.openxmlformats.spreadsheetml.sheet'],
);

/// The system dialogs and the disk. The screens use this, and the tests replace it.
class FileAccess {
  const FileAccess();

  /// Ask for invoices to add. Empty when the person cancels.
  Future<List<InvoiceUpload>> pickInvoices() async {
    final files = await openFiles(acceptedTypeGroups: const [invoiceTypes]);
    return [for (final file in files) InvoiceUpload(file.name, await file.readAsBytes())];
  }

  /// Ask where to save the workbook and write it there. Null when the person cancels.
  Future<String?> saveWorkbook(Workbook workbook) async {
    final location = await getSaveLocation(
      suggestedName: workbook.fileName,
      acceptedTypeGroups: const [_excel],
    );
    if (location == null) return null;
    await File(location.path).writeAsBytes(workbook.bytes, flush: true);
    return location.path;
  }

  /// Read what was dropped on the window. A folder gives the files inside it.
  Future<List<InvoiceUpload>> readDropped(List<DropItem> items) async {
    final uploads = <InvoiceUpload>[];
    for (final item in items) {
      if (item is DropItemDirectory) {
        uploads.addAll(await readDropped(item.children));
        continue;
      }
      uploads.add(InvoiceUpload(item.name, await _read(item)));
    }
    return uploads;
  }

  // A file from outside the app container is read inside a security-scoped access.
  Future<Uint8List> _read(DropItem item) async {
    final bookmark = item.extraAppleBookmark ?? Uint8List(0);
    final granted =
        bookmark.isNotEmpty &&
        await DesktopDrop.instance.startAccessingSecurityScopedResource(bookmark: bookmark);
    try {
      return await item.readAsBytes();
    } finally {
      if (granted) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(bookmark: bookmark);
      }
    }
  }
}
