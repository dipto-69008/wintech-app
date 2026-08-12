import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/expense_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/offline_queue_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  List<ExpenseModel> _expenses = [];
  bool _loading = true;
  bool _erpConnected = false;
  String _typeFilter = 'all';
  late TabController _tabCtrl;

  static const _typeOptions = [
    ('all',                   'All'),
    (ExpenseModel.typeTaBill,     'TA Bill'),
    (ExpenseModel.typeTaDaSheet,  'TA/DA'),
    (ExpenseModel.typeOutStation, 'Out Station'),
    (ExpenseModel.typeMotorcycle, 'Motorcycle'),
    (ExpenseModel.typeOthersBill, 'Others'),
  ];

  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 1, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await LocalStorageService.getCurrentUser();
    final local = await LocalStorageService.getExpenses();
    var all = local;
    var erp = false;

    // ERP-first: fetch live expenses, merge with local-only entries.
    if (await ApiService.isConnected) {
      try {
        final data = await ApiService.expenses();
        final remote = data.map((m) {
          final map = Map<String, dynamic>.from(m);
          map['id'] ??= map['_id']?.toString();
          return ExpenseModel.fromMap(map);
        }).toList();
        final remoteIds = remote.map((e) => e.id).toSet();
        all = [
          ...remote,
          ...local.where((e) => !remoteIds.contains(e.id)),
        ];
        erp = true;
      } catch (_) {
        // Offline or endpoint unavailable — keep local data.
      }
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _erpConnected = erp;
      _expenses = (user?.isAdmin ?? false)
          ? all
          : all.where((e) => e.srId == (user?.id ?? '')).toList();
      _loading = false;
    });
  }

  List<ExpenseModel> get _filtered => _typeFilter == 'all'
      ? _expenses
      : _expenses.where((e) => e.type == _typeFilter).toList();

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TypePickerSheet(
        onPick: (type) {
          Navigator.pop(context);
          _openForm(type: type);
        },
      ),
    );
  }

  void _openForm({required String type, ExpenseModel? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(
          type: type,
          existing: existing,
          user: _user,
          onSave: (e) async {
            await LocalStorageService.saveExpense(e);
            // Only push brand-new bills to the ERP (edits stay local).
            if (existing == null) {
              var sent = false;
              if (await ApiService.isConnected) {
                try {
                  await ApiService.createExpense(e.toMap());
                  sent = true;
                  // The bill now lives in the ERP (with a server id) —
                  // drop the local copy so it doesn't show up twice.
                  await LocalStorageService.deleteExpense(e.id);
                } catch (_) {}
              }
              if (!sent) {
                await OfflineQueueService.enqueueExpense(e.toMap());
              }
              _snack(sent
                  ? '✅ Bill submitted to ERP!'
                  : '📥 Offline — will sync to ERP when connected');
            }
            await _load();
          },
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _delete(ExpenseModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete?',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text('This expense bill will be deleted.',
            style: GoogleFonts.hindSiliguri()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('No', style: GoogleFonts.hindSiliguri())),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  minimumSize: const Size(80, 40)),
              child: Text('Yes', style: GoogleFonts.hindSiliguri())),
        ],
      ),
    );
    if (ok == true) {
      await LocalStorageService.deleteExpense(e.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : RefreshIndicator(
              color: AppTheme.primaryAccent,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(isDark)),
                  SliverToBoxAdapter(child: _buildTypeFilter(isDark)),
                  SliverToBoxAdapter(child: _buildSummary(isDark)),
                  if (_filtered.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty(isDark))
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildTile(_filtered[i], isDark),
                        childCount: _filtered.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: AppTheme.primaryAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Bill',
            style: GoogleFonts.hindSiliguri(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primaryAccent,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.receipt_rounded, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Text('Expense / TA-DA',
            style: GoogleFonts.hindSiliguri(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                _erpConnected
                    ? Icons.cloud_done_rounded
                    : Icons.wifi_off_rounded,
                size: 13,
                color: Colors.white),
            const SizedBox(width: 4),
            Text(_erpConnected ? 'ERP Connected' : 'Offline',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11, color: Colors.white)),
          ]),
        ),
        const SizedBox(width: 8),
        Text('Total: ${_expenses.length}',
            style: GoogleFonts.hindSiliguri(
                fontSize: 13, color: Colors.white70)),
      ]),
    );
  }

  Widget _buildTypeFilter(bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: _typeOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (val, label) = _typeOptions[i];
          final sel = _typeFilter == val;
          return GestureDetector(
            onTap: () => setState(() => _typeFilter = val),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? AppTheme.primaryAccent
                    : (isDark ? AppTheme.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? AppTheme.primaryAccent : AppTheme.divider),
              ),
              child: Text(label,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white
                          : (isDark ? AppTheme.darkText : AppTheme.textDark))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final total =
        _filtered.fold(0.0, (s, e) => s + e.totalAmount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.primaryAccent.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.receipt_rounded,
              color: AppTheme.primaryAccent, size: 18),
          const SizedBox(width: 8),
          Text('${_filtered.length} bills',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13, color: AppTheme.textGrey)),
          if (total > 0) ...[
            Text(' · ',
                style: GoogleFonts.hindSiliguri(color: AppTheme.textGrey)),
            Text('৳ ${_fmt.format(total)}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryAccent)),
          ],
        ]),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(children: [
          Icon(Icons.receipt_rounded,
              size: 64,
              color: isDark ? AppTheme.darkTextGrey : AppTheme.divider),
          const SizedBox(height: 14),
          Text('No bills',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 15, color: AppTheme.textGrey)),
          const SizedBox(height: 6),
          Text('Tap + to add a new bill',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 12, color: AppTheme.textGrey)),
        ]),
      ),
    );
  }

  Widget _buildTile(ExpenseModel e, bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final statusColor = e.status == ExpenseModel.statusApproved
        ? AppTheme.success
        : e.status == ExpenseModel.statusRejected
            ? AppTheme.error
            : AppTheme.warning;

    final typeColors = {
      ExpenseModel.typeTaBill:     AppTheme.primaryAccent,
      ExpenseModel.typeTaDaSheet:  const Color(0xFF6A1B9A),
      ExpenseModel.typeOutStation: const Color(0xFFE65100),
      ExpenseModel.typeMotorcycle: const Color(0xFF1565C0),
      ExpenseModel.typeOthersBill: const Color(0xFF2E7D32),
      ExpenseModel.typeDa:         AppTheme.warning,
    };
    final typeColor = typeColors[e.type] ?? AppTheme.primaryAccent;

    return GestureDetector(
      onTap: () => _openForm(type: e.type, existing: e),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.receipt_rounded, color: typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(e.typeLabel,
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: typeColor)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  if (e.applicantName.isNotEmpty)
                    Text(e.applicantName,
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                      '${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}'
                      '${e.month.isNotEmpty ? ' · ${e.month}' : ''}',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 11, color: AppTheme.textGrey)),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (e.totalAmount > 0)
              Text('৳ ${_fmt.format(e.totalAmount)}',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryAccent)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(e.statusLabel,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _delete(e),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppTheme.error),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Type Picker Sheet ─────────────────────────────────────────────────────

class _TypePickerSheet extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _TypePickerSheet({required this.onPick});

  static const _items = [
    (ExpenseModel.typeTaBill,     'TA Bill',        Icons.directions_car_rounded,   AppTheme.primaryAccent),
    (ExpenseModel.typeTaDaSheet,  'Monthly TA/DA Sheet', Icons.table_rows_rounded, Color(0xFF6A1B9A)),
    (ExpenseModel.typeOutStation, 'Out Station Bill', Icons.hotel_rounded,          Color(0xFFE65100)),
    (ExpenseModel.typeMotorcycle, 'Motorcycle Log',   Icons.two_wheeler_rounded,    Color(0xFF1565C0)),
    (ExpenseModel.typeOthersBill, 'TA/DA & Others Bill', Icons.summarize_rounded, Color(0xFF2E7D32)),
    (ExpenseModel.typeDa,         'DA Bill',          Icons.account_balance_wallet_rounded, AppTheme.warning),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkCard : Colors.white;
    return Container(
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Select Bill Type',
            style: GoogleFonts.hindSiliguri(
                fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ..._items.map((item) {
          final (type, label, icon, color) = item;
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Text(label,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textGrey),
            onTap: () => onPick(type),
          );
        }),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Expense Form Screen  (handles all 6 types)
// ══════════════════════════════════════════════════════════════════════════

class ExpenseFormScreen extends StatefulWidget {
  final String type;
  final ExpenseModel? existing;
  final UserModel? user;
  final Future<void> Function(ExpenseModel) onSave;

  const ExpenseFormScreen({
    super.key,
    required this.type,
    this.existing,
    required this.user,
    required this.onSave,
  });

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fmt = NumberFormat('#,##0.##', 'en_US');

  late TextEditingController _nameCtrl;
  late TextEditingController _designationCtrl;
  late TextEditingController _zoneCtrl;
  late TextEditingController _monthCtrl;

  // TA Bill rows
  final List<Map<String, TextEditingController>> _taRows = [];

  // TA/DA Sheet rows
  final List<Map<String, TextEditingController>> _tadaRows = [];

  // Out Station rows
  final List<Map<String, TextEditingController>> _outRows = [];

  // Motorcycle log rows
  final List<Map<String, TextEditingController>> _motoRows = [];

  // DA Bill
  late TextEditingController _daAmountCtrl;
  late TextEditingController _daNoteCtrl;

  // Others Bill controllers
  late Map<String, TextEditingController> _othersCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl        = TextEditingController(text: e?.applicantName ?? widget.user?.name ?? '');
    _designationCtrl = TextEditingController(text: e?.designation ?? widget.user?.designation ?? '');
    _zoneCtrl        = TextEditingController(text: e?.zone ?? widget.user?.zela ?? '');
    _monthCtrl       = TextEditingController(text: e?.month ?? _currentMonthBn());
    _daAmountCtrl    = TextEditingController();
    _daNoteCtrl      = TextEditingController();

    _othersCtrl = {
      for (final key in _otherKeys) key: TextEditingController(),
    };

    // Populate existing rows
    if (e != null) {
      switch (widget.type) {
        case ExpenseModel.typeTaBill:
          for (final r in e.taRows) _addTaRow(init: r);
          break;
        case ExpenseModel.typeTaDaSheet:
          for (final r in e.tadaRows) _addTadaRow(init: r);
          break;
        case ExpenseModel.typeOutStation:
          for (final r in e.outStationRows) _addOutRow(init: r);
          break;
        case ExpenseModel.typeMotorcycle:
          for (final r in e.motoRows) _addMotoRow(init: r);
          break;
        case ExpenseModel.typeOthersBill:
          for (final key in _otherKeys) {
            _othersCtrl[key]!.text =
                (e.othersBill[key] ?? '').toString();
          }
          break;
        case ExpenseModel.typeDa:
          _daAmountCtrl.text = (e.othersBill['amount'] ?? '').toString();
          _daNoteCtrl.text   = (e.othersBill['note'] ?? '').toString();
          break;
      }
    }

    if (_taRows.isEmpty && widget.type == ExpenseModel.typeTaBill) {
      _addTaRow();
    }
    if (_tadaRows.isEmpty && widget.type == ExpenseModel.typeTaDaSheet) {
      _addTadaRow();
    }
    if (_outRows.isEmpty && widget.type == ExpenseModel.typeOutStation) {
      _addOutRow();
    }
    if (_motoRows.isEmpty && widget.type == ExpenseModel.typeMotorcycle) {
      _addMotoRow();
    }
  }

  static const _otherKeys = [
    'previousDues', 'salesTarget', 'salesAmount', 'salesAchievement',
    'recoveryAmount', 'salesRecoveryPercent', 'tadaPercent', 'currentDues',
    'tadaAmount', 'outStationBill', 'entertainment', 'telephoneBill',
    'ddttCommission', 'courierBill', 'othersBill',
  ];

  static const Map<String, String> _otherLabels = {
    'previousDues':       'Previous Dues',
    'salesTarget':        'Sales Target',
    'salesAmount':        'Sales Amount',
    'salesAchievement':   'Sales Achievement',
    'recoveryAmount':     'Recovery Amount',
    'salesRecoveryPercent': 'Sales Recovery %',
    'tadaPercent':        'TA & DA Percent',
    'currentDues':        'Current Dues',
    'tadaAmount':         'TA & DA Amount',
    'outStationBill':     'Out Station Bill',
    'entertainment':      'Entertainment',
    'telephoneBill':      'Telephone Bill',
    'ddttCommission':     'DD/TT Commission',
    'courierBill':        'Courier Bill',
    'othersBill':         'Others Bill',
  };

  String _currentMonthBn() {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  void _addTaRow({Map<String, dynamic>? init}) {
    setState(() {
      _taRows.add({
        'date':            TextEditingController(text: init?['date'] ?? ''),
        'from':            TextEditingController(text: init?['from'] ?? ''),
        'to':              TextEditingController(text: init?['to'] ?? ''),
        'modeOfTransport': TextEditingController(text: init?['modeOfTransport'] ?? ''),
        'description':     TextEditingController(text: init?['description'] ?? ''),
        'amount':          TextEditingController(text: (init?['amount'] ?? '').toString()),
      });
    });
  }

  void _addTadaRow({Map<String, dynamic>? init}) {
    setState(() {
      _tadaRows.add({
        'date':  TextEditingController(text: init?['date'] ?? ''),
        'place': TextEditingController(text: init?['place'] ?? ''),
        'ta':    TextEditingController(text: (init?['ta'] ?? '').toString()),
        'da':    TextEditingController(text: (init?['da'] ?? '').toString()),
      });
    });
  }

  void _addOutRow({Map<String, dynamic>? init}) {
    setState(() {
      _outRows.add({
        'date':  TextEditingController(text: init?['date'] ?? ''),
        'from':  TextEditingController(text: init?['from'] ?? ''),
        'to':    TextEditingController(text: init?['to'] ?? ''),
        'ta':    TextEditingController(text: (init?['ta'] ?? '').toString()),
        'da':    TextEditingController(text: (init?['da'] ?? '').toString()),
        'hotel': TextEditingController(text: (init?['hotel'] ?? '').toString()),
      });
    });
  }

  void _addMotoRow({Map<String, dynamic>? init}) {
    setState(() {
      _motoRows.add({
        'date':        TextEditingController(text: init?['date'] ?? ''),
        'destination': TextEditingController(text: init?['destination'] ?? ''),
        'purposes':    TextEditingController(text: init?['purposes'] ?? ''),
        'prevReading': TextEditingController(text: (init?['prevReading'] ?? '').toString()),
        'latestReading': TextEditingController(text: (init?['latestReading'] ?? '').toString()),
        'petrol':      TextEditingController(text: (init?['petrol'] ?? '').toString()),
        'mobil':       TextEditingController(text: (init?['mobil'] ?? '').toString()),
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _designationCtrl.dispose();
    _zoneCtrl.dispose();
    _monthCtrl.dispose();
    _daAmountCtrl.dispose();
    _daNoteCtrl.dispose();
    for (final c in _othersCtrl.values) c.dispose();
    for (final r in _taRows) for (final c in r.values) c.dispose();
    for (final r in _tadaRows) for (final c in r.values) c.dispose();
    for (final r in _outRows) for (final c in r.values) c.dispose();
    for (final r in _motoRows) for (final c in r.values) c.dispose();
    super.dispose();
  }

  double _dbl(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    List<Map<String, dynamic>> taRows = [];
    List<Map<String, dynamic>> tadaRows = [];
    List<Map<String, dynamic>> outRows = [];
    List<Map<String, dynamic>> motoRows = [];
    Map<String, dynamic> othersBill = {};

    switch (widget.type) {
      case ExpenseModel.typeTaBill:
        taRows = _taRows.map((r) => {
              'date': r['date']!.text,
              'from': r['from']!.text,
              'to': r['to']!.text,
              'modeOfTransport': r['modeOfTransport']!.text,
              'description': r['description']!.text,
              'amount': _dbl(r['amount']!),
            }).toList();
        break;
      case ExpenseModel.typeTaDaSheet:
        tadaRows = _tadaRows.map((r) {
          final ta = _dbl(r['ta']!);
          final da = _dbl(r['da']!);
          return {
            'date':  r['date']!.text,
            'place': r['place']!.text,
            'ta':    ta,
            'da':    da,
            'total': ta + da,
          };
        }).toList();
        break;
      case ExpenseModel.typeOutStation:
        outRows = _outRows.map((r) {
          final ta    = _dbl(r['ta']!);
          final da    = _dbl(r['da']!);
          final hotel = _dbl(r['hotel']!);
          return {
            'date':  r['date']!.text,
            'from':  r['from']!.text,
            'to':    r['to']!.text,
            'ta':    ta,
            'da':    da,
            'hotel': hotel,
            'total': ta + da + hotel,
          };
        }).toList();
        break;
      case ExpenseModel.typeMotorcycle:
        motoRows = _motoRows.map((r) {
          final prev   = _dbl(r['prevReading']!);
          final latest = _dbl(r['latestReading']!);
          return {
            'date':          r['date']!.text,
            'destination':   r['destination']!.text,
            'purposes':      r['purposes']!.text,
            'prevReading':   prev,
            'latestReading': latest,
            'totalKm':       latest - prev,
            'petrol':        _dbl(r['petrol']!),
            'mobil':         _dbl(r['mobil']!),
          };
        }).toList();
        break;
      case ExpenseModel.typeOthersBill:
        for (final key in _otherKeys) {
          othersBill[key] = _dbl(_othersCtrl[key]!);
        }
        othersBill['totalTaka'] = [
          'tadaAmount', 'outStationBill', 'entertainment',
          'telephoneBill', 'ddttCommission', 'courierBill', 'othersBill'
        ].fold<double>(0.0, (s, k) => s + ((othersBill[k] as double?) ?? 0));
        break;
      case ExpenseModel.typeDa:
        othersBill = {
          'amount': _dbl(_daAmountCtrl),
          'note':   _daNoteCtrl.text.trim(),
        };
        break;
    }

    final model = ExpenseModel(
      id: widget.existing?.id ??
          'EXP-${DateTime.now().millisecondsSinceEpoch}',
      type: widget.type,
      month: _monthCtrl.text.trim(),
      applicantName: _nameCtrl.text.trim(),
      designation: _designationCtrl.text.trim(),
      zone: _zoneCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      status: widget.existing?.status ?? ExpenseModel.statusPending,
      srId: widget.user?.id ?? '',
      taRows: taRows,
      tadaRows: tadaRows,
      outStationRows: outRows,
      motoRows: motoRows,
      othersBill: othersBill,
    );

    await widget.onSave(model);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeLabel = ExpenseModel(
            id: '', type: widget.type, createdAt: DateTime.now(), srId: '')
        .typeLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(typeLabel),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _submit,
              child: Text('Save',
                  style: GoogleFonts.hindSiliguri(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Common header fields
            _sectionCard(isDark, children: [
              _field('Applicant Name', _nameCtrl),
              const SizedBox(height: 12),
              _field('Designation', _designationCtrl),
              const SizedBox(height: 12),
              _field('Zone', _zoneCtrl),
              const SizedBox(height: 12),
              _field('Month', _monthCtrl),
            ]),
            const SizedBox(height: 16),

            // Type-specific rows
            ..._buildTypeFields(isDark),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(
                  widget.existing == null ? 'Save' : 'Update',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildTypeFields(bool isDark) {
    switch (widget.type) {
      case ExpenseModel.typeTaBill:
        return _buildTaBillFields(isDark);
      case ExpenseModel.typeTaDaSheet:
        return _buildTaDaSheetFields(isDark);
      case ExpenseModel.typeOutStation:
        return _buildOutStationFields(isDark);
      case ExpenseModel.typeMotorcycle:
        return _buildMotoFields(isDark);
      case ExpenseModel.typeOthersBill:
        return _buildOthersBillFields(isDark);
      case ExpenseModel.typeDa:
        return _buildDaFields(isDark);
      default:
        return [];
    }
  }

  // ── TA Bill ──────────────────────────────────────────────────────────
  List<Widget> _buildTaBillFields(bool isDark) {
    return [
      Row(children: [
        Text('TA Bill Rows',
            style: GoogleFonts.hindSiliguri(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(
          onPressed: _addTaRow,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Add Row', style: GoogleFonts.hindSiliguri(fontSize: 12)),
        ),
      ]),
      ..._taRows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        return _sectionCard(isDark, children: [
          Row(children: [
            Text('Row ${i + 1}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey)),
            const Spacer(),
            if (_taRows.length > 1)
              GestureDetector(
                onTap: () => setState(() => _taRows.removeAt(i)),
                child: const Icon(Icons.remove_circle_outline_rounded,
                    size: 18, color: AppTheme.error),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field('Date', r['date']!)),
            const SizedBox(width: 8),
            Expanded(child: _field('From', r['from']!)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field('To', r['to']!)),
            const SizedBox(width: 8),
            Expanded(child: _field('Transport', r['modeOfTransport']!)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(flex: 2, child: _field('Description', r['description']!)),
            const SizedBox(width: 8),
            Expanded(child: _field('Amount (৳)', r['amount']!,
                keyboardType: TextInputType.number)),
          ]),
        ]);
      }),
      _totalRow('Total TA',
          _taRows.fold(0.0, (s, r) => s + _dbl(r['amount']!))),
    ];
  }

  // ── TA/DA Sheet ──────────────────────────────────────────────────────
  List<Widget> _buildTaDaSheetFields(bool isDark) {
    return [
      Row(children: [
        Text('Monthly TA/DA Sheet',
            style: GoogleFonts.hindSiliguri(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(
          onPressed: _addTadaRow,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Add Row', style: GoogleFonts.hindSiliguri(fontSize: 12)),
        ),
      ]),
      ..._tadaRows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        final total = _dbl(r['ta']!) + _dbl(r['da']!);
        return _sectionCard(isDark, children: [
          Row(children: [
            Text('Row ${i + 1}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey)),
            const Spacer(),
            if (_tadaRows.length > 1)
              GestureDetector(
                onTap: () => setState(() => _tadaRows.removeAt(i)),
                child: const Icon(Icons.remove_circle_outline_rounded,
                    size: 18, color: AppTheme.error),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field('Date', r['date']!)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _field('Place', r['place']!)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _field('TA (৳)', r['ta']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
                child: _field('DA (৳)', r['da']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(children: [
                Text('Total',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11, color: AppTheme.textGrey)),
                const SizedBox(height: 4),
                Text('৳ ${_fmt.format(total)}',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryAccent)),
              ]),
            ),
          ]),
        ]);
      }),
      _totalRow('Total',
          _tadaRows.fold(0.0, (s, r) => s + _dbl(r['ta']!) + _dbl(r['da']!))),
    ];
  }

  // ── Out Station ──────────────────────────────────────────────────────
  List<Widget> _buildOutStationFields(bool isDark) {
    return [
      Row(children: [
        Text('Out Station Bill',
            style: GoogleFonts.hindSiliguri(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(
          onPressed: _addOutRow,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Add Row', style: GoogleFonts.hindSiliguri(fontSize: 12)),
        ),
      ]),
      ..._outRows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        final total = _dbl(r['ta']!) + _dbl(r['da']!) + _dbl(r['hotel']!);
        return _sectionCard(isDark, children: [
          Row(children: [
            Text('Row ${i + 1}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey)),
            const Spacer(),
            if (_outRows.length > 1)
              GestureDetector(
                onTap: () => setState(() => _outRows.removeAt(i)),
                child: const Icon(Icons.remove_circle_outline_rounded,
                    size: 18, color: AppTheme.error),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field('Date', r['date']!)),
            const SizedBox(width: 8),
            Expanded(child: _field('From', r['from']!)),
            const SizedBox(width: 8),
            Expanded(child: _field('To', r['to']!)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _field('TA (৳)', r['ta']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
                child: _field('DA (৳)', r['da']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
                child: _field('Hotel (৳)', r['hotel']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 6),
          Text('Total: ৳ ${_fmt.format(total)}',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryAccent)),
        ]);
      }),
      _totalRow('Total', _outRows.fold(0.0,
          (s, r) => s + _dbl(r['ta']!) + _dbl(r['da']!) + _dbl(r['hotel']!))),
    ];
  }

  // ── Motorcycle Log ───────────────────────────────────────────────────
  List<Widget> _buildMotoFields(bool isDark) {
    return [
      Row(children: [
        Text('Motorcycle Log Book',
            style: GoogleFonts.hindSiliguri(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(
          onPressed: _addMotoRow,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Add Row', style: GoogleFonts.hindSiliguri(fontSize: 12)),
        ),
      ]),
      ..._motoRows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        final km = _dbl(r['latestReading']!) - _dbl(r['prevReading']!);
        return _sectionCard(isDark, children: [
          Row(children: [
            Text('Row ${i + 1}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey)),
            const Spacer(),
            if (_motoRows.length > 1)
              GestureDetector(
                onTap: () => setState(() => _motoRows.removeAt(i)),
                child: const Icon(Icons.remove_circle_outline_rounded,
                    size: 18, color: AppTheme.error),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field('Date', r['date']!)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _field('Destination/Place', r['destination']!)),
          ]),
          const SizedBox(height: 8),
          _field('Purpose', r['purposes']!),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _field('Previous Reading', r['prevReading']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
                child: _field('Latest Reading', r['latestReading']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(children: [
                Text('Total (KM)',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 10, color: AppTheme.textGrey)),
                Text('${_fmt.format(km < 0 ? 0 : km)}',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryAccent)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _field('Petrol/Octane (L)', r['petrol']!,
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(
                child: _field('Mobil (L)', r['mobil']!,
                    keyboardType: TextInputType.number)),
          ]),
        ]);
      }),
    ];
  }

  // ── Others Bill ──────────────────────────────────────────────────────
  List<Widget> _buildOthersBillFields(bool isDark) {
    return [
      Text('TA/DA & Others Bill',
          style: GoogleFonts.hindSiliguri(
              fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _sectionCard(isDark, children: [
        ..._otherKeys.map((key) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _field(_otherLabels[key]!, _othersCtrl[key]!,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {})),
            )),
        Divider(color: AppTheme.divider.withValues(alpha: 0.5)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total Taka',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          Text(
              '৳ ${_fmt.format([
                'tadaAmount', 'outStationBill', 'entertainment',
                'telephoneBill', 'ddttCommission', 'courierBill', 'othersBill'
              ].fold<double>(0.0,
                  (s, k) => s + _dbl(_othersCtrl[k]!)))}',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryAccent)),
        ]),
      ]),
    ];
  }

  // ── DA Bill ──────────────────────────────────────────────────────────
  List<Widget> _buildDaFields(bool isDark) {
    return [
      _sectionCard(isDark, children: [
        _field('DA Amount (৳)', _daAmountCtrl,
            keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        _field('Note', _daNoteCtrl),
      ]),
    ];
  }

  // ── helpers ──────────────────────────────────────────────────────────
  Widget _sectionCard(bool isDark,
      {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
              blurRadius: 4)
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType, ValueChanged<String>? onChanged}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.hindSiliguri(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: GoogleFonts.hindSiliguri(fontSize: 13),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.divider, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppTheme.primaryAccent, width: 2)),
          ),
        ),
      ]);

  Widget _totalRow(String label, double amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('$label: ',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            Text('৳ ${_fmt.format(amount)}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryAccent)),
          ],
        ),
      );
}
