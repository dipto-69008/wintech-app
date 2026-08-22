import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../data/wintech_catalog.dart';
import '../../../models/survey_model.dart';
import '../../../services/api_service.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/offline_queue_service.dart';

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
                  Text(_erpConnected ? 'ERP Connected' : 'Offline Mode',
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
    return date == null
        ? raw
        : DateFormat('dd MMM yyyy · hh:mm a').format(date);
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
  List<String> _photos = [];
  bool _pickingPhoto = false;
  static const int _maxPhotos = 5;

  // Dealer visit: zone-based party selection
  String _dealerZone = '';
  List<Map<String, dynamic>> _erpParties = [];

  /// Full Wintech product list from the official catalog (dropdown source)
  static final List<String> _productOptions = () {
    final set = <String>{};
    for (final p in WintechCatalog.products) {
      set.add(p['name'] as String);
    }
    final list = set.toList()..sort();
    return list;
  }();

  static List<String> get _zoneOptions => WintechCatalog.zones;

  /// Parties of the selected zone (ERP list merged with local catalog)
  List<String> get _zoneParties {
    final names = <String>{};
    for (final p in _erpParties) {
      final zone = (p['zone'] ?? p['area'] ?? '').toString();
      if (_dealerZone.isEmpty || zone == _dealerZone) {
        names.add((p['name'] ?? '').toString());
      }
    }
    for (final p in WintechCatalog.parties) {
      if (_dealerZone.isEmpty || p['zone'] == _dealerZone) {
        names.add(p['name'] as String);
      }
    }
    names.remove('');
    final list = names.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    final survey = widget.existing;
    _type = survey?.type ?? widget.type;
    _visitDate = survey?.visitDate ?? _dhakaNow().toIso8601String();
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
    _photos = [...(survey?.photos ?? [])];
    _loadParties();
  }

  /// Fetch live parties from the ERP for zone-wise dealer dropdown.
  Future<void> _loadParties() async {
    try {
      if (await ApiService.isConnected) {
        final data = await ApiService.parties(allBranches: true);
        if (mounted) setState(() => _erpParties = data);
      }
    } catch (_) {
      // Offline — the local catalog list still works.
    }
  }

  Future<void> _fillExistingNumber(String number, {required bool dealer}) async {
    final normalized = number.replaceAll(RegExp(r'\D'), '');
    if (normalized.length < 8 || !await ApiService.isConnected) return;
    try {
      final records = await ApiService.surveys(
        type: dealer ? SurveyModel.typeDealer : SurveyModel.typeFarmer,
        mineOnly: false,
      );
      // Records arrive newest-first, so the first match is the latest visit.
      final found = records.cast<Map<String, dynamic>>().firstWhere(
        (row) => (row[dealer ? 'dealerMobile' : 'farmerMobile'] ?? '')
            .toString()
            .replaceAll(RegExp(r'\D'), '') == normalized,
        orElse: () => <String, dynamic>{},
      );
      if (found.isEmpty || !mounted) return;
      setState(() {
        if (dealer) {
          _shopName.text = (found['shopName'] ?? '').toString();
          _dealerName.text = (found['dealerName'] ?? '').toString();
          _bazarName.text = (found['bazarName'] ?? '').toString();
          _stock = (found['wintechStock'] ?? '').toString();
          _competitor.text = (found['competitorProduct'] ?? '').toString();
        } else {
          _farmName.text = (found['farmName'] ?? '').toString();
          _village.text = (found['village'] ?? '').toString();
          _diseases.text = (found['diseases'] ?? '').toString();
          _prescription.text = (found['prescription'] ?? '').toString();
          _products = List<String>.from(found['wintechProducts'] ?? const []);
        }
      });
      _message('Existing visit details filled from ERP');
    } catch (_) {
      // A new number remains a normal new visit entry.
    }
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

  static DateTime _dhakaNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 6));

  static String _dateAndTime(DateTime value) =>
      DateFormat('dd MMM yyyy · hh:mm a').format(value);

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_visitDate) ?? _dhakaNow();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      final now = _dhakaNow();
      setState(() => _visitDate = DateTime(
          date.year, date.month, date.day, now.hour, now.minute, now.second)
          .toIso8601String());
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Required fields per visit type (matches server-side validation).
    if (_type == SurveyModel.typeFarmer) {
      if (_farmName.text.trim().isEmpty) {
        _message('Farm/farmer name is required');
        return;
      }
      if (_farmerMobile.text.trim().isEmpty) {
        _message('Farmer mobile number is required');
        return;
      }
      if (_village.text.trim().isEmpty) {
        _message('Village is required');
        return;
      }
    }
    if (_type == SurveyModel.typeDealer) {
      if (_shopName.text.trim().isEmpty) {
        _message('Shop name is required');
        return;
      }
      if (_dealerName.text.trim().isEmpty) {
        _message('Dealer name is required');
        return;
      }
      if (_dealerMobile.text.trim().isEmpty) {
        _message('Dealer mobile number is required');
        return;
      }
      if (_bazarName.text.trim().isEmpty) {
        _message('Bazar name is required');
        return;
      }
    }
    // Real-time photo is mandatory: at least one camera capture.
    if (_photos.isEmpty && _photo.trim().isEmpty) {
      _message('Please take at least one real-time photo with the camera');
      return;
    }
    // New visit records always capture the live Asia/Dhaka timestamp.
    if (widget.existing == null) _visitDate = _dhakaNow().toIso8601String();
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
      photos: _photos,
      createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
    );
    await LocalStorageService.saveSurvey(survey);
    // Only push brand-new surveys to the ERP (edits stay local).
    if (existing == null) {
      var sent = false;
      if (await ApiService.isConnected) {
        try {
          // Upload real-time photos first so the ERP stores durable URLs.
          final payload = survey.toMap()
            ..remove('workerName')
            ..remove('postingId')
            ..remove('visitDate');
          payload['photos'] = await ApiService.uploadPhotos(
              survey.allPhotos,
              folder: 'surveys');
          await ApiService.createSurvey(payload);
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
            ? '✅ Survey submitted to ERP!'
            : '📥 Offline — will sync to ERP when connected');
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
                _section(isFarmer ? 'Farmer Info' : 'Shop / Dealer Info'),
                if (isFarmer) ...[
                  Row(
                    children: [
                      Expanded(child: _field(_farmName, 'Farm / Farmer Name')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_farmerMobile, 'Mobile / WhatsApp',
                          keyboard: TextInputType.phone,
                          onSubmitted: (value) => _fillExistingNumber(value, dealer: false))),
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
                  DropdownButtonFormField<String>(
                    value: null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Select product',
                        prefixIcon: Icon(Icons.inventory_2_rounded)),
                    items: _productOptions
                        .where((p) => !_products.contains(p))
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    GoogleFonts.hindSiliguri(fontSize: 13))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null && !_products.contains(value)) {
                        setState(() => _products.add(value));
                      }
                    },
                  ),
                  if (_products.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      children: _products.map((product) {
                        return Chip(
                          label: Text(product,
                              style: GoogleFonts.hindSiliguri(fontSize: 11)),
                          deleteIcon: const Icon(Icons.close_rounded, size: 14),
                          onDeleted: () =>
                              setState(() => _products.remove(product)),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _field(_prescription, 'Prescription / Recommendation',
                      maxLines: 3, required: false),
                ] else ...[
                  // Zone-wise party dropdown for dealership visits
                  DropdownButtonFormField<String>(
                    value: _dealerZone.isEmpty ? null : _dealerZone,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Zone',
                        prefixIcon: Icon(Icons.map_rounded)),
                    items: _zoneOptions
                        .map((z) => DropdownMenuItem(
                            value: z,
                            child: Text(z,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    GoogleFonts.hindSiliguri(fontSize: 13))))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _dealerZone = value ?? ''),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _zoneParties.contains(_shopName.text)
                        ? _shopName.text
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Party / Shop Name *',
                        prefixIcon: Icon(Icons.storefront_rounded)),
                    hint: Text(
                        _dealerZone.isEmpty
                            ? 'Select zone first'
                            : 'Select party',
                        style: GoogleFonts.hindSiliguri(fontSize: 12)),
                    items: _zoneParties
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    GoogleFonts.hindSiliguri(fontSize: 13))))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _shopName.text = value ?? ''),
                    validator: (_) => _shopName.text.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _field(_shopName, 'Shop Name (manual, if not in list)',
                      required: false),
                  const SizedBox(height: 10),
                  _field(_dealerName, 'Dealer Name'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _field(_dealerMobile, 'Mobile / WhatsApp',
                              keyboard: TextInputType.phone,
                              onSubmitted: (value) => _fillExistingNumber(value, dealer: true))),
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
                _section('Real-time Photos (Required)'),
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
    // Camera-only, multi-photo (max _maxPhotos). Legacy single photo shown too.
    final all = <String>[
      if (_photo.trim().isNotEmpty && !_photos.contains(_photo)) _photo,
      ..._photos,
    ];
    Widget thumb(String path) => Stack(children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.lightAccent,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppTheme.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: path.startsWith('http')
                ? Image.network(path,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: AppTheme.textGrey,
                        size: 25))
                : Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: AppTheme.textGrey,
                        size: 25),
                  ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => setState(() {
                if (_photo == path) _photo = '';
                _photos.remove(path);
              }),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (all.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: all.map(thumb).toList(),
          ),
        ),
      SizedBox(
        width: double.infinity,
        height: 72,
        child: OutlinedButton.icon(
          onPressed: (_pickingPhoto || all.length >= _maxPhotos)
              ? null
              : _pickPhoto,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryAccent,
            side: BorderSide(
              color: AppTheme.primaryAccent.withValues(alpha: 0.85),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _pickingPhoto
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.photo_camera_rounded, size: 25),
          label: Text(
            all.isEmpty
                ? 'Take Photo'
                : all.length >= _maxPhotos
                    ? 'Maximum $_maxPhotos Photos Added'
                    : 'Take Another Photo (${all.length}/$_maxPhotos)',
            style: GoogleFonts.hindSiliguri(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      if (all.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Real-time camera photo is required (gallery not allowed)',
            style: GoogleFonts.hindSiliguri(
                fontSize: 11, color: AppTheme.textGrey),
          ),
        ),
    ]);
  }

  Future<void> _pickPhoto() async {
    // Camera ONLY — real-time capture is mandatory; gallery is not allowed.
    setState(() => _pickingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 78,
        maxWidth: 1600,
      );
      if (picked != null && mounted) {
        var storedPhoto = picked.path;
        if (await ApiService.isConnected) {
          try {
            storedPhoto = await ApiService.uploadPhoto(
              picked.path,
              folder: 'surveys',
            );
          } catch (_) {
            // Keep the camera file for the normal save-time upload retry.
          }
        }
        if (mounted) setState(() => _photos = [..._photos, storedPhoto]);
      }
    } catch (_) {
      if (mounted) _message('Camera unavailable — please enable camera access');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Widget _field(TextEditingController controller, String label,
      {String? hint,
      TextInputType? keyboard,
      int maxLines = 1,
       bool required = false,
       bool readOnly = false,
       ValueChanged<String>? onSubmitted}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      readOnly: readOnly,
      onFieldSubmitted: onSubmitted,
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
