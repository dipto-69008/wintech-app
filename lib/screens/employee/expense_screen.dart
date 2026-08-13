import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../data/wintech_catalog.dart';
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
    (ExpenseModel.typeDa,         'DA Bill'),
    (ExpenseModel.typeTaDaSheet,  'Top Sheet'),
    (ExpenseModel.typeOutStation, 'Out Station'),
    (ExpenseModel.typeMotorcycle, 'Motorcycle'),
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
              var rejected = '';
              if (await ApiService.isConnected) {
                try {
                  // Upload supporting document photos (local camera captures)
                  // so the ERP stores durable URLs instead of device paths.
                  final payload = e.toMap();
                  Future<void> uploadDocsIn(String key) async {
                    final rows = payload[key];
                    if (rows is! List) return;
                    for (final row in rows) {
                      if (row is! Map) continue;
                      final doc = (row['supportingDoc'] ?? '').toString();
                      if (doc.isNotEmpty && !doc.startsWith('http')) {
                        row['supportingDoc'] = await ApiService.uploadPhoto(
                            doc,
                            folder: 'expenses');
                      }
                    }
                  }

                  await uploadDocsIn('motoRows');
                  await uploadDocsIn('motoServicingRows');
                  await ApiService.createExpense(payload);
                  sent = true;
                  // The bill now lives in the ERP (with a server id) —
                  // drop the local copy so it doesn't show up twice.
                  await LocalStorageService.deleteExpense(e.id);
                } on ApiException catch (ex) {
                  if (ex.statusCode == 400 || ex.statusCode == 403) {
                    // Business rejection (month lock / missing doc / Friday DA)
                    rejected = ex.message;
                    await LocalStorageService.deleteExpense(e.id);
                  }
                } catch (_) {}
              }
              if (rejected.isNotEmpty) {
                _snack(rejected.replaceFirst(RegExp(r'^[A-Z_]+: '), ''),
                    error: true);
              } else {
                if (!sent) {
                  await OfflineQueueService.enqueueExpense(e.toMap());
                }
                _snack(sent
                    ? '✅ Bill submitted to ERP!'
                    : '📥 Offline — will sync to ERP when connected');
              }
            }
            await _load();
          },
        ),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
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
    (ExpenseModel.typeDa,         'DA Bill',          Icons.account_balance_wallet_rounded, AppTheme.warning),
    (ExpenseModel.typeOutStation, 'Out Station Bill', Icons.hotel_rounded,          Color(0xFFE65100)),
    (ExpenseModel.typeMotorcycle, 'Motorcycle Log',   Icons.two_wheeler_rounded,    Color(0xFF1565C0)),
    (ExpenseModel.typeOthersBill, 'TA/DA Top Sheet', Icons.summarize_rounded, Color(0xFF2E7D32)),
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
//  Expense Form Screen  (handles all bill types)
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

  // Dropdown-driven header values
  String _applicantName = '';
  String _designation = '';
  String _zone = '';
  String _month = '';

  List<String> _employeeNames = [];
  List<String> _zoneOptions = [];
  List<String> _monthOptions = [];

  // Motorcycle registration number (entered once, then auto-filled)
  late TextEditingController _motoRegCtrl;
  bool _motoRegSaved = false;

  // TA Bill rows
  final List<Map<String, TextEditingController>> _taRows = [];

  // Motorcycle Servicing Bill rows (attached to TA bill & motorcycle log)
  final List<Map<String, TextEditingController>> _servRows = [];

  // TA/DA Top Sheet rows
  final List<Map<String, TextEditingController>> _tadaRows = [];

  // Out Station rows
  final List<Map<String, TextEditingController>> _outRows = [];

  // Motorcycle log rows
  final List<Map<String, TextEditingController>> _motoRows = [];

  // DA Bill rows (date auto, Friday-blocked, amount from designation)
  final List<Map<String, TextEditingController>> _daRows = [];
  final List<bool> _daAdminApproved = [];

  // Top Sheet controllers
  late Map<String, TextEditingController> _othersCtrl;
  bool _topSheetLoading = false;

  bool _saving = false;
  bool _pickingPhoto = false;

  bool get _isAdmin => widget.user?.isAdmin ?? false;

  static String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _applicantName = e?.applicantName ?? widget.user?.name ?? '';
    _designation   = e?.designation ?? widget.user?.designation ?? '';
    _zone          = e?.zone ?? widget.user?.zela ?? '';
    _month         = e?.month ?? _currentMonth();
    _motoRegCtrl   = TextEditingController(text: e?.motoRegNumber ?? '');

    _employeeNames = [
      if (_applicantName.isNotEmpty) _applicantName,
    ];
    _zoneOptions = _buildZoneOptions();
    _monthOptions = _buildMonthOptions();

    _othersCtrl = {
      for (final key in _otherKeys) key: TextEditingController(),
    };

    // Populate existing rows
    if (e != null) {
      switch (widget.type) {
        case ExpenseModel.typeTaBill:
          for (final r in e.taRows) {
            _addTaRow(init: r);
          }
          for (final r in e.motoServicingRows) {
            _addServRow(init: r);
          }
          break;
        case ExpenseModel.typeTaDaSheet:
          for (final r in e.tadaRows) {
            _addTadaRow(init: r);
          }
          break;
        case ExpenseModel.typeOutStation:
          for (final r in e.outStationRows) {
            _addOutRow(init: r);
          }
          break;
        case ExpenseModel.typeMotorcycle:
          for (final r in e.motoRows) {
            _addMotoRow(init: r);
          }
          for (final r in e.motoServicingRows) {
            _addServRow(init: r);
          }
          break;
        case ExpenseModel.typeOthersBill:
          for (final key in _otherKeys) {
            _othersCtrl[key]!.text =
                (e.othersBill[key] ?? '').toString();
          }
          break;
        case ExpenseModel.typeDa:
          for (final r in e.daRows) {
            _addDaRow(init: r);
          }
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
    if (_daRows.isEmpty && widget.type == ExpenseModel.typeDa) {
      _addDaRow();
    }

    _loadEmployees();
    _loadMotoReg();
    if (widget.type == ExpenseModel.typeOthersBill && e == null) {
      _loadTopSheet();
    }
  }

  List<String> _buildZoneOptions() {
    final zones = <String>{...WintechCatalog.zones, ...UserModel.zelaList};
    if (_zone.isNotEmpty) zones.add(_zone);
    final list = zones.toList()..sort();
    return list;
  }

  List<String> _buildMonthOptions() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    final list = <String>[];
    for (var i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      list.add('${months[d.month - 1]} ${d.year}');
    }
    if (_month.isNotEmpty && !list.contains(_month)) list.insert(0, _month);
    return list;
  }

  Future<void> _loadEmployees() async {
    final employees = await LocalStorageService.getAllEmployees();
    final names = <String>{
      if ((widget.user?.name ?? '').isNotEmpty) widget.user!.name,
      ...employees.map((e) => e.name),
    };
    if (_applicantName.isNotEmpty) names.add(_applicantName);
    if (!mounted) return;
    setState(() => _employeeNames = names.toList());
  }

  Future<void> _loadMotoReg() async {
    if (_motoRegCtrl.text.trim().isNotEmpty) return;
    final saved =
        await LocalStorageService.getMotoRegNumber(widget.user?.id ?? '');
    if (saved.isNotEmpty && mounted) {
      setState(() {
        _motoRegCtrl.text = saved;
        _motoRegSaved = true;
      });
    }
  }

  /// Auto-fill Top Sheet from ERP: previous dues, sales target/amount,
  /// achievement %, recovery amount, bill totals — all automatic.
  Future<void> _loadTopSheet() async {
    setState(() => _topSheetLoading = true);
    try {
      if (await ApiService.isConnected) {
        final ts = await ApiService.taDaTopSheet(month: _month);
        if (ts.isNotEmpty && mounted) {
          void put(String key, dynamic v) {
            if (v == null) return;
            final d = (v as num?)?.toDouble() ?? 0;
            _othersCtrl[key]?.text = d == 0 ? '' : _stripZeros(d);
          }

          put('previousDues',       ts['previousDues']);
          put('salesTarget',        ts['salesTarget']);
          put('salesAmount',        ts['salesAmount']);
          put('salesAchievement',   ts['salesAchievement']);
          put('recoveryAmount',     ts['recoveryAmount']);
          put('currentDues',        ts['currentDues']);
          put('tadaAmount',         ts['tadaAmount']);
          put('outStationBill',     ts['outStationBill']);
          final sales = (ts['salesAmount'] as num?)?.toDouble() ?? 0;
          final recovery = (ts['recoveryAmount'] as num?)?.toDouble() ?? 0;
          if (sales > 0) {
            _othersCtrl['salesRecoveryPercent']?.text =
                _stripZeros((recovery / sales) * 100);
          }
        }
      }
    } catch (_) {
      // Offline — keep manual entry.
    }
    if (mounted) setState(() => _topSheetLoading = false);
  }

  static String _stripZeros(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00')
        ? s.substring(0, s.length - 3)
        : (s.endsWith('0') ? s.substring(0, s.length - 1) : s);
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

  String _currentMonth() {
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
        // Date auto-filled with today for new rows
        'date':            TextEditingController(text: init?['date'] ?? _today()),
        'from':            TextEditingController(text: init?['from'] ?? ''),
        'to':              TextEditingController(text: init?['to'] ?? ''),
        'modeOfTransport': TextEditingController(text: init?['modeOfTransport'] ?? ''),
        'description':     TextEditingController(text: init?['description'] ?? ''),
        'amount':          TextEditingController(text: (init?['amount'] ?? '').toString()),
      });
    });
  }

  void _addServRow({Map<String, dynamic>? init}) {
    setState(() {
      _servRows.add({
        'date':          TextEditingController(text: init?['date'] ?? _today()),
        'description':   TextEditingController(text: init?['description'] ?? ''),
        'amount':        TextEditingController(text: (init?['amount'] ?? '').toString()),
        'supportingDoc': TextEditingController(text: init?['supportingDoc'] ?? ''),
      });
    });
  }

  void _addTadaRow({Map<String, dynamic>? init}) {
    setState(() {
      _tadaRows.add({
        'date':  TextEditingController(text: init?['date'] ?? _today()),
        'place': TextEditingController(text: init?['place'] ?? ''),
        'ta':    TextEditingController(text: (init?['ta'] ?? '').toString()),
        'da':    TextEditingController(text: (init?['da'] ?? '').toString()),
      });
    });
  }

  void _addOutRow({Map<String, dynamic>? init}) {
    setState(() {
      _outRows.add({
        'date':  TextEditingController(text: init?['date'] ?? _today()),
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
        'date':          TextEditingController(text: init?['date'] ?? _today()),
        'destination':   TextEditingController(text: init?['destination'] ?? ''),
        'purposes':      TextEditingController(text: init?['purposes'] ?? ''),
        'prevReading':   TextEditingController(text: (init?['prevReading'] ?? '').toString()),
        'latestReading': TextEditingController(text: (init?['latestReading'] ?? '').toString()),
        'petrol':        TextEditingController(text: (init?['petrol'] ?? '').toString()),
        'petrolAmount':  TextEditingController(text: (init?['petrolAmount'] ?? '').toString()),
        'octane':        TextEditingController(text: (init?['octane'] ?? '').toString()),
        'octaneAmount':  TextEditingController(text: (init?['octaneAmount'] ?? '').toString()),
        'mobil':         TextEditingController(text: (init?['mobil'] ?? '').toString()),
        'mobilAmount':   TextEditingController(text: (init?['mobilAmount'] ?? '').toString()),
        'othersAmount':  TextEditingController(text: (init?['othersAmount'] ?? '').toString()),
        'supportingDoc': TextEditingController(text: init?['supportingDoc'] ?? ''),
      });
    });
  }

  void _addDaRow({Map<String, dynamic>? init}) {
    // DA amount comes automatically from the selected designation
    final autoAmount = ExpenseModel.daByDesignation[_designation];
    setState(() {
      _daRows.add({
        'date':   TextEditingController(text: init?['date'] ?? _today()),
        'amount': TextEditingController(
            text: (init?['amount'] ?? (autoAmount ?? '')).toString()),
        'note':   TextEditingController(text: init?['note'] ?? ''),
      });
      _daAdminApproved.add(init?['adminApproved'] as bool? ?? false);
    });
  }

  @override
  void dispose() {
    _motoRegCtrl.dispose();
    for (final c in _othersCtrl.values) {
      c.dispose();
    }
    for (final rows in [_taRows, _tadaRows, _outRows, _motoRows, _servRows, _daRows]) {
      for (final r in rows) {
        for (final c in r.values) {
          c.dispose();
        }
      }
    }
    super.dispose();
  }

  double _dbl(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  bool _isFriday(String date) {
    final d = DateTime.tryParse(date);
    return d != null && d.weekday == DateTime.friday;
  }

  Future<void> _pickRowDate(TextEditingController ctrl,
      {bool blockFriday = false, int? daIndex}) async {
    final current = DateTime.tryParse(ctrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    if (blockFriday && picked.weekday == DateTime.friday && !_isAdmin) {
      final approved = daIndex != null &&
          daIndex < _daAdminApproved.length &&
          _daAdminApproved[daIndex];
      if (!approved) {
        _formSnack(
            'শুক্রবার DA বিল বন্ধ। স্পেশাল কাজের ক্ষেত্রে এডমিনের এপ্রোভাল প্রয়োজন।',
            error: true);
        return;
      }
    }
    setState(() => ctrl.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _captureDoc(TextEditingController docCtrl) async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 75,
      );
      if (picked != null && mounted) {
        setState(() => docCtrl.text = picked.path);
      }
    } catch (_) {
      // Camera-only policy: supporting documents must be captured live.
      if (mounted) {
        _formSnack('ক্যামেরা চালু করা যায়নি। সাপোর্টিং ডকুমেন্ট অবশ্যই ক্যামেরা দিয়ে তুলতে হবে।',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _formSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // ── Month lock: bills of a previous month need admin unlock ──────────
    final locked = ExpenseModel.isMonthLocked(_month);
    final adminUnlocked = widget.existing?.adminUnlocked ?? false;
    if (locked && !_isAdmin && !adminUnlocked) {
      _formSnack(
          'সিস্টেম লক: $_month-এর বিল জমার সময় শেষ। এডমিন আনলক করলে পুনরায় জমা দিতে পারবেন।',
          error: true);
      return;
    }

    // ── Mandatory supporting docs for fuel & servicing ────────────────────
    if (widget.type == ExpenseModel.typeMotorcycle) {
      for (var i = 0; i < _motoRows.length; i++) {
        final r = _motoRows[i];
        final hasFuel = _dbl(r['petrol']!) > 0 || _dbl(r['petrolAmount']!) > 0 ||
            _dbl(r['octane']!) > 0 || _dbl(r['octaneAmount']!) > 0 ||
            _dbl(r['mobil']!) > 0 || _dbl(r['mobilAmount']!) > 0 ||
            _dbl(r['othersAmount']!) > 0;
        if (hasFuel && r['supportingDoc']!.text.trim().isEmpty) {
          _formSnack(
              'Row ${i + 1}: পেট্রোল/অকটেন/মবিল বিলের সাপোর্টিং ডকুমেন্টের ছবি বাধ্যতামূলক।',
              error: true);
          return;
        }
      }
    }
    for (var i = 0; i < _servRows.length; i++) {
      final r = _servRows[i];
      if (_dbl(r['amount']!) > 0 && r['supportingDoc']!.text.trim().isEmpty) {
        _formSnack(
            'Servicing Row ${i + 1}: সাপোর্টিং ডকুমেন্টের ছবি বাধ্যতামূলক।',
            error: true);
        return;
      }
    }

    // ── Friday DA check ────────────────────────────────────────────────────
    if (widget.type == ExpenseModel.typeDa) {
      for (var i = 0; i < _daRows.length; i++) {
        if (_isFriday(_daRows[i]['date']!.text) &&
            !(_isAdmin || _daAdminApproved[i])) {
          _formSnack(
              'Row ${i + 1}: শুক্রবারের DA বিলের জন্য এডমিনের এপ্রোভাল প্রয়োজন।',
              error: true);
          return;
        }
      }
    }

    setState(() => _saving = true);

    // Save motorcycle registration number once per employee
    final motoReg = _motoRegCtrl.text.trim();
    if (motoReg.isNotEmpty && !_motoRegSaved) {
      await LocalStorageService.setMotoRegNumber(
          widget.user?.id ?? '', motoReg);
    }

    List<Map<String, dynamic>> taRows = [];
    List<Map<String, dynamic>> tadaRows = [];
    List<Map<String, dynamic>> outRows = [];
    List<Map<String, dynamic>> motoRows = [];
    List<Map<String, dynamic>> daRows = [];
    Map<String, dynamic> othersBill = {};

    final servRows = _servRows.map((r) => {
          'date': r['date']!.text,
          'description': r['description']!.text,
          'amount': _dbl(r['amount']!),
          'supportingDoc': r['supportingDoc']!.text,
        }).toList();

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
            'petrolAmount':  _dbl(r['petrolAmount']!),
            'octane':        _dbl(r['octane']!),
            'octaneAmount':  _dbl(r['octaneAmount']!),
            'mobil':         _dbl(r['mobil']!),
            'mobilAmount':   _dbl(r['mobilAmount']!),
            'othersAmount':  _dbl(r['othersAmount']!),
            'supportingDoc': r['supportingDoc']!.text,
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
        daRows = List.generate(_daRows.length, (i) {
          final r = _daRows[i];
          final d = DateTime.tryParse(r['date']!.text);
          return {
            'date':   r['date']!.text,
            'amount': _dbl(r['amount']!),
            'note':   r['note']!.text.trim(),
            'dayOfWeek': d == null ? '' : DateFormat('EEEE').format(d),
            'adminApproved': _daAdminApproved[i],
          };
        });
        break;
    }

    final model = ExpenseModel(
      id: widget.existing?.id ??
          'EXP-${DateTime.now().millisecondsSinceEpoch}',
      type: widget.type,
      month: _month,
      applicantName: _applicantName,
      designation: _designation,
      zone: _zone,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      status: widget.existing?.status ?? ExpenseModel.statusPending,
      srId: widget.user?.id ?? '',
      isLocked: locked,
      adminUnlocked: adminUnlocked,
      taRows: taRows,
      tadaRows: tadaRows,
      outStationRows: outRows,
      motoRows: motoRows,
      motoServicingRows: servRows,
      motoRegNumber: motoReg,
      daRows: daRows,
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
    final locked = ExpenseModel.isMonthLocked(_month) &&
        !_isAdmin &&
        !(widget.existing?.adminUnlocked ?? false);

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
            if (locked) _lockBanner(),
            // Common header fields — all dropdowns
            _sectionCard(isDark, children: [
              _dropdownField(
                'Applicant / Employee Name',
                value: _applicantName.isEmpty ? null : _applicantName,
                items: _employeeNames,
                onChanged: (v) => setState(() => _applicantName = v ?? ''),
              ),
              const SizedBox(height: 12),
              _dropdownField(
                'Employee Designation',
                value: ExpenseModel.designationList.contains(_designation)
                    ? _designation
                    : (_designation.isEmpty ? null : _designation),
                items: [
                  ...ExpenseModel.designationList,
                  if (_designation.isNotEmpty &&
                      !ExpenseModel.designationList.contains(_designation))
                    _designation,
                ],
                onChanged: (v) {
                  setState(() {
                    _designation = v ?? '';
                    // DA amount auto-updates from designation
                    final auto = ExpenseModel.daByDesignation[_designation];
                    if (auto != null) {
                      for (final r in _daRows) {
                        r['amount']!.text = _stripZeros(auto);
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _dropdownField(
                'Zone',
                value: _zoneOptions.contains(_zone) ? _zone : null,
                items: _zoneOptions,
                onChanged: (v) => setState(() => _zone = v ?? ''),
              ),
              const SizedBox(height: 12),
              _dropdownField(
                'Month',
                value: _monthOptions.contains(_month) ? _month : null,
                items: _monthOptions,
                onChanged: (v) => setState(() => _month = v ?? ''),
              ),
            ]),
            const SizedBox(height: 16),

            // Type-specific rows
            ..._buildTypeFields(isDark),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_saving || locked) ? null : _submit,
              child: Text(
                  locked
                      ? 'Locked — Admin unlock required'
                      : (widget.existing == null ? 'Save' : 'Update'),
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  Widget _lockBanner() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.lock_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                '$_month-এর বিল সাবমিট লক হয়ে গেছে। এডমিন আনলক করলে জমা দিতে পারবেন।',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error)),
          ),
        ]),
      );

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
        return _buildTopSheetFields(isDark);
      case ExpenseModel.typeDa:
        return _buildDaFields(isDark);
      default:
        return [];
    }
  }

  // ── TA Bill (with From/To + Motorcycle Servicing Bill) ────────────────
  List<Widget> _buildTaBillFields(bool isDark) {
    return [
      _motoRegField(isDark),
      const SizedBox(height: 8),
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
          _dateField('Date', r['date']!),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field('From', r['from']!)),
            const SizedBox(width: 8),
            Expanded(child: _field('To', r['to']!)),
          ]),
          const SizedBox(height: 8),
          _field('Transport', r['modeOfTransport']!),
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
      const SizedBox(height: 8),
      ..._buildServicingSection(isDark),
    ];
  }

  // ── Motorcycle Servicing Bill (attached to TA bill & motorcycle log) ──
  List<Widget> _buildServicingSection(bool isDark) {
    return [
      Row(children: [
        Text('Motorcycle Servicing Bill',
            style: GoogleFonts.hindSiliguri(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(
          onPressed: _addServRow,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Add', style: GoogleFonts.hindSiliguri(fontSize: 12)),
        ),
      ]),
      if (_servRows.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('No servicing bill added',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 12, color: AppTheme.textGrey)),
        ),
      ..._servRows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        return _sectionCard(isDark, children: [
          Row(children: [
            Text('Servicing ${i + 1}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                for (final c in _servRows[i].values) {
                  c.dispose();
                }
                _servRows.removeAt(i);
              }),
              child: const Icon(Icons.remove_circle_outline_rounded,
                  size: 18, color: AppTheme.error),
            ),
          ]),
          const SizedBox(height: 8),
          _dateField('Date', r['date']!),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(flex: 2, child: _field('Description', r['description']!)),
            const SizedBox(width: 8),
            Expanded(child: _field('Amount (৳)', r['amount']!,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 8),
          _docPicker(r['supportingDoc']!,
              required: _dbl(r['amount']!) > 0),
        ]);
      }),
      if (_servRows.isNotEmpty)
        _totalRow('Servicing Total',
            _servRows.fold(0.0, (s, r) => s + _dbl(r['amount']!))),
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
            Expanded(child: _dateField('Date', r['date']!)),
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
          _dateField('Date', r['date']!),
          const SizedBox(height: 8),
          Row(children: [
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
      _motoRegField(isDark),
      const SizedBox(height: 8),
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
        final fuelTotal = _dbl(r['petrolAmount']!) +
            _dbl(r['octaneAmount']!) +
            _dbl(r['mobilAmount']!) +
            _dbl(r['othersAmount']!);
        final needsDoc = fuelTotal > 0 ||
            _dbl(r['petrol']!) > 0 ||
            _dbl(r['octane']!) > 0 ||
            _dbl(r['mobil']!) > 0;
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
            Expanded(child: _dateField('Date', r['date']!)),
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
                Text(_fmt.format(km < 0 ? 0 : km),
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryAccent)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          // Fuel: liter + amount pairs
          Row(children: [
            Expanded(
                child: _field('Petrol (L)', r['petrol']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
                child: _field('Petrol Amount (৳)', r['petrolAmount']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _field('Octane (L)', r['octane']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
                child: _field('Octane Amount (৳)', r['octaneAmount']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _field('Mobil (L)', r['mobil']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
                child: _field('Mobil Amount (৳)', r['mobilAmount']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 8),
          _field('Others Amount (৳)', r['othersAmount']!,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {})),
          if (fuelTotal > 0) ...[
            const SizedBox(height: 6),
            Text('Fuel Total: ৳ ${_fmt.format(fuelTotal)}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryAccent)),
          ],
          const SizedBox(height: 8),
          _docPicker(r['supportingDoc']!, required: needsDoc),
        ]);
      }),
      _totalRow(
          'Total Fuel Bill',
          _motoRows.fold(
              0.0,
              (s, r) =>
                  s +
                  _dbl(r['petrolAmount']!) +
                  _dbl(r['octaneAmount']!) +
                  _dbl(r['mobilAmount']!) +
                  _dbl(r['othersAmount']!))),
      const SizedBox(height: 8),
      ..._buildServicingSection(isDark),
    ];
  }

  // ── TA/DA Top Sheet (auto-generated) ─────────────────────────────────
  List<Widget> _buildTopSheetFields(bool isDark) {
    return [
      Row(children: [
        Text('TA/DA Top Sheet',
            style: GoogleFonts.hindSiliguri(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (_topSheetLoading)
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
        else
          TextButton.icon(
            onPressed: _loadTopSheet,
            icon: const Icon(Icons.sync_rounded, size: 16),
            label: Text('Auto-fill',
                style: GoogleFonts.hindSiliguri(fontSize: 12)),
          ),
      ]),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
            'Previous dues, sales target, sales amount, achievement, recovery — সব ERP থেকে স্বয়ংক্রিয়ভাবে চলে আসবে।',
            style: GoogleFonts.hindSiliguri(
                fontSize: 11, color: AppTheme.textGrey)),
      ),
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

  // ── DA Bill (auto date, Friday-blocked, amount from designation) ─────
  List<Widget> _buildDaFields(bool isDark) {
    final autoAmount = ExpenseModel.daByDesignation[_designation];
    return [
      Row(children: [
        Text('DA Bill',
            style: GoogleFonts.hindSiliguri(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(
          onPressed: _addDaRow,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Add Day', style: GoogleFonts.hindSiliguri(fontSize: 12)),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
            autoAmount != null
                ? 'Designation অনুযায়ী DA: ৳ ${_stripZeros(autoAmount)}/দিন। শুক্রবার DA বন্ধ (এডমিন এপ্রোভাল ছাড়া)।'
                : 'Designation সিলেক্ট করলে DA amount অটোমেটিক চলে আসবে। শুক্রবার DA বন্ধ।',
            style: GoogleFonts.hindSiliguri(
                fontSize: 11, color: AppTheme.textGrey)),
      ),
      ..._daRows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        final friday = _isFriday(r['date']!.text);
        return _sectionCard(isDark, children: [
          Row(children: [
            Text('Day ${i + 1}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGrey)),
            if (friday) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('Friday',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.error)),
              ),
            ],
            const Spacer(),
            if (_daRows.length > 1)
              GestureDetector(
                onTap: () => setState(() {
                  for (final c in _daRows[i].values) {
                    c.dispose();
                  }
                  _daRows.removeAt(i);
                  _daAdminApproved.removeAt(i);
                }),
                child: const Icon(Icons.remove_circle_outline_rounded,
                    size: 18, color: AppTheme.error),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _dateField('Date', r['date']!,
                    blockFriday: true, daIndex: i)),
            const SizedBox(width: 8),
            Expanded(
                child: _field('DA Amount (৳)', r['amount']!,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 8),
          _field('Note', r['note']!),
          if (friday && _isAdmin) ...[
            const SizedBox(height: 8),
            Row(children: [
              Checkbox(
                value: _daAdminApproved[i],
                onChanged: (v) =>
                    setState(() => _daAdminApproved[i] = v ?? false),
              ),
              Expanded(
                child: Text('Admin approval — শুক্রবারের স্পেশাল কাজ অনুমোদিত',
                    style: GoogleFonts.hindSiliguri(fontSize: 12)),
              ),
            ]),
          ],
        ]);
      }),
      _totalRow('Total DA',
          _daRows.fold(0.0, (s, r) => s + _dbl(r['amount']!))),
    ];
  }

  // ── Motorcycle registration number ────────────────────────────────────
  Widget _motoRegField(bool isDark) {
    return _sectionCard(isDark, children: [
      Row(children: [
        const Icon(Icons.two_wheeler_rounded,
            size: 18, color: Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Text('Motorcycle Registration Number',
            style: GoogleFonts.hindSiliguri(
                fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 4),
      Text(
          _motoRegSaved
              ? 'সংরক্ষিত নম্বর অটোমেটিক অ্যাড হয়েছে'
              : 'একবার লিখলেই পরবর্তীতে অটোমেটিক অ্যাড হয়ে যাবে',
          style: GoogleFonts.hindSiliguri(
              fontSize: 11, color: AppTheme.textGrey)),
      const SizedBox(height: 8),
      _field('Registration No. (e.g. DHAKA METRO HA 12-3456)', _motoRegCtrl),
    ]);
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

  InputDecoration _inputDecoration() => InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.divider, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppTheme.primaryAccent, width: 2)),
      );

  Widget _dropdownField(String label,
      {String? value,
      required List<String> items,
      required ValueChanged<String?> onChanged}) {
    final unique = items.toSet().toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.hindSiliguri(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey)),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        value: value != null && unique.contains(value) ? value : null,
        isExpanded: true,
        decoration: _inputDecoration(),
        style: GoogleFonts.hindSiliguri(
            fontSize: 13,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkText
                : AppTheme.textDark),
        hint: Text('Select $label',
            style: GoogleFonts.hindSiliguri(
                fontSize: 12, color: AppTheme.textGrey)),
        items: unique
            .map((v) => DropdownMenuItem(
                value: v,
                child: Text(v,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hindSiliguri(fontSize: 13))))
            .toList(),
        onChanged: onChanged,
      ),
    ]);
  }

  Widget _dateField(String label, TextEditingController ctrl,
      {bool blockFriday = false, int? daIndex}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.hindSiliguri(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey)),
      const SizedBox(height: 4),
      InkWell(
        onTap: () =>
            _pickRowDate(ctrl, blockFriday: blockFriday, daIndex: daIndex),
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: _inputDecoration(),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: AppTheme.textGrey),
            const SizedBox(width: 8),
            Text(ctrl.text.isEmpty ? 'Select date' : ctrl.text,
                style: GoogleFonts.hindSiliguri(fontSize: 13)),
          ]),
        ),
      ),
    ]);
  }

  Widget _docPicker(TextEditingController docCtrl, {bool required = false}) {
    final hasDoc = docCtrl.text.trim().isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Supporting Document',
            style: GoogleFonts.hindSiliguri(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey)),
        if (required) ...[
          const SizedBox(width: 4),
          Text('(বাধ্যতামূলক)',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.error)),
        ],
      ]),
      const SizedBox(height: 6),
      Row(children: [
        if (hasDoc)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(docCtrl.text),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: AppTheme.divider,
                child: const Icon(Icons.image_rounded,
                    size: 22, color: AppTheme.textGrey),
              ),
            ),
          )
        else
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: (required ? AppTheme.error : AppTheme.divider)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: required
                      ? AppTheme.error.withValues(alpha: 0.4)
                      : AppTheme.divider),
            ),
            child: Icon(Icons.receipt_long_rounded,
                size: 22,
                color: required ? AppTheme.error : AppTheme.textGrey),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _pickingPhoto ? null : () => _captureDoc(docCtrl),
                  icon: _pickingPhoto
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_camera_rounded, size: 17),
                  label: Text(hasDoc ? 'Retake Photo' : 'Take Photo',
                      style: GoogleFonts.hindSiliguri(fontSize: 12)),
                ),
                if (hasDoc)
                  TextButton(
                    onPressed: () => setState(() => docCtrl.clear()),
                    child: Text('Remove',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 11, color: AppTheme.error)),
                  ),
              ]),
        ),
      ]),
    ]);
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
          decoration: _inputDecoration(),
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
