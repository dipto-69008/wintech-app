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

  // Demo customers list
  final List<Map<String, String>> _customers = [
    {'id': 'cust-001', 'name': 'মেসার্স আল-আমিন ট্রেডার্স'},
    {'id': 'cust-002', 'name': 'নিউ ঢাকা এন্টারপ্রাইজ'},
    {'id': 'cust-003', 'name': 'রহমান স্টোর্স'},
    {'id': 'cust-004', 'name': 'বাংলাদেশ মার্চেন্টস'},
    {'id': 'cust-005', 'name': 'সিটি ট্রেডিং কোম্পানি'},
    {'id': 'cust-006', 'name': 'মেসার্স করিম ব্রাদার্স'},
    {'id': 'cust-007', 'name': 'নর্থ বেঙ্গল ট্রেডার্স'},
    {'id': 'cust-008', 'name': 'ইস্ট ওয়েস্ট সাপ্লাই'},
  ];

  // Demo products
  final List<Map<String, dynamic>> _productSuggestions = [
    {'name': 'সয়াবিন তেল ৫ লিটার', 'unit': 'কার্টন', 'price': 3200.0},
    {'name': 'সয়াবিন তেল ১ লিটার', 'unit': 'কার্টন', 'price': 2800.0},
    {'name': 'চিনি ১ কেজি', 'unit': 'বস্তা', 'price': 4500.0},
    {'name': 'আটা ২ কেজি', 'unit': 'বস্তা', 'price': 2200.0},
    {'name': 'ময়দা ১ কেজি', 'unit': 'বস্তা', 'price': 1800.0},
    {'name': 'লবণ ১ কেজি', 'unit': 'কার্টন', 'price': 650.0},
    {'name': 'মসুর ডাল ১ কেজি', 'unit': 'বস্তা', 'price': 5200.0},
    {'name': 'ছোলার ডাল ১ কেজি', 'unit': 'বস্তা', 'price': 4800.0},
    {'name': 'গুঁড়া দুধ ৪০০ গ্রাম', 'unit': 'কার্টন', 'price': 3600.0},
    {'name': 'টমেটো সস ৩২০ গ্রাম', 'unit': 'কার্টন', 'price': 1200.0},
    {'name': 'সরিষার তেল ১ লিটার', 'unit': 'কার্টন', 'price': 2200.0},
    {'name': 'হলুদ গুঁড়া ২০০ গ্রাম', 'unit': 'কার্টন', 'price': 980.0},
    {'name': 'মরিচ গুঁড়া ২০০ গ্রাম', 'unit': 'কার্টন', 'price': 1100.0},
    {'name': 'ধনিয়া গুঁড়া ২০০ গ্রাম', 'unit': 'কার্টন', 'price': 850.0},
    {'name': 'বিস্কুট (প্যাকেট)', 'unit': 'কার্টন', 'price': 1440.0},
    {'name': 'চানাচুর ২৫০ গ্রাম', 'unit': 'কার্টন', 'price': 960.0},
    {'name': 'সাবান (বার)', 'unit': 'কার্টন', 'price': 780.0},
    {'name': 'শ্যাম্পু ৩৪০ মিলি', 'unit': 'ডজন', 'price': 1560.0},
    {'name': 'টুথপেস্ট ১০০ গ্রাম', 'unit': 'ডজন', 'price': 1200.0},
    {'name': 'ডিটারজেন্ট পাউডার ১ কেজি', 'unit': 'কার্টন', 'price': 2400.0},
  ];

  final _fmt = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadUser();
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

  Future<void> _submitOrder() async {
    if (_selectedCustomerId.isEmpty) {
      _showError('কাস্টমার বেছে নিন');
      return;
    }
    final validItems = _items.where((i) => i.isValid).toList();
    if (validItems.isEmpty) {
      _showError('কমপক্ষে একটি পণ্য যোগ করুন');
      return;
    }

    setState(() => _saving = true);

    final orderItems = validItems.map((i) => OrderItem(
          productName: i.nameCtrl.text.trim(),
          quantity: double.tryParse(i.qtyCtrl.text) ?? 0,
          unit: i.unit,
          unitPrice: double.tryParse(i.priceCtrl.text) ?? 0,
        )).toList();

    final order = OrderModel(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
      srId: _user?.id ?? '',
      srName: _user?.name ?? '',
      customerId: _selectedCustomerId,
      customerName: _selectedCustomerName,
      items: orderItems,
      total: _total,
      date: DateTime.now(),
      status: OrderModel.statusConfirmed,
      notes: _notesCtrl.text.trim(),
    );

    await LocalStorageService.saveOrder(order);

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ অর্ডার সফলভাবে জমা হয়েছে!',
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
              Text('কাস্টমার বেছে নিন',
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
        title: Text('নতুন অর্ডার — POS',
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
                              Text('কাস্টমার *',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 11, color: AppTheme.textGrey)),
                              Text(
                                _selectedCustomerName.isEmpty
                                    ? 'কাস্টমার বেছে নিন'
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
                        Text('পণ্য তালিকা',
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
                        label: Text('পণ্য যোগ',
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
                        labelText: 'নোট (ঐচ্ছিক)',
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
                    Text('মোট পরিমাণ',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('৳ ${_fmt.format(_total)}',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryAccent)),
                  ],
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
                    label: Text(_saving ? 'সংরক্ষণ হচ্ছে...' : 'অর্ডার জমা দিন',
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
                  labelText: 'পণ্যের নাম *',
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
                  labelText: 'পরিমাণ *',
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
                  labelText: 'একক',
                  labelStyle: GoogleFonts.hindSiliguri(
                      fontSize: 12, color: AppTheme.textGrey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                items: ['পিস', 'কেজি', 'লিটার', 'বাক্স', 'ডজন', 'কার্টন', 'গ্রাম']
                    .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u,
                            style: GoogleFonts.hindSiliguri(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => item.unit = v ?? 'পিস'),
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
                  labelText: 'একক মূল্য (৳) *',
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
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'মোট: ৳ ${_fmt.format(item.lineTotal)}',
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
                    child: Text('পণ্য বেছে নিন',
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
                  hintText: 'পণ্যের নাম খুঁজুন...',
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
                      Text('কোনো পণ্য পাওয়া যায়নি',
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
                        child: Text('যোগ করুন',
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
  String unit = 'পিস';

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

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
