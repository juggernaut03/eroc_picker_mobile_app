import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';
import '../models/item_model.dart';
import '../utils/app_constants.dart';
import '../utils/helpers.dart';

class OrderPdf {
  static Future<void> shareOrPrint({
    required Order order,
    required List<OrderItem> items,
  }) async {
    final doc = await _build(order: order, items: items);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'order_${order.ordersIdorders}.pdf',
    );
  }

  static Future<pw.Document> _build({
    required Order order,
    required List<OrderItem> items,
  }) async {
    final doc = pw.Document(title: 'Order #${order.ordersIdorders}');
    final assignment = order.currentAssignment;

    final picked = items.where((i) {
      final ps = i.pickerStatus;
      return ps != null && ps.pickedStatus == 'picked' && ps.pickedQuantity >= i.orderedQuantity;
    }).length;
    final partial = items.where((i) {
      final ps = i.pickerStatus;
      return ps != null && ps.pickedStatus == 'picked' && ps.pickedQuantity < i.orderedQuantity;
    }).length;
    final issues = items.where((i) {
      final ps = i.pickerStatus;
      return ps != null && ps.pickedStatus != 'pending' && ps.pickedStatus != 'picked';
    }).length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 32),
        header: (_) => _header(order),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 10),
          _summary(order, assignment),
          pw.SizedBox(height: 14),
          _statsRow(total: items.length, picked: picked, partial: partial, issues: issues),
          pw.SizedBox(height: 16),
          pw.Text('Items',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _itemsTable(items),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _header(Order order) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(AppConstants.appName,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(AppConstants.appTagline,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Order #${order.ordersIdorders}',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Store ${order.storeCode}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
      );

  static pw.Widget _summary(Order order, dynamic assignment) {
    final rows = <List<String>>[
      ['Order ID', '#${order.ordersIdorders}'],
      ['Store', order.storeCode],
      ['Total Items', '${order.totalItems}'],
      ['Total Amount', 'Rs ${order.totalAmount.toStringAsFixed(2)}'],
      if (order.orderDate != null) ['Order Date', formatDate(order.orderDate)],
      if (order.deliveryDate != null) ['Delivery Date', order.deliveryDate!],
      ['Status', _titleCase(order.status)],
      if (assignment != null && assignment.assignedTo != null) ...[
        ['Picker', assignment.assignedTo.name],
        ['Picker Email', assignment.assignedTo.email],
      ],
      if (assignment != null)
        ['Assigned At', formatDateTime(assignment.assignedAt)],
      if (assignment != null && assignment.completedAt != null)
        ['Completed At', formatDateTime(assignment.completedAt)],
    ];

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows.map((r) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 110,
                    child: pw.Text(r[0],
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ),
                  pw.Expanded(
                    child: pw.Text(r[1],
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
            )).toList(),
      ),
    );
  }

  static pw.Widget _statsRow({
    required int total,
    required int picked,
    required int partial,
    required int issues,
  }) {
    pw.Widget cell(String label, String value, PdfColor color) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 3),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text(value,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
                pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ),
        );

    return pw.Row(
      children: [
        cell('Total', '$total', PdfColors.blueGrey700),
        cell('Picked', '$picked', PdfColors.green700),
        cell('Partial', '$partial', PdfColors.orange700),
        cell('Issues', '$issues', PdfColors.red700),
      ],
    );
  }

  static pw.Widget _itemsTable(List<OrderItem> items) {
    final headerStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final cellStyle = const pw.TextStyle(fontSize: 9);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(20),
        1: pw.FlexColumnWidth(3.4),
        2: pw.FixedColumnWidth(40),
        3: pw.FixedColumnWidth(40),
        4: pw.FixedColumnWidth(55),
        5: pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          children: [
