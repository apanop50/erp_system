/// Invoice & Price-List PDF Service
///
/// Generates printable PDFs for sales invoices and hotel price lists using
/// the `pdf` and `printing` packages. Arabic text is shaped via
/// presentation forms and ordered right-to-left by the pdf bidi handler.
library;

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/services/pdf_support/arabic_reshaping.dart';
import '../../../../core/services/pdf_support/pdf_font.dart';
import '../../domain/sales_model.dart';
import '../../../products/domain/product_model.dart';

/// Shared PDF service singleton.
class InvoicePdfService {
  InvoicePdfService._();

  static final InvoicePdfService instance = InvoicePdfService._();

  pw.Font? _arabicFont;
  pw.Font? _arabicBoldFont;
  bool _fontLoading = false;

  /// Loads (once) the Arabic-capable PDF font.
  Future<pw.Font> _getArabicFont() async {
    if (_arabicFont != null) return _arabicFont!;
    if (!_fontLoading) {
      _fontLoading = true;
      try {
        final bytes = await loadArabicPdfFontBytes();
        if (bytes != null) {
          _arabicFont = pw.Font.ttf(ByteData.sublistView(bytes));
        }
      } catch (_) {
        // Fall back to Google Fonts below.
      }
      try {
        if (_arabicFont == null) {
          try {
            _arabicFont = await PdfGoogleFonts.cairoRegular();
            _arabicBoldFont = await PdfGoogleFonts.cairoBold();
          } catch (_) {
            try {
              _arabicFont = await PdfGoogleFonts.notoNaskhArabicRegular();
              _arabicBoldFont = await PdfGoogleFonts.notoNaskhArabicBold();
            } catch (_) {
              // Last fallback is Helvetica; Arabic may not render if reached.
            }
          }
        }
      } finally {
        _fontLoading = false;
      }
    }
    return _arabicFont ?? pw.Font.helvetica();
  }

  /// Returns a sized text style using the Arabic font when available.
  pw.TextStyle _style({
    double size = 10,
    pw.FontWeight? weight,
    PdfColor? color,
  }) {
    return pw.TextStyle(
      font: weight == pw.FontWeight.bold
          ? (_arabicBoldFont ?? _arabicFont)
          : _arabicFont,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  /// Shaped Arabic label for use in PDF widgets.
  String _ar(String text) => shapingArabic(text);

  /// Formats a number with thousands separators.
  String _num(num value) => NumberFormat('#,##0.##', 'en_US').format(value);

  static const String _currency = 'ج.م';

  String _money(num value) => '${_num(value)} $_currency';

  /// Number of item rows per table chunk so large invoices (100+ items) split
  /// correctly across multiple pages.
  static const int _itemChunkSize = 30;
  // ==================== INVOICE PDF ====================

  /// Builds the bytes for a sales invoice PDF.
  Future<Uint8List> buildInvoicePdf(SalesInvoice invoice) async {
    await _getArabicFont();

    final doc = pw.Document(title: '${_ar('فاتورة')} ${invoice.invoiceNumber}');
    final theme = pw.ThemeData.withFont(
      base: _arabicFont ?? pw.Font.helvetica(),
      bold: _arabicBoldFont ?? _arabicFont ?? pw.Font.helveticaBold(),
    );

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(invoice),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            _ar('شكراً لتعاملكم معنا — ماريفيو'),
            style: _style(size: 9, color: PdfColors.grey),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        build: (context) => _buildInvoiceSections(invoice),
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader(SalesInvoice invoice) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.indigo, width: 1.5),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _ar('ماريفيو'),
                style: _style(
                  size: 18,
                  weight: pw.FontWeight.bold,
                  color: PdfColors.indigo,
                ),
              ),
              pw.Text(
                'MARIVIO — Packaging',
                style: _style(size: 9, color: PdfColors.grey),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                _ar('فاتورة مبيعات'),
                style: _style(size: 16, weight: pw.FontWeight.bold),
              ),
              pw.Text(
                '${_ar('رقم الفاتورة')}: ${invoice.invoiceNumber}',
                textDirection: pw.TextDirection.rtl,
                style: _style(size: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildInvoiceSections(SalesInvoice invoice) {
    // Item rows for the items table are generated in chunks below so invoices
    // with many items print correctly across multiple pages.

    final customerBlock = pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _ar('بيانات العميل'),
            style: _style(size: 11, weight: pw.FontWeight.bold),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${_ar('الاسم')}: ${_ar(invoice.customerName)}',
            textDirection: pw.TextDirection.rtl,
            style: _style(size: 10),
          ),
          pw.Text(
            '${_ar('التاريخ')}: ${DateFormat('yyyy/MM/dd', 'en_US').format(invoice.invoiceDate)}',
            textDirection: pw.TextDirection.rtl,
            style: _style(size: 10),
          ),
          if (invoice.salesRepName != null && invoice.salesRepName!.isNotEmpty)
            pw.Text(
              '${_ar('المندوب')}: ${_ar(invoice.salesRepName!)}',
              textDirection: pw.TextDirection.rtl,
              style: _style(size: 10),
            ),
        ],
      ),
    );

    final totals = pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.indigo),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _totalRow(_ar('الإجمالي الفرعي'), _money(invoice.subtotal)),
          if (invoice.discount > 0)
            _totalRow(_ar('الخصم'), _money(invoice.discount)),
          if (invoice.taxPercentage > 0)
            _totalRow(
              '${_ar('الضريبة')} (${_num(invoice.taxPercentage)}%)',
              _money(invoice.taxAmount),
            ),
          pw.Divider(color: PdfColors.indigo),
          _totalRow(_ar('الإجمالي'), _money(invoice.grandTotal), bold: true),
          _totalRow(_ar('المدفوع'), _money(invoice.paidAmount)),
          _totalRow(
            _ar('المتبقي'),
            _money(invoice.remainingBalance),
            bold: true,
          ),
        ],
      ),
    );

    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: customerBlock),
          pw.SizedBox(width: 12),
          pw.Expanded(child: totals),
        ],
      ),
      pw.SizedBox(height: 16),
      ..._buildChunkedItemTables(invoice.items),
      if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Text(
          '${_ar('ملاحظات')}: ${_ar(invoice.notes!)}',
          textDirection: pw.TextDirection.rtl,
          style: _style(size: 9),
        ),
      ],
    ];
  }

  pw.Widget _buildItemsTable(List<InvoiceItem> chunk, int startIndex) {
    final rows = <pw.TableRow>[];
    rows.add(
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.indigo),
        children: [
          _cell(_ar('م'), bold: true, white: true),
          _cell(_ar('الصنف'), bold: true, white: true),
          _cell(_ar('الكمية'), bold: true, white: true, alignRight: true),
          _cell(_ar('السعر'), bold: true, white: true, alignRight: true),
          _cell(_ar('الإجمالي'), bold: true, white: true, alignRight: true),
        ],
      ),
    );

    var i = startIndex + 1;
    for (final it in chunk) {
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? PdfColors.grey200 : PdfColors.white,
          ),
          children: [
            _cell('$i'),
            _cell(_ar(it.productName)),
            _cell(_num(it.quantity), alignRight: true),
            _cell(_num(it.unitPrice), alignRight: true),
            _cell(_money(it.total), alignRight: true),
          ],
        ),
      );
      i++;
    }

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: PdfColors.grey300,
          width: 0.5,
        ),
        bottom: pw.BorderSide(color: PdfColors.grey400),
        top: pw.BorderSide(color: PdfColors.grey400),
        left: pw.BorderSide(color: PdfColors.grey400),
        right: pw.BorderSide(color: PdfColors.grey400),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(30),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(55),
        3: pw.FixedColumnWidth(70),
        4: pw.FixedColumnWidth(90),
      },
      children: rows,
    );
  }

  /// Splits [items] into several small tables so long invoices paginate well.
  List<pw.Widget> _buildChunkedItemTables(List<InvoiceItem> items) {
    if (items.isEmpty) return const <pw.Widget>[];
    final widgets = <pw.Widget>[];
    for (var start = 0; start < items.length; start += _itemChunkSize) {
      final end = (start + _itemChunkSize) > items.length
          ? items.length
          : start + _itemChunkSize;
      widgets.add(_buildItemsTable(items.sublist(start, end), start));
      if (end < items.length) widgets.add(pw.SizedBox(height: 6));
    }
    return widgets;
  }

  pw.Widget _cell(
    String text, {
    bool bold = false,
    bool white = false,
    bool alignRight = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      alignment: alignRight
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        textDirection: pw.TextDirection.rtl,
        style: _style(
          size: 9,
          weight: bold ? pw.FontWeight.bold : null,
          color: white ? PdfColors.white : null,
        ),
      ),
    );
  }

  pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            textDirection: pw.TextDirection.rtl,
            style: _style(size: 10, weight: bold ? pw.FontWeight.bold : null),
          ),
          pw.Text(
            value,
            style: _style(size: 10, weight: bold ? pw.FontWeight.bold : null),
          ),
        ],
      ),
    );
  }
  // ==================== HOTEL PRICE LIST PDF ====================

  /// Builds the bytes for a hotel price-list PDF from the given products.
  Future<Uint8List> buildHotelPriceListPdf({
    required Hotel hotel,
    required List<Product> products,
  }) async {
    await _getArabicFont();

    final doc = pw.Document(title: '${_ar('قائمة أسعار')} ${hotel.name}');
    final theme = pw.ThemeData.withFont(
      base: _arabicFont ?? pw.Font.helvetica(),
      bold: _arabicBoldFont ?? _arabicFont ?? pw.Font.helveticaBold(),
    );

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.indigo, width: 1.5),
            ),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                _ar('قائمة أسعار الفندق'),
                style: _style(
                  size: 18,
                  weight: pw.FontWeight.bold,
                  color: PdfColors.indigo,
                ),
              ),
              pw.Text(
                '${_ar('الفندق')}: ${_ar(hotel.name)}',
                textDirection: pw.TextDirection.rtl,
                style: _style(size: 12, weight: pw.FontWeight.bold),
              ),
              if ((hotel.phone ?? '').isNotEmpty)
                pw.Text(
                  '${_ar('الهاتف')}: ${hotel.phone}',
                  textDirection: pw.TextDirection.rtl,
                  style: _style(size: 10),
                ),
            ],
          ),
        ),
        footer: (context) => pw.Text(
          _ar('تم إعداد القائمة بواسطة ماريفيو — الأسعار شاملة الضرائب'),
          style: _style(size: 8, color: PdfColors.grey),
          textDirection: pw.TextDirection.rtl,
        ),
        build: (context) => _hotelPriceListSections(hotel, products),
      ),
    );

    return doc.save();
  }

    /// Splits the hotel price-list into pages with chunked tables so lists with
  /// many products (100+) print correctly.
  List<pw.Widget> _hotelPriceListSections(
    Hotel hotel,
    List<Product> products,
  ) {
    final rows = _chunkRows(products, (p) => hotel.specialPrices[p.id] ?? p.hotelPrice);
    return [
      ..._chunkedPriceTables(
        rows,
        perRow: (p) => [_cell(_ar(p.name)), _cell(_ar(p.unit))],
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        _ar('عدد الأصناف') + ': ${products.length}',
        textDirection: pw.TextDirection.rtl,
        style: _style(size: 9, color: PdfColors.grey),
      ),
    ];
  }

  /// Generic chunked price-list table builder.
  ///
  /// [rows] is the list of products (used for row indexes) and [perRow] maps
  /// a product to its additional leading cells (beyond the row number). The
  /// trailing price column is added automatically.
  List<pw.Widget> _chunkedPriceTables(
    List<(Product, double)> rows, {
    required List<pw.Widget> Function(Product product) perRow,
  }) {
    if (rows.isEmpty) return const <pw.Widget>[];
    final widgets = <pw.Widget>[];
    for (var start = 0; start < rows.length; start += _itemChunkSize) {
      final end = (start + _itemChunkSize) > rows.length
          ? rows.length
          : start + _itemChunkSize;
      widgets.add(_priceTable(rows.sublist(start, end), start, perRow: perRow));
      if (end < rows.length) widgets.add(pw.SizedBox(height: 6));
    }
    return widgets;
  }

  pw.Widget _priceTable(
    List<(Product, double)> rows,
    int startIndex, {
    required List<pw.Widget> Function(Product product) perRow,
  }) {
    final tableRows = <pw.TableRow>[];
    tableRows.add(
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.indigo),
        children: [
          _cell(_ar('م'), bold: true, white: true),
          _cell(_ar('الصنف'), bold: true, white: true),
          _cell(_ar('الوحدة'), bold: true, white: true),
          _cell(_ar('السعر'), bold: true, white: true, alignRight: true),
        ],
      ),
    );
    for (var i = 0; i < rows.length; i++) {
      final (product, price) = rows[i];
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: (startIndex + i + 1).isEven
                ? PdfColors.grey200
                : PdfColors.white,
          ),
          children: [
            _cell('${startIndex + i + 1}'),
            ...perRow(product),
            _cell(_money(price), alignRight: true),
          ],
        ),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(30),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(60),
        3: pw.FixedColumnWidth(90),
      },
      children: tableRows,
    );
  }

  List<(Product, double)> _chunkRows(
    List<Product> products,
    double Function(Product p) priceOf,
  ) {
    return [
      for (final p in products) (p, priceOf(p)),
    ];
  }

  // ==================== GENERAL PRICE LIST PDF ====================

  /// Builds a general price-list PDF for the given products, showing the
  /// different price tiers (selling, hotel, wholesale).
  Future<Uint8List> buildPriceListPdf(List<Product> products) async {
    await _getArabicFont();

    final doc = pw.Document(title: _ar('قائمة الأسعار'));
    final theme = pw.ThemeData.withFont(
      base: _arabicFont ?? pw.Font.helvetica(),
      bold: _arabicBoldFont ?? _arabicFont ?? pw.Font.helveticaBold(),
    );

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.indigo, width: 1.5),
            ),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                _ar('قائمة الأسعار'),
                style: _style(
                  size: 18,
                  weight: pw.FontWeight.bold,
                  color: PdfColors.indigo,
                ),
              ),
              pw.Text(
                _ar('ماريفيو — الأسعار شاملة الضرائب'),
                textDirection: pw.TextDirection.rtl,
                style: _style(size: 10, color: PdfColors.grey),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Text(
          _ar('تم إعداد القائمة بواسطة ماريفيو — الأسعار شاملة الضرائب'),
          style: _style(size: 8, color: PdfColors.grey),
          textDirection: pw.TextDirection.rtl,
        ),
        build: (context) => _generalPriceListSections(products),
      ),
    );

    return doc.save();
  }

  /// Splits the general price-list into chunked tables so lists with many
  /// products (100+) print correctly across pages.
  List<pw.Widget> _generalPriceListSections(List<Product> products) {
    final widgets = <pw.Widget>[];
    for (var start = 0; start < products.length; start += _itemChunkSize) {
      final end = (start + _itemChunkSize) > products.length
          ? products.length
          : start + _itemChunkSize;
      widgets.add(_generalPriceTable(products.sublist(start, end), start));
      if (end < products.length) widgets.add(pw.SizedBox(height: 6));
    }
    widgets.add(pw.SizedBox(height: 12));
    widgets.add(
      pw.Text(
        _ar('عدد الأصناف') + ': ${products.length}',
        textDirection: pw.TextDirection.rtl,
        style: _style(size: 9, color: PdfColors.grey),
      ),
    );
    return widgets;
  }

  /// Builds a single general price-list table for [chunk].
  pw.Widget _generalPriceTable(List<Product> chunk, int startIndex) {
    final tableRows = <pw.TableRow>[];
    tableRows.add(
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.indigo),
        children: [
          _cell(_ar('م'), bold: true, white: true),
          _cell(_ar('الصنف'), bold: true, white: true),
          _cell(_ar('الوحدة'), bold: true, white: true),
          _cell(_ar('سعر البيع'), bold: true, white: true, alignRight: true),
          _cell(_ar('سعر الفندق'), bold: true, white: true, alignRight: true),
          _cell(_ar('سعر الجملة'), bold: true, white: true, alignRight: true),
        ],
      ),
    );
    for (var i = 0; i < chunk.length; i++) {
      final p = chunk[i];
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: (startIndex + i + 1).isEven
                ? PdfColors.grey200
                : PdfColors.white,
          ),
          children: [
            _cell('${startIndex + i + 1}'),
            _cell(_ar(p.name)),
            _cell(_ar(p.unit)),
            _cell(_money(p.sellingPrice), alignRight: true),
            _cell(_money(p.hotelPrice), alignRight: true),
            _cell(_money(p.wholesalePrice), alignRight: true),
          ],
        ),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(45),
        3: pw.FixedColumnWidth(70),
        4: pw.FixedColumnWidth(70),
        5: pw.FixedColumnWidth(70),
      },
      children: tableRows,
    );
  }

  // ==================== PRINT / SHARE ====================

  /// Prints the given invoice PDF.
  Future<void> printInvoicePdf(SalesInvoice invoice) async {
    final bytes = await buildInvoicePdf(invoice);
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: 'invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  /// Shares the given invoice PDF.
  Future<void> shareInvoicePdf(SalesInvoice invoice) async {
    final bytes = await buildInvoicePdf(invoice);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  /// Prints the hotel price list PDF.
  Future<void> printHotelPriceListPdf({
    required Hotel hotel,
    required List<Product> products,
  }) async {
    final bytes = await buildHotelPriceListPdf(
      hotel: hotel,
      products: products,
    );
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: 'hotel_price_list_${hotel.name}.pdf',
    );
  }

  /// Prints a general price list PDF for the given products.
  Future<void> printPriceListPdf(List<Product> products) async {
    final bytes = await buildPriceListPdf(products);
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: 'price_list.pdf',
    );
  }
}

/// Convenience accessor for cross-file use.
InvoicePdfService get pdfService => InvoicePdfService.instance;
