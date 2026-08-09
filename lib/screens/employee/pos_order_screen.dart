import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class PosOrderScreen extends StatefulWidget {
  const PosOrderScreen({super.key});

  @override
  State<PosOrderScreen> createState() => _PosOrderScreenState();
}

class _PosOrderScreenState extends State<PosOrderScreen> {
  UserModel? _user;
  bool _saving = false;

  // Customer
  String _selectedCustomerId = '';
  String _selectedCustomerName = '';
  final _customerCtrl = TextEditingController();

  // Order items
  final List<_ItemRow> _items = [];

  // Notes
  final _notesCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _paidAmountCtrl = TextEditingController();
  DateTime _saleDate = DateTime.now();
  DateTime? _probablePaymentDate;
  String _paymentType = 'Cash';

  // Demo customers list
  final List<Map<String, String>> _customers = [
    {'id': 'cust-001', 'name': 'Messrs Al-Amin Traders'},
    {'id': 'cust-002', 'name': 'New Dhaka Enterprise'},
    {'id': 'cust-003', 'name': 'Rahman Stores'},
    {'id': 'cust-004', 'name': 'Bangladesh Merchants'},
    {'id': 'cust-005', 'name': 'City Trading Company'},
    {'id': 'cust-006', 'name': 'Messrs Karim Brothers'},
    {'id': 'cust-007', 'name': 'North Bengal Traders'},
    {'id': 'cust-008', 'name': 'East West Supply'},
  ];

  // Demo products
  final List<Map<String, dynamic>> _productSuggestions = [
    {'name': 'Soybean Oil 5 Litre', 'unit': 'Carton', 'price': 3200.0},
    {'name': 'Soybean Oil 1 Litre', 'unit': 'Carton', 'price': 2800.0},
    {'name': 'Sugar 1 kg', 'unit': 'Sack', 'price': 4500.0},
    {'name': 'Flour 2 kg', 'unit': 'Sack', 'price': 2200.0},
    {'name': 'Maida 1 kg', 'unit': 'Sack', 'price': 1800.0},
    {'name': 'Salt 1 kg', 'unit': 'Carton', 'price': 650.0},
    {'name': 'Red Lentil 1 kg', 'unit': 'Sack', 'price': 5200.0},
    {'name': 'Chickpea Dal 1 kg', 'unit': 'Sack', 'price': 4800.0},
    {'name': 'Milk Powder 400 g', 'unit': 'Carton', 'price': 3600.0},
    {'name': 'Tomato Sauce 320 g', 'unit': 'Carton', 'price': 1200.0},
    {'name': 'Mustard Oil 1 Litre', 'unit': 'Carton', 'price': 2200.0},
    {'name': 'Turmeric Powder 200 g', 'unit': 'Carton', 'price': 980.0},
    {'name': 'Chilli Powder 200 g', 'unit': 'Carton', 'price': 1100.0},
    {'name': 'Coriander Powder 200 g', 'unit': 'Carton', 'price': 850.0},
    {'name': 'Biscuit (Packet)', 'unit': 'Carton', 'price': 1440.0},
    {'name': 'Chanachur 250 g', 'unit': 'Carton', 'price': 960.0},
    {'name': 'Soap (Bar)', 'unit': 'Carton', 'price': 780.0},
    {'name': 'Shampoo 340 ml', 'unit': 'Dozen', 'price': 1560.0},
    {'name': 'Toothpaste 100 g', 'unit': 'Dozen', 'price': 1200.0},
    {'name': 'Detergent Powder 1 kg', 'unit': 'Carton', 'price': 2400.0},
  ];

  final _fmt = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadUser();
    _invoiceCtrl.text =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _addItem(); // start with one empty item
  }

  Future<void> _loadUser() async {
    final user = await LocalStorageService.getCurrentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemRow());
    });
  }

  void _removeItem(int index) {
    if (_items.length == 1) return;
    setState(() => _items.removeAt(index));
  }

  double get _total => _items.fold(0.0, (s, r) => s + r.lineTotal);

  double get _paidAmount {
    final entered = double.tryParse(_paidAmountCtrl.text.trim());
    if (entered == null) return _paymentType == 'Cash' ? _total : 0;
    return entered.clamp(0, _total).toDouble();
  }

  double get _dueAmount =>
      (_total - _paidAmount).clamp(0, double.infinity).toDouble();

  double get _bonusCount => _items.fold(
      0.0, (sum, item) => sum + (item.bonusEnabled ? item.bonusQuantity : 0));

  Future<void> _submitOrder() async {
    if (_selectedCustomerId.isEmpty) {
      _showError('Please select a customer');
      return;
    }
    final validItems = _items.where((i) => i.isValid).toList();
    if (validItems.isEmpty) {
      _showError('Please add at least one product');
      return;
    }

    setState(() => _saving = true);

    final orderItems = validItems.map((i) => OrderItem(
          productName: i.nameCtrl.text.trim(),
          quantity: double.tryParse(i.qtyCtrl.text) ?? 0,
          unit: i.unit,
          unitPrice: double.tryParse(i.priceCtrl.text) ?? 0,
        )).toList();
    for (final item in validItems) {
      if (item.hasBonus) {
        orderItems.add(OrderItem(
          productName: item.nameCtrl.text.trim(),
          quantity: item.bonusQuantity.toDouble(),
          unit: item.unit,
          unitPrice: 0,
          isBonus: true,
        ));
      }
    }

    final order = OrderModel(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
      srId: _user?.id ?? '',
      srName: _user?.name ?? '',
      customerId: _selectedCustomerId,
      customerName: _selectedCustomerName,
      items: orderItems,
      total: _total,
      date: _saleDate,
      status: OrderModel.statusPending,
      notes: _notesCtrl.text.trim(),
      invoiceNo: _invoiceCtrl.text.trim(),
      paymentType: _paymentType,
      paidAmount: _paidAmount,
      dueAmount: _dueAmount,
      branch: _user?.branch ?? '',
      probablePaymentDate: _probablePaymentDate == null
          ? ''
          : DateFormat('yyyy-MM-dd').format(_probablePaymentDate!),
    );

    await LocalStorageService.saveOrder(order);

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Order submitted successfully!',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
    Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _pickCustomer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(4))),
              Text('Select Customer',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
               ..._customers.map((c) => ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.lightAccent,
                      child: Icon(Icons.store_rounded,
                          color: AppTheme.primaryAccent, size: 18),
                    ),
                    title: Text(c['name']!,
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: _selectedCustomerId == c['id']
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppTheme.primaryAccent)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCustomerId = c['id']!;
                        _selectedCustomerName = c['name']!;
                      });
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _pickProduct(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ProductPickerSheet(
        products: _productSuggestions,
        fmt: _fmt,
        onSelect: (p) {
          setState(() {
            _items[index].nameCtrl.text = p['name'] as String;
            _items[index].priceCtrl.text =
                (p['price'] as double).toStringAsFixed(2);
            _items[index].unit = p['unit'] as String;
            if (_items[index].qtyCtrl.text.isEmpty) {
              _items[index].qtyCtrl.text = '1';
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('New Order — POS',
            style: GoogleFonts.hindSiliguri(
                fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer selector
                  GestureDetector(
                    onTap: _pickCustomer,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedCustomerId.isEmpty
                              ? AppTheme.divider
                              : AppTheme.primaryAccent,
                          width: _selectedCustomerId.isEmpty ? 1.5 : 2,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.store_rounded,
                              color: AppTheme.primaryAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customer *',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 11, color: AppTheme.textGrey)),
                              Text(
                                _selectedCustomerName.isEmpty
                                    ? 'Select Customer'
                                    : _selectedCustomerName,
                                style: GoogleFonts.hindSiliguri(
                                    fontSize: 14,
                                    fontWeight: _selectedCustomerName.isEmpty
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                    color: _selectedCustomerName.isEmpty
                                        ? AppTheme.textGrey
                                        : (isDark
                                            ? AppTheme.darkText
                                            : AppTheme.textDark)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded,
                            color: AppTheme.primaryAccent),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildOrderInfoCard(isDark, cardBg),
                  const SizedBox(height: 20),

                  // Items header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                                color: AppTheme.primaryAccent,
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text('Product List',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTheme.darkText
                                    : AppTheme.textDark)),
                      ]),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('Add Product',
                            style: GoogleFonts.hindSiliguri(fontSize: 13)),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Item rows
                  ..._items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return _buildItemCard(i, item, isDark, cardBg);
                  }),

                  const SizedBox(height: 16),

                  // Notes
                  Container(
                    decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.divider)),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      style: GoogleFonts.hindSiliguri(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        labelStyle: GoogleFonts.hindSiliguri(
                            fontSize: 13, color: AppTheme.textGrey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Bottom total + submit
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            decoration: BoxDecoration(
              color: cardBg,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4))
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('৳ ${_fmt.format(_total)}',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryAccent)),
                  ],
                ),
                if (_bonusCount > 0) ...[
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🎁 Bonus / Free',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 12, color: AppTheme.warning)),
                      Text('${_fmt.format(_bonusCount)} units',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warning)),
                    ],
                  ),
                ],
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Paid ৳${_fmt.format(_paidAmount)} · Due ৳${_fmt.format(_dueAmount)}',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11, color: AppTheme.textGrey),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _submitOrder,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)))
                        : const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(_saving ? 'Saving...' : 'Submit Order',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_rounded,
                  color: AppTheme.primaryAccent, size: 19),
              const SizedBox(width: 8),
              Text('Order Info',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _invoiceCtrl,
                  style: GoogleFonts.hindSiliguri(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Invoice No',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                    isDense: true,
                    labelStyle: GoogleFonts.hindSiliguri(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickSaleDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Sale Date',
                      prefixIcon:
                          const Icon(Icons.calendar_today_rounded, size: 18),
                      isDense: true,
                      labelStyle: GoogleFonts.hindSiliguri(fontSize: 12),
                    ),
                    child: Text(DateFormat('dd MMM yyyy').format(_saleDate),
                        style: GoogleFonts.hindSiliguri(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _paymentType,
                  decoration: InputDecoration(
                    labelText: 'Payment Type',
                    prefixIcon: const Icon(Icons.payments_rounded, size: 18),
                    isDense: true,
                    labelStyle: GoogleFonts.hindSiliguri(fontSize: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(
                        value: 'Bank Transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                    DropdownMenuItem(
                        value: 'Mobile Banking', child: Text('Mobile Banking')),
                    DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                  ],
                  onChanged: (value) =>
                      setState(() => _paymentType = value ?? 'Cash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickProbablePaymentDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Probable Payment Date',
                      prefixIcon:
                          const Icon(Icons.event_available_rounded, size: 18),
                      isDense: true,
                      labelStyle: GoogleFonts.hindSiliguri(fontSize: 12),
                    ),
                    child: Text(
                      _probablePaymentDate == null
                          ? 'Select date'
                          : DateFormat('dd MMM yyyy')
                              .format(_probablePaymentDate!),
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 13,
                        color: _probablePaymentDate == null
                            ? AppTheme.textGrey
                            : (isDark ? AppTheme.darkText : AppTheme.textDark),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_probablePaymentDate != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _probablePaymentDate = null),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Remove Date'),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _paidAmountCtrl,
            onChanged: (_) => setState(() {}),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            style: GoogleFonts.hindSiliguri(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Paid Amount (৳)',
              prefixIcon: const Icon(Icons.account_balance_wallet_rounded,
                  size: 18),
              hintText: _paymentType == 'Cash' ? _fmt.format(_total) : '0',
              isDense: true,
              labelStyle: GoogleFonts.hindSiliguri(fontSize: 12),
            ),
          ),
          if ((_user?.branch ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.store_mall_directory_rounded,
                      size: 16, color: AppTheme.textGrey),
                  const SizedBox(width: 6),
                  Text('Sale Branch: ${_user!.branch}',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12, color: AppTheme.textGrey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickSaleDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _saleDate = date);
  }

  Future<void> _pickProbablePaymentDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _probablePaymentDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _probablePaymentDate = date);
  }

  Widget _buildItemCard(
      int index, _ItemRow item, bool isDark, Color cardBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: item.nameCtrl,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.hindSiliguri(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Product Name *',
                  labelStyle: GoogleFonts.hindSiliguri(
                      fontSize: 12, color: AppTheme.textGrey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _pickProduct(index),
              child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.search_rounded,
                      color: AppTheme.primaryAccent, size: 20)),
            ),
            if (_items.length > 1) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeItem(index),
                child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.error, size: 20)),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: item.qtyCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
                style: GoogleFonts.hindSiliguri(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  labelStyle: GoogleFonts.hindSiliguri(
                      fontSize: 12, color: AppTheme.textGrey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: item.unit,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkText : AppTheme.textDark),
                decoration: InputDecoration(
                  labelText: 'Unit',
                  labelStyle: GoogleFonts.hindSiliguri(
                      fontSize: 12, color: AppTheme.textGrey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                items: ['Piece', 'Kg', 'Litre', 'Box', 'Dozen', 'Carton', 'Gram']
                    .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u,
                            style: GoogleFonts.hindSiliguri(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => item.unit = v ?? 'Piece'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: item.priceCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
                style: GoogleFonts.hindSiliguri(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Unit Price (৳) *',
                  labelStyle: GoogleFonts.hindSiliguri(
                      fontSize: 12, color: AppTheme.textGrey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ]),
          if (item.isValid) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: item.bonusEnabled
                    ? AppTheme.warning.withValues(alpha: 0.09)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: item.bonusEnabled
                      ? AppTheme.warning.withValues(alpha: 0.45)
                      : AppTheme.divider,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: item.bonusEnabled,
                    activeColor: AppTheme.warning,
                    visualDensity: VisualDensity.compact,
                    onChanged: (value) => setState(() {
                      item.bonusEnabled = value ?? false;
                      if (!item.bonusEnabled) item.bonusQtyCtrl.clear();
                    }),
                  ),
                  Expanded(
                    child: Text(
                      'Bonus offer',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: item.bonusEnabled
                            ? AppTheme.warning
                            : (isDark
                                ? AppTheme.darkText
                                : AppTheme.textDark),
                      ),
                    ),
                  ),
                  if (item.bonusEnabled) ...[
                    SizedBox(
                      width: 86,
                      child: TextField(
                        controller: item.bonusQtyCtrl,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'))
                        ],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.hindSiliguri(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Free Qty',
                          labelStyle:
                              GoogleFonts.hindSiliguri(fontSize: 10),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Free',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 11,
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.hasBonus)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '🎁 ${_fmt.format(item.bonusQuantity)} ${item.unit} bonus — ৳0',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11,
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ৳ ${_fmt.format(item.lineTotal)}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _notesCtrl.dispose();
    _invoiceCtrl.dispose();
    _paidAmountCtrl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }
}

// ── Product picker bottom sheet with search ──────────────────────────────
class _ProductPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final NumberFormat fmt;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _ProductPickerSheet(
      {required this.products, required this.fmt, required this.onSelect});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.products
        .where((p) =>
            (p['name'] as String).contains(_query) ||
            (p['unit'] as String).contains(_query))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Select Product',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppTheme.darkText
                                : AppTheme.textDark)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.textGrey, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Search box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.hindSiliguri(fontSize: 14),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search product name...',
                  hintStyle: GoogleFonts.hindSiliguri(
                      fontSize: 13, color: AppTheme.textGrey),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.textGrey, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: const Icon(Icons.clear_rounded,
                              color: AppTheme.textGrey, size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppTheme.primaryAccent.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppTheme.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryAccent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off_rounded,
                          color: AppTheme.textGrey, size: 40),
                      const SizedBox(height: 8),
                      Text('No products found',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 14, color: AppTheme.textGrey)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 6),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2_rounded,
                            color: AppTheme.primaryAccent, size: 20),
                      ),
                      title: Text(p['name'] as String,
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppTheme.darkText
                                  : AppTheme.textDark)),
                      subtitle: Text(
                          '৳ ${widget.fmt.format(p['price'])} / ${p['unit']}',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 12,
                              color: AppTheme.textGrey)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Add',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12,
                                color: AppTheme.primaryAccent,
                                fontWeight: FontWeight.w600)),
                      ),
                      onTap: () {
                        widget.onSelect(p);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final bonusQtyCtrl = TextEditingController();
  String unit = 'Piece';
  bool bonusEnabled = false;

  bool get isValid {
    final name = nameCtrl.text.trim();
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    return name.isNotEmpty && qty > 0 && price > 0;
  }

  double get lineTotal {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    return qty * price;
  }

  double get bonusQuantity => double.tryParse(bonusQtyCtrl.text) ?? 0;

  bool get hasBonus => bonusEnabled && bonusQuantity > 0;

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
    bonusQtyCtrl.dispose();
  }
}
