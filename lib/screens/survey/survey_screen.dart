import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/survey_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/offline_queue_service.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  String _tab = SurveyModel.typeFarmer;
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _loading = true;
  bool _erpConnected = false;
  List<SurveyModel> _surveys = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final local = await LocalStorageService.getSurveys();
    var all = local;
    var erp = false;

    // ERP-first: fetch live surveys, merge with local-only records.
    if (await ApiService.isConnected) {
      try {
        final data = await ApiService.surveys();
        final remote = data.map((m) {
          final map = Map<String, dynamic>.from(m);
          map['id'] ??= map['_id']?.toString();
          return SurveyModel.fromMap(map);
        }).toList();
        final remoteIds = remote.map((s) => s.id).toSet();
        all = [
          ...remote,
          ...local.where((s) => !remoteIds.contains(s.id)),
        ];
        erp = true;
      } catch (_) {
        // Offline or endpoint unavailable — keep local data.
      }
    }

    if (!mounted) return;
    setState(() {
      _surveys = all;
      _erpConnected = erp;
      _loading = false;
    });
  }

  List<SurveyModel> get _filtered {
    final query = _search.trim().toLowerCase();
    return _surveys.where((survey) {
      if (survey.type != _tab) return false;
      final date = DateTime.tryParse(survey.visitDate);
      if (date == null) return false;
      if (_fromDate != null && date.isBefore(_dayStart(_fromDate!))) {
        return false;
      }
      if (_toDate != null && date.isAfter(_dayEnd(_toDate!))) return false;
      if (query.isEmpty) return true;
      final text = [
        survey.workerName,
        survey.postingId,
        survey.farmName,
        survey.farmerMobile,
        survey.village,
        survey.shopName,
        survey.dealerName,
        survey.dealerMobile,
        survey.bazarName,
        survey.wintechStock,
        survey.competitorProduct,
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  DateTime _dayStart(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _dayEnd(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59);

  int get _farmerCount =>
      _surveys.where((survey) => survey.type == SurveyModel.typeFarmer).length;

  int get _dealerCount =>
      _surveys.where((survey) => survey.type == SurveyModel.typeDealer).length;

  int get _monthCount {
    final now = DateTime.now();
    return _filtered.where((survey) {
      final date = DateTime.tryParse(survey.visitDate);
      return date?.year == now.year && date?.month == now.month;
    }).length;
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: from ? 'Select Start Date' : 'Select End Date',
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _openForm({SurveyModel? editing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SurveyFormDialog(
        type: editing?.type ?? _tab,
        existing: editing,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(SurveyModel survey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Record?',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text(
          'This ${survey.type == SurveyModel.typeFarmer ? 'farmer' : 'dealer'} visit record cannot be recovered.',
          style: GoogleFonts.hindSiliguri(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalStorageService.deleteSurvey(survey.id);
    if (!mounted) return;
    _load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Survey record deleted',
            style: GoogleFonts.hindSiliguri()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _view(SurveyModel survey) {
    showDialog<void>(
      context: context,
      builder: (_) => _SurveyDetailsDialog(survey: survey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _tab == SurveyModel.typeFarmer ? 'Farmer Visit' : 'Dealer Visit';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppTheme.primaryAccent,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(isDark)),
            SliverToBoxAdapter(child: _summary(isDark)),
            SliverToBoxAdapter(child: _filters(isDark)),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryAccent),
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _empty(title))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _SurveyCard(
                      survey: _filtered[index],
                      onView: () => _view(_filtered[index]),
                      onEdit: () => _openForm(editing: _filtered[index]),
                      onDelete: () => _delete(_filtered[index]),
                    ),
                    childCount: _filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add $title',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _header(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryAccent, Color(0xFF0874A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 22),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.assignment_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Field Survey',
                    style: GoogleFonts.hindSiliguri(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Row(children: [
                  Icon(
                      _erpConnected
                          ? Icons.cloud_done_rounded
                          : Icons.wifi_off_rounded,
                      size: 12,
                      color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(_erpConnected ? 'ERP সংযুক্ত' : 'অফলাইন মোড',
                      style: GoogleFonts.hindSiliguri(
                          color: Colors.white70, fontSize: 12)),
                ]),
              ],
            ),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _summary(bool isDark) {
    final cards = [
      ('Farmer Visits', '$_farmerCount', Icons.grass_rounded, const Color(0xFF2E9B67)),
      ('Dealer Visits', '$_dealerCount', Icons.storefront_rounded, const Color(0xFF2477C5)),
      ('Shown', '${_filtered.length}', Icons.assignment_rounded, const Color(0xFF7B4FC9)),
      ('This Month', '$_monthCount', Icons.calendar_month_rounded, AppTheme.warning),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, index) {
            final card = cards[index];
            return Container(
              width: 142,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: card.$4.withValues(alpha: 0.12),
                    blurRadius: 9,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: card.$4.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(card.$3, color: card.$4, size: 17),
                  ),
                  const Spacer(),
                  Text(card.$2,
                      style: GoogleFonts.hindSiliguri(
                          color: card.$4,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                  Text(card.$1,
                      style: GoogleFonts.hindSiliguri(
                          color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                          fontSize: 10)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filters(bool isDark) {
    final selectedColor = isDark ? AppTheme.darkCard2 : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: const InputDecoration(
                    hintText: 'Search officer, name or shop',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showDateFilters(),
                style: IconButton.styleFrom(
                  backgroundColor: (_fromDate != null || _toDate != null)
                      ? AppTheme.lightAccent
                      : selectedColor,
                  foregroundColor: AppTheme.primaryAccent,
                ),
                icon: const Icon(Icons.filter_alt_rounded),
                tooltip: 'Date Filter',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : const Color(0xFFE5F1F7),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                _tabButton('farmer', 'Farmer Visit', Icons.grass_rounded),
                _tabButton('dealer', 'Dealer Visit', Icons.storefront_rounded),
              ],
            ),
          ),
          if (_fromDate != null || _toDate != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Wrap(
                  spacing: 6,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.date_range_rounded, size: 15),
                      label: Text(
                        '${_fromDate == null ? 'No start' : DateFormat('dd/MM/yy').format(_fromDate!)} — ${_toDate == null ? 'No end' : DateFormat('dd/MM/yy').format(_toDate!)}',
                        style: GoogleFonts.hindSiliguri(fontSize: 11),
                      ),
                      onDeleted: () => setState(() {
                        _fromDate = null;
                        _toDate = null;
                      }),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabButton(String value, String label, IconData icon) {
    final selected = _tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: selected ? Colors.white : AppTheme.textGrey),
              const SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.hindSiliguri(
                      color: selected ? Colors.white : AppTheme.textGrey,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDateFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by Date',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(from: true),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(_fromDate == null
                        ? 'Start'
                        : DateFormat('dd MMM yyyy').format(_fromDate!)),
                  ),
                ),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('to')),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(from: false),
                    icon: const Icon(Icons.event_rounded, size: 16),
                    label: Text(_toDate == null
                        ? 'End'
                        : DateFormat('dd MMM yyyy').format(_toDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _fromDate = null;
                    _toDate = null;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Clear Filter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _tab == SurveyModel.typeFarmer
                  ? Icons.grass_rounded
                  : Icons.storefront_rounded,
              size: 56,
              color: AppTheme.primaryAccent.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text('No $title found',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Tap the button below to add a new visit record',
                textAlign: TextAlign.center,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12, color: AppTheme.textGrey)),
          ],
        ),
      ),
    );
  }
}

class _SurveyCard extends StatelessWidget {
  final SurveyModel survey;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SurveyCard({
    required this.survey,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isFarmer = survey.type == SurveyModel.typeFarmer;
    final accent = isFarmer ? const Color(0xFF2E9B67) : const Color(0xFF2477C5);
    final name = isFarmer
        ? (survey.farmName.isEmpty ? 'Farmer name not provided' : survey.farmName)
        : (survey.shopName.isEmpty ? 'Shop name not provided' : survey.shopName);
    final person = isFarmer ? survey.farmerMobile : survey.dealerName;
    final location = isFarmer ? survey.village : survey.bazarName;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(isFarmer ? Icons.grass_rounded : Icons.storefront_rounded,
                    color: accent, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                        Text(_formatDate(survey.visitDate),
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 10, color: AppTheme.textGrey)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        survey.workerName.isEmpty ? 'No officer' : survey.workerName,
                        if (person.isNotEmpty) person,
                        if (location.isNotEmpty) location,
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12, color: AppTheme.textGrey),
                    ),
                    if (isFarmer && survey.wintechProducts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: survey.wintechProducts.take(3).map((product) {
                            return _tag(product, accent);
                          }).toList(),
                        ),
                      ),
                    if (!isFarmer &&
                        (survey.wintechStock.isNotEmpty ||
                            survey.collectionAmount != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Row(
                          children: [
                            if (survey.wintechStock.isNotEmpty)
                              _tag('Stock: ${survey.wintechStock}', accent),
                            if (survey.collectionAmount != null) ...[
                              const SizedBox(width: 5),
                              _tag(
                                  '৳${NumberFormat('#,##0').format(survey.collectionAmount)}',
                                  AppTheme.success),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'view') onView();
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'view', child: Text('View Details')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _tag(String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.hindSiliguri(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );

  static String _formatDate(String raw) {
    final date = DateTime.tryParse(raw);
    return date == null ? raw : DateFormat('dd MMM yyyy').format(date);
  }
}

class _SurveyFormDialog extends StatefulWidget {
  final String type;
  final SurveyModel? existing;

  const _SurveyFormDialog({required this.type, this.existing});

  @override
  State<_SurveyFormDialog> createState() => _SurveyFormDialogState();
}

class _SurveyFormDialogState extends State<_SurveyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late String _visitDate;
  bool _saving = false;
  List<UserModel> _employees = [];
  final _worker = TextEditingController();
  final _posting = TextEditingController();
  final _farmName = TextEditingController();
  final _farmerMobile = TextEditingController();
  final _village = TextEditingController();
  final _diseases = TextEditingController();
  final _prescription = TextEditingController();
  final _shopName = TextEditingController();
  final _dealerName = TextEditingController();
  final _dealerMobile = TextEditingController();
  final _bazarName = TextEditingController();
  final _competitor = TextEditingController();
  final _collection = TextEditingController();
  final _remarks = TextEditingController();
  List<String> _products = [];
  String _stock = '';
  String _photo = '';
  bool _pickingPhoto = false;

  static const _productOptions = [
    'Wintech Grow',
    'Wintech Gold',
    'Agro Plus',
    'Crop Care',
    'Poultry Care',
    'Fish Care',
  ];

  @override
  void initState() {
    super.initState();
    final survey = widget.existing;
    _type = survey?.type ?? widget.type;
    _visitDate = survey?.visitDate ?? _dateOnly(DateTime.now());
    _worker.text = survey?.workerName ?? '';
    _posting.text = survey?.postingId ?? '';
    _farmName.text = survey?.farmName ?? '';
    _farmerMobile.text = survey?.farmerMobile ?? '';
    _village.text = survey?.village ?? '';
    _diseases.text = survey?.diseases ?? '';
    _prescription.text = survey?.prescription ?? '';
    _shopName.text = survey?.shopName ?? '';
    _dealerName.text = survey?.dealerName ?? '';
    _dealerMobile.text = survey?.dealerMobile ?? '';
    _bazarName.text = survey?.bazarName ?? '';
    _competitor.text = survey?.competitorProduct ?? '';
    _collection.text =
        survey?.collectionAmount == null ? '' : '${survey!.collectionAmount}';
    _remarks.text = survey?.remarks ?? '';
    _stock = survey?.wintechStock ?? '';
    _products = [...(survey?.wintechProducts ?? [])];
    _photo = survey?.photo ?? '';
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final employees = await LocalStorageService.getAllEmployees();
    final currentUser = await LocalStorageService.getCurrentUser();
    if (currentUser != null &&
        currentUser.isEmployee &&
        !employees.any((employee) => employee.id == currentUser.id)) {
      employees.insert(0, currentUser);
    }
    if (!mounted) return;
    setState(() => _employees = employees.where((e) => e.isEmployee).toList());
  }

  @override
  void dispose() {
    for (final controller in [
      _worker,
      _posting,
      _farmName,
      _farmerMobile,
      _village,
      _diseases,
      _prescription,
      _shopName,
      _dealerName,
      _dealerMobile,
      _bazarName,
      _competitor,
      _collection,
      _remarks,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _dateOnly(DateTime value) =>
      DateFormat('yyyy-MM-dd').format(value);

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_visitDate) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _visitDate = _dateOnly(date));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == SurveyModel.typeFarmer &&
        _farmName.text.trim().isEmpty &&
        _farmerMobile.text.trim().isEmpty) {
      _message('Please enter farm name or mobile number');
      return;
    }
    if (_type == SurveyModel.typeDealer && _shopName.text.trim().isEmpty) {
      _message('Please enter shop name');
      return;
    }
    setState(() => _saving = true);
    final existing = widget.existing;
    final amount = double.tryParse(_collection.text.trim());
    final survey = SurveyModel(
      id: existing?.id ?? 'SUR-${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      workerName: _worker.text.trim(),
      postingId: _posting.text.trim(),
      visitDate: _visitDate,
      farmName: _farmName.text.trim(),
      farmerMobile: _farmerMobile.text.trim(),
      village: _village.text.trim(),
      diseases: _diseases.text.trim(),
      wintechProducts: _products,
      prescription: _prescription.text.trim(),
      shopName: _shopName.text.trim(),
      dealerName: _dealerName.text.trim(),
      dealerMobile: _dealerMobile.text.trim(),
      bazarName: _bazarName.text.trim(),
      wintechStock: _stock,
      competitorProduct: _competitor.text.trim(),
      collectionAmount: amount,
      remarks: _remarks.text.trim(),
      photo: _photo,
      createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
    );
    await LocalStorageService.saveSurvey(survey);
    // Only push brand-new surveys to the ERP (edits stay local).
    if (existing == null) {
      var sent = false;
      if (await ApiService.isConnected) {
        try {
          await ApiService.createSurvey(survey.toMap());
          sent = true;
          // The survey now lives in the ERP (with a server id) —
          // drop the local copy so it doesn't show up twice.
          await LocalStorageService.deleteSurvey(survey.id);
        } catch (_) {}
      }
      if (!sent) {
        await OfflineQueueService.enqueueSurvey(survey.toMap());
      }
      if (mounted) {
        _message(sent
            ? '✅ সার্ভে ERP-তে জমা হয়েছে!'
            : '📥 অফলাইন — sync হলে ERP-তে যাবে');
      }
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.hindSiliguri())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFarmer = _type == SurveyModel.typeFarmer;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${widget.existing == null ? 'New' : 'Edit'} ${isFarmer ? 'Farmer' : 'Dealer'} Visit',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('Visit Info'),
                Row(
                  children: [
                    Expanded(child: _workerField()),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(_posting, 'Posting / ID',
                          hint: 'Officer ID'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Visit Date',
                        prefixIcon: Icon(Icons.calendar_today_rounded)),
                    child: Text(_visitDate),
                  ),
                ),
                const SizedBox(height: 16),
                _section(isFarmer ? 'Farmer Info' : 'Shop / Dealer Info'),
                if (isFarmer) ...[
                  Row(
                    children: [
                      Expanded(child: _field(_farmName, 'Farm / Farmer Name')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_farmerMobile, 'Mobile / WhatsApp',
                          keyboard: TextInputType.phone)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _field(_village, 'Village / Union'),
                  const SizedBox(height: 10),
                  _field(_diseases, 'New Disease / Problem',
                      maxLines: 2, required: false),
                  const SizedBox(height: 14),
                  Text('Wintech products used',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    children: _productOptions.map((product) {
                      final selected = _products.contains(product);
                      return FilterChip(
                        selected: selected,
                        label: Text(product,
                            style: GoogleFonts.hindSiliguri(fontSize: 11)),
                        onSelected: (value) => setState(() {
                          if (value) {
                            _products.add(product);
                          } else {
                            _products.remove(product);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  _field(_prescription, 'Prescription / Recommendation',
                      maxLines: 3, required: false),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                          child: _field(_shopName, 'Shop Name',
                              required: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_dealerName, 'Dealer Name')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _field(_dealerMobile, 'Mobile / WhatsApp',
                              keyboard: TextInputType.phone)),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_bazarName, 'Market / Bazar')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _stock.isEmpty ? null : _stock,
                    decoration: const InputDecoration(
                        labelText: 'Wintech Stock Level'),
                    items: const [
                      DropdownMenuItem(value: 'High', child: Text('High — Adequate')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium — Moderate')),
                      DropdownMenuItem(value: 'Low', child: Text('Low — Scarce')),
                      DropdownMenuItem(value: 'None', child: Text('None — Out of stock')),
                    ],
                    onChanged: (value) => setState(() => _stock = value ?? ''),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _field(_competitor, 'Competitor product')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(_collection, 'Collection (৳)',
                            keyboard: const TextInputType.numberWithOptions(
                                decimal: true)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _field(_remarks, 'Remarks', maxLines: 3, required: false),
                ],
                const SizedBox(height: 14),
                _section('Photo (Optional)'),
                _photoPicker(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(widget.existing == null ? 'Save Visit' : 'Update'),
        ),
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: GoogleFonts.hindSiliguri(
                color: AppTheme.primaryAccent,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      );

  Widget _photoPicker() {
    final hasPhoto = _photo.trim().isNotEmpty;
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppTheme.lightAccent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppTheme.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasPhoto
              ? Image.file(
                  File(_photo),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.textGrey,
                      size: 25),
                )
              : const Icon(Icons.photo_camera_outlined,
                  color: AppTheme.primaryAccent, size: 27),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _pickingPhoto ? null : _pickPhoto,
                icon: _pickingPhoto
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_a_photo_rounded, size: 17),
                label: Text(hasPhoto ? 'Change Photo' : 'Add Photo'),
              ),
              if (hasPhoto)
                TextButton(
                  onPressed: () => setState(() => _photo = ''),
                  child: const Text('Remove Photo'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    setState(() => _pickingPhoto = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Take with Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1600,
      );
      if (picked != null && mounted) setState(() => _photo = picked.path);
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Widget _workerField() {
    return DropdownButtonFormField<String>(
      value: _employees.any((e) => e.name == _worker.text) ? _worker.text : null,
      decoration: const InputDecoration(labelText: 'Officer Name *'),
      hint: const Text('Select Officer'),
      items: _employees
          .map((employee) =>
              DropdownMenuItem(value: employee.name, child: Text(employee.name)))
          .toList(),
      onChanged: (value) => setState(() => _worker.text = value ?? ''),
      validator: (_) => _worker.text.trim().isEmpty ? 'Required' : null,
    );
  }

  Widget _field(TextEditingController controller, String label,
      {String? hint,
      TextInputType? keyboard,
      int maxLines = 1,
      bool required = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: required ? '$label *' : label, hintText: hint),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    );
  }
}

class _SurveyDetailsDialog extends StatelessWidget {
  final SurveyModel survey;

  const _SurveyDetailsDialog({required this.survey});

  @override
  Widget build(BuildContext context) {
    final isFarmer = survey.type == SurveyModel.typeFarmer;
    final items = <MapEntry<String, String>>[
      MapEntry('Officer', survey.workerName),
      MapEntry('Posting / ID', survey.postingId),
      MapEntry('Visit Date', _SurveyCard._formatDate(survey.visitDate)),
      if (isFarmer) ...[
        MapEntry('Farm / Farmer Name', survey.farmName),
        MapEntry('Mobile', survey.farmerMobile),
        MapEntry('Village / Union', survey.village),
        MapEntry('Disease / Problem', survey.diseases),
        MapEntry('Products Used', survey.wintechProducts.join(', ')),
        MapEntry('Recommendation', survey.prescription),
      ] else ...[
        MapEntry('Shop Name', survey.shopName),
        MapEntry('Dealer Name', survey.dealerName),
        MapEntry('Mobile', survey.dealerMobile),
        MapEntry('Market / Bazar', survey.bazarName),
        MapEntry('Wintech stock', survey.wintechStock),
        MapEntry('Competitor product', survey.competitorProduct),
        MapEntry('Collection', survey.collectionAmount == null
            ? ''
            : '৳${NumberFormat('#,##0').format(survey.collectionAmount)}'),
        MapEntry('Remarks', survey.remarks),
      ],
    ];
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(isFarmer ? 'Farmer Visit Details' : 'Dealer Visit Details',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w800)),
          ),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (survey.photo.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(survey.photo),
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 70,
                        alignment: Alignment.center,
                        color: AppTheme.lightAccent,
                        child: Text('Photo no longer available on this device',
                            style: GoogleFonts.hindSiliguri(
                                color: AppTheme.textGrey, fontSize: 12)),
                      ),
                    ),
                  ),
                ),
              ...items
                  .where((item) => item.value.trim().isNotEmpty)
                  .map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 125,
                              child: Text(item.key,
                                  style: GoogleFonts.hindSiliguri(
                                      color: AppTheme.textGrey, fontSize: 12)),
                            ),
                            Expanded(
                              child: Text(item.value,
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      )),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
