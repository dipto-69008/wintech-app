import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';
import '../../services/secure_screen_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late OrderModel _order;
  UserModel? _currentUser;
  bool _updatingStatus = false;
  final _fmt = NumberFormat('#,##0.00', 'en_US');
  final _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    // Block screenshots/screen-recording until we know the user is admin
    SecureScreenService.enable();
    _loadUser();
  }

  @override
  void dispose() {
    SecureScreenService.disable();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await LocalStorageService.getCurrentUser();
    if (mounted) {
      setState(() => _currentUser = user);
      // Admins may screenshot; officers stay blocked
      if (user != null && user.isAdmin) {
        SecureScreenService.disable();
      }
    }
  }

  bool get _canChangeStatus =>
      _currentUser != null &&
      (_currentUser!.isAdmin ||
          _currentUser!.role == UserModel.roleSuperAdmin ||
          _currentUser!.role == UserModel.roleTeamLeader);

  /// Only admins can download invoices — officers cannot download or screenshot.
  bool get _canDownloadInvoice => _currentUser != null && _currentUser!.isAdmin;

  /// Merge charged + bonus lines of the SAME product into one display row so
  /// the invoice never shows a misleading "[2 items]" for one product.
  /// Bonus quantity is shown as "+N (Bonus)".
  List<_DisplayItem> get _displayItems {
    final List<_DisplayItem> out = [];
    for (final item in _order.items) {
      final baseName = item.productName.replaceAll('(Bonus)', '').trim();
      if (item.isBonus || item.unitPrice == 0 && item.productName.contains('(Bonus)')) {
        // Try to merge into an existing charged row of the same product
        final idx = out.indexWhere((d) => d.name == baseName && !d.isBonusOnly);
        if (idx >= 0) {
          out[idx] = out[idx].withBonus(item.quantity);
          continue;
        }
        out.add(_DisplayItem(
          name: baseName,
          quantity: 0,
          bonusQuantity: item.quantity,
          unit: item.unit,
          unitPrice: 0,
          total: 0,
        ));
      } else {
        // Charged row — absorb any earlier bonus-only row of same product
        final idx = out.indexWhere((d) => d.name == baseName && d.isBonusOnly);
        if (idx >= 0) {
          final bonusQty = out[idx].bonusQuantity;
          out.removeAt(idx);
          out.add(_DisplayItem(
            name: baseName,
            quantity: item.quantity,
            bonusQuantity: bonusQty,
            unit: item.unit,
            unitPrice: item.unitPrice,
            total: item.total,
          ));
        } else {
          out.add(_DisplayItem(
            name: baseName,
            quantity: item.quantity,
            bonusQuantity: 0,
            unit: item.unit,
            unitPrice: item.unitPrice,
            total: item.total,
          ));
        }
      }
    }
    return out;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updatingStatus = true);
    final updated = _order.copyWith(status: newStatus);
    await LocalStorageService.saveOrder(updated);
    if (mounted) {
      setState(() {
        _order = updated;
        _updatingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated: ${updated.statusLabel}',
              style: GoogleFonts.hindSiliguri()),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Future<void> _downloadInvoice() async {
    if (!_canDownloadInvoice) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Only admin can download invoices',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final pdf = pw.Document();

    // Company logo
    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/images/wintech.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    // Colour palette (PDF colours)
    const brandColor = PdfColor.fromInt(0xFF1B9DD9);
    const darkColor = PdfColor.fromInt(0xFF1A2D3D);
    const greyColor = PdfColor.fromInt(0xFF7A8EA0);
    const lightBg = PdfColor.fromInt(0xFFF0F8FD);
    const successColor = PdfColor.fromInt(0xFF2E7D32);
    const warningColor = PdfColor.fromInt(0xFFF57F17);
    const errorColor = PdfColor.fromInt(0xFFC62828);
    const blueColor = PdfColor.fromInt(0xFF1565C0);

    PdfColor statusColor;
    switch (_order.status) {
      case 'delivered':
        statusColor = successColor;
        break;
      case 'cancelled':
        statusColor = errorColor;
        break;
      case 'confirmed':
        statusColor = blueColor;
        break;
      default:
        statusColor = warningColor;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context ctx) {
          return pw.Stack(children: [
            // ── Watermark: company name across the page ──────────────
            pw.Positioned.fill(
              child: pw.Center(
                child: pw.Transform.rotate(
                  angle: 0.5,
                  child: pw.Opacity(
                    opacity: 0.07,
                    child: pw.Text('Wintech Agro Bangladesh',
                        style: pw.TextStyle(
                            fontSize: 42,
                            fontWeight: pw.FontWeight.bold,
                            color: brandColor)),
                  ),
                ),
              ),
            ),
            _invoiceBody(ctx, logoImage, statusColor),
          ]);
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'wintech_invoice_${_order.id.substring(0, 8).toUpperCase()}.pdf',
    );
  }

  pw.Widget _invoiceBody(
      pw.Context ctx, pw.MemoryImage? logoImage, PdfColor statusColor) {
    const brandColor = PdfColor.fromInt(0xFF1B9DD9);
    const darkColor = PdfColor.fromInt(0xFF1A2D3D);
    const greyColor = PdfColor.fromInt(0xFF7A8EA0);
    const lightBg = PdfColor.fromInt(0xFFF0F8FD);
    return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: brandColor,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 24, vertical: 18),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(children: [
                      // Company logo
                      if (logoImage != null) ...[
                        pw.Container(
                          width: 44,
                          height: 44,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(8)),
                          ),
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Image(logoImage),
                        ),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Wintech Agro Bangladesh',
                              style: pw.TextStyle(
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white)),
                          pw.SizedBox(height: 2),
                          pw.Text('Fish Import & Distribution',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.white)),
                        ],
                      ),
                    ]),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE',
                            style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white)),
                        pw.SizedBox(height: 2),
                        pw.Text('#${_order.id.substring(0, 8).toUpperCase()}',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.white)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // ── Order info row ───────────────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bill To
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(14),
                      decoration: pw.BoxDecoration(
                        color: lightBg,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(8)),
                        border: pw.Border.all(
                            color: const PdfColor.fromInt(0xFFD6EAF5)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BILL TO',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: greyColor,
                                  letterSpacing: 1.2)),
                          pw.SizedBox(height: 6),
                          pw.Text(_order.customerName,
                              style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: darkColor)),
                          pw.SizedBox(height: 2),
                          pw.Text('ID: ${_order.customerId}',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: greyColor)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  // Order Details
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(14),
                      decoration: pw.BoxDecoration(
                        color: lightBg,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(8)),
                        border: pw.Border.all(
                            color: const PdfColor.fromInt(0xFFD6EAF5)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ORDER DETAILS',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: greyColor,
                                  letterSpacing: 1.2)),
                          pw.SizedBox(height: 6),
                          _pdfDetailRow('Date',
                              DateFormat('dd MMM yyyy').format(_order.date)),
                          if (_order.probablePaymentDate != null)
                            _pdfDetailRow(
                                'Probable Payment',
                                DateFormat('dd MMM yyyy')
                                    .format(_order.probablePaymentDate!)),
                          _pdfDetailRow('SR Name', _order.srName),
                          _pdfDetailRow('SR ID', _order.srId),
                          _pdfDetailRow('Status', _order.statusLabel,
                              valueColor: statusColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 22),

              // ── Items Table ──────────────────────────────────────────────
              pw.Text('ITEMS',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: greyColor,
                      letterSpacing: 1.2)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                    color: const PdfColor.fromInt(0xFFD6EAF5), width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: brandColor),
                    children: [
                      _tableHeader('Product'),
                      _tableHeader('Qty'),
                      _tableHeader('Unit'),
                      _tableHeader('Price'),
                      _tableHeader('Total'),
                    ],
                  ),
                  // Item rows (bonus lines merged into their product row)
                  ..._displayItems.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    final rowBg = i.isOdd
                        ? const PdfColor.fromInt(0xFFF0F8FD)
                        : PdfColors.white;
                    final qtyText = item.isBonusOnly
                        ? '${_fmt.format(item.bonusQuantity)} (Bonus)'
                        : item.bonusQuantity > 0
                            ? '${_fmt.format(item.quantity)} + ${_fmt.format(item.bonusQuantity)} (Bonus)'
                            : _fmt.format(item.quantity);
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowBg),
                      children: [
                        _tableCell(
                            item.isBonusOnly
                                ? '${item.name} (Bonus)'
                                : item.name,
                            align: pw.TextAlign.left),
                        _tableCell(qtyText),
                        _tableCell(item.unit),
                        _tableCell(item.isBonusOnly
                            ? 'FREE'
                            : '৳${_fmt.format(item.unitPrice)}'),
                        _tableCell(
                            item.isBonusOnly
                                ? '৳0'
                                : '৳${_fmt.format(item.total)}',
                            bold: true),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 16),

              // ── Totals ───────────────────────────────────────────────────
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 220,
                  child: pw.Column(
                    children: [
                      _totalRow('Subtotal', _order.total),
                      if (_order.commissionPct > 0)
                        _totalRow(
                            'Cash Commission (${_order.commissionPct.toStringAsFixed(0)}%)',
                            -(_order.total * _order.commissionPct / 100)),
                      pw.Divider(
                          color: const PdfColor.fromInt(0xFFD6EAF5),
                          height: 8),
                      pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL',
                              style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: darkColor)),
                          pw.Text(
                              '৳${_fmt.format(_order.total - _order.total * _order.commissionPct / 100)}',
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: brandColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (_order.notes.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFE1F4FD),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFF56C1E8)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Notes: ',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: darkColor)),
                      pw.Expanded(
                        child: pw.Text(_order.notes,
                            style: const pw.TextStyle(
                                fontSize: 10, color: darkColor)),
                      ),
                    ],
                  ),
                ),
              ],

              pw.Spacer(),

              // ── Footer ───────────────────────────────────────────────────
              pw.Divider(
                  color: const PdfColor.fromInt(0xFFD6EAF5)),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: const pw.TextStyle(
                          fontSize: 8, color: greyColor)),
                  pw.Text('Wintech Agro Bangladesh • wintech-agro.com',
                      style: const pw.TextStyle(
                          fontSize: 8, color: greyColor)),
                ],
              ),
            ],
          );
  }

  pw.Widget _pdfDetailRow(String label, String value,
      {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Text('$label: ',
              style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromInt(0xFF888888))),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: valueColor ?? const PdfColor.fromInt(0xFF2C2C2C))),
        ],
      ),
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
          textAlign: pw.TextAlign.center),
    );
  }

  pw.Widget _tableCell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: const PdfColor.fromInt(0xFF2C2C2C)),
          textAlign: align),
    );
  }

  pw.Widget _totalRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColor.fromInt(0xFF888888))),
        pw.Text('৳${_fmt.format(amount)}',
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColor.fromInt(0xFF2C2C2C))),
      ],
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(_order.status);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isDark, statusColor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBanner(isDark, statusColor),
                  const SizedBox(height: 16),
                  _buildInfoCards(isDark),
                  const SizedBox(height: 16),
                  _buildItemsTable(isDark),
                  const SizedBox(height: 16),
                  _buildTotalCard(isDark),
                  if (_order.notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildNotesCard(isDark),
                  ],
                  if (_canChangeStatus) ...[
                    const SizedBox(height: 16),
                    _buildStatusActions(isDark),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildAppBar(bool isDark, Color statusColor) {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: AppTheme.primaryAccent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context, _order),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            color: AppTheme.primaryAccent,
          ),
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _order.customerName,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'Order #${_order.id.substring(0, 8).toUpperCase()}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: _downloadInvoice,
          icon: const Icon(Icons.download_rounded, color: Colors.white),
          tooltip: 'Download Invoice',
        ),
      ],
    );
  }

  Widget _buildStatusBanner(bool isDark, Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(_statusIcon(_order.status), color: statusColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _order.statusLabel,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: statusColor),
              ),
              Text(
                _dateFmt.format(_order.date),
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11, color: AppTheme.textGrey),
              ),
            ],
          ),
        ),
        if (_updatingStatus)
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primaryAccent)),
      ]),
    );
  }

  Widget _buildInfoCards(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Row(children: [
      Expanded(
        child: _infoCard(
          isDark: isDark,
          icon: Icons.person_rounded,
          label: 'Party',
          value: _order.customerName,
          sub: 'ID: ${_order.customerId}',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _infoCard(
          isDark: isDark,
          icon: Icons.badge_rounded,
          label: 'SR',
          value: _order.srName,
          sub: 'ID: ${_order.srId}',
        ),
      ),
    ]);
  }

  Widget _infoCard(
      {required bool isDark,
      required IconData icon,
      required String label,
      required String value,
      required String sub}) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 4)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppTheme.primaryAccent, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.hindSiliguri(
                  fontSize: 11, color: AppTheme.textGrey)),
        ]),
        const SizedBox(height: 6),
        Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.hindSiliguri(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkText : AppTheme.textDark)),
        const SizedBox(height: 2),
        Text(sub,
            style: GoogleFonts.hindSiliguri(
                fontSize: 10, color: AppTheme.textGrey)),
      ]),
    );
  }

  Widget _buildItemsTable(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final headerBg =
        isDark ? AppTheme.darkCard2 : AppTheme.lightAccent;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.inventory_2_rounded,
                  color: AppTheme.primaryAccent, size: 18),
              const SizedBox(width: 8),
              Text('Item List',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_displayItems.length} item(s)',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12, color: AppTheme.textGrey)),
            ]),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.divider),
                borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                // Column labels
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10)),
                  ),
                  child: Row(children: [
                    Expanded(
                        flex: 4,
                        child: Text('Product',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textGrey))),
                    _colHeader('Qty', flex: 2),
                    _colHeader('Price', flex: 2),
                    _colHeader('Total', flex: 2, align: TextAlign.right),
                  ]),
                ),
                // Rows (bonus merged into the product's row)
                ...List.generate(_displayItems.length, (i) {
                  final item = _displayItems[i];
                  final isLast = i == _displayItems.length - 1;
                  final rowBg = i.isEven
                      ? (isDark ? AppTheme.darkCard : Colors.white)
                      : (isDark
                          ? AppTheme.darkCard2
                          : AppTheme.primaryBg);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: rowBg,
                      borderRadius: isLast
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(10))
                          : null,
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(
                                  color: AppTheme.divider, width: 0.5)),
                    ),
                    child: Row(children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                item.isBonusOnly
                                    ? '${item.name} (Bonus)'
                                    : item.name,
                                style: GoogleFonts.hindSiliguri(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: item.isBonusOnly
                                        ? AppTheme.warning
                                        : null)),
                            if (!item.isBonusOnly && item.bonusQuantity > 0)
                              Text(
                                  '+ ${_fmt.format(item.bonusQuantity)} ${item.unit} (Bonus)',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.warning)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                            item.isBonusOnly
                                ? '${_fmt.format(item.bonusQuantity)} ${item.unit}'
                                : '${_fmt.format(item.quantity)} ${item.unit}',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 11, color: AppTheme.textGrey)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                            item.isBonusOnly
                                ? 'FREE'
                                : '৳${_fmt.format(item.unitPrice)}',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 11,
                                color: item.isBonusOnly
                                    ? AppTheme.warning
                                    : AppTheme.textGrey)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('৳${_fmt.format(item.total)}',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryAccent)),
                      ),
                    ]),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _colHeader(String text,
      {int flex = 2, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: align,
          style: GoogleFonts.hindSiliguri(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textGrey)),
    );
  }

  Widget _buildTotalCard(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 4)
        ],
      ),
      child: Column(children: [
        _totalRow2('Subtotal', _order.total, isDark),
        if (_order.commissionPct > 0) ...[
          const SizedBox(height: 6),
          _totalRow2(
              'Cash Commission (${_order.commissionPct.toStringAsFixed(0)}%)',
              -(_order.total * _order.commissionPct / 100),
              isDark),
        ],
        const Divider(height: 16),
        Row(children: [
          Text('Grand Total',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 15, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(
              '৳${_fmt.format(_order.total - _order.total * _order.commissionPct / 100)}',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryAccent)),
        ]),
        if (_order.probablePaymentDate != null) ...[
          const Divider(height: 16),
          Row(children: [
            const Icon(Icons.event_rounded,
                size: 15, color: AppTheme.textGrey),
            const SizedBox(width: 6),
            Text('Probable Payment Date',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12.5, color: AppTheme.textGrey)),
            const Spacer(),
            Text(
                DateFormat('dd MMM yyyy')
                    .format(_order.probablePaymentDate!),
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.textDark)),
          ]),
        ],
      ]),
    );
  }

  Widget _totalRow2(String label, double amount, bool isDark) {
    return Row(children: [
      Text(label,
          style: GoogleFonts.hindSiliguri(
              fontSize: 13, color: AppTheme.textGrey)),
      const Spacer(),
      Text('৳${_fmt.format(amount)}',
          style: GoogleFonts.hindSiliguri(
              fontSize: 13,
              color: isDark ? AppTheme.darkText : AppTheme.textDark)),
    ]);
  }

  Widget _buildNotesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_rounded,
              color: AppTheme.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notes',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warning)),
                const SizedBox(height: 4),
                Text(_order.notes,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkText
                            : AppTheme.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusActions(bool isDark) {
    // Available transitions based on current status
    final List<_StatusAction> actions = [];

    if (_order.status == OrderModel.statusPending) {
      actions.add(_StatusAction(
          label: 'Confirm',
          status: OrderModel.statusConfirmed,
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF1565C0)));
      actions.add(_StatusAction(
          label: 'Cancel',
          status: OrderModel.statusCancelled,
          icon: Icons.cancel_rounded,
          color: AppTheme.error));
    } else if (_order.status == OrderModel.statusConfirmed) {
      actions.add(_StatusAction(
          label: 'Mark Delivered',
          status: OrderModel.statusDelivered,
          icon: Icons.local_shipping_rounded,
          color: AppTheme.success));
      actions.add(_StatusAction(
          label: 'Cancel',
          status: OrderModel.statusCancelled,
          icon: Icons.cancel_rounded,
          color: AppTheme.error));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Update Status',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textGrey)),
          const SizedBox(height: 10),
          Row(
            children: actions
                .map((a) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: actions.last == a ? 0 : 8),
                        child: ElevatedButton.icon(
                          onPressed: _updatingStatus
                              ? null
                              : () => _updateStatus(a.status),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: a.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(a.icon, size: 16),
                          label: Text(a.label,
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    // Officers cannot download invoices — hide the button entirely.
    if (!_canDownloadInvoice) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _downloadInvoice,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.download_rounded, size: 20),
          label: Text('Download Invoice',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      case 'confirmed':
        return const Color(0xFF1565C0);
      default:
        return AppTheme.warning;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'delivered':
        return Icons.local_shipping_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'confirmed':
        return Icons.check_circle_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }
}

/// One display row on the invoice — bonus quantities merged with the
/// charged quantity of the same product.
class _DisplayItem {
  final String name;
  final double quantity;      // charged quantity
  final double bonusQuantity; // free quantity
  final String unit;
  final double unitPrice;
  final double total;

  const _DisplayItem({
    required this.name,
    required this.quantity,
    required this.bonusQuantity,
    required this.unit,
    required this.unitPrice,
    required this.total,
  });

  bool get isBonusOnly => quantity == 0 && bonusQuantity > 0;

  _DisplayItem withBonus(double extraBonus) => _DisplayItem(
        name: name,
        quantity: quantity,
        bonusQuantity: bonusQuantity + extraBonus,
        unit: unit,
        unitPrice: unitPrice,
        total: total,
      );
}

class _StatusAction {
  final String label;
  final String status;
  final IconData icon;
  final Color color;
  const _StatusAction(
      {required this.label,
      required this.status,
      required this.icon,
      required this.color});
}
