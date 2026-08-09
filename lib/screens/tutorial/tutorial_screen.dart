import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/tutorial_model.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  List<TutorialModel> _all = [];
  List<TutorialModel> _filtered = [];
  UserModel? _currentUser;
  bool _loading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tutorials = await LocalStorageService.getTutorials();
    final user = await LocalStorageService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _all = tutorials;
      _currentUser = user;
      _loading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    if (_selectedCategory == 'All') {
      setState(() => _filtered = List.from(_all));
    } else {
      setState(() => _filtered =
          _all.where((t) => t.category == _selectedCategory).toList());
    }
  }

  bool get _canManage =>
      _currentUser?.isSuperAdmin == true || _currentUser?.isAdmin == true;

  void _showAddEditDialog({TutorialModel? existing}) {
    final titleCtrl =
        TextEditingController(text: existing?.title ?? '');
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');
    final urlCtrl =
        TextEditingController(text: existing?.videoUrl ?? '');
    String category = existing?.category ?? 'General';
    int duration = existing?.durationMinutes ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: StatefulBuilder(builder: (ctx, setSt) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          existing != null
                              ? 'Edit Tutorial'
                              : 'New Tutorial',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryAccent)),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon:
                            const Icon(Icons.close_rounded, size: 22)),
                  ]),
                  const SizedBox(height: 16),
                  _field(titleCtrl, 'Title *', 'Tutorial name'),
                  const SizedBox(height: 12),
                  _field(descCtrl, 'Description', 'About this tutorial',
                      maxLines: 3),
                  const SizedBox(height: 12),
                  _field(urlCtrl, 'Video Link',
                      'https://youtube.com/watch?v=...'),
                  const SizedBox(height: 12),
                  Text('Category',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.primaryBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.divider)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.divider)),
                    ),
                    items: TutorialModel.categoryOptions
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c,
                                style: GoogleFonts.hindSiliguri(
                                    fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setSt(() => category = v!),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) return;
                        final t = TutorialModel(
                          id: existing?.id ??
                              DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          videoUrl: urlCtrl.text.trim(),
                          category: category,
                          durationMinutes: duration,
                        );
                        await LocalStorageService.saveTutorial(t);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _load();
                      },
                      child: Text(
                          existing != null ? 'Update' : 'Add',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.hindSiliguri(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.hindSiliguri(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.hindSiliguri(
                fontSize: 13, color: AppTheme.textGrey),
            filled: true,
            fillColor: AppTheme.primaryBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.divider)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppTheme.primaryAccent, width: 2)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ['All', ...TutorialModel.categoryOptions];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            color: AppTheme.primaryAccent,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tutorials',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text('App usage guide',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  if (_canManage)
                    GestureDetector(
                      onTap: () => _showAddEditDialog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.add_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text('Add',
                              style: GoogleFonts.hindSiliguri(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = categories[i];
                      final sel = c == _selectedCategory;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = c);
                          _applyFilter();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color:
                                sel ? Colors.white : Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(c,
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? AppTheme.primaryAccent
                                      : Colors.white)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryAccent))
                : _filtered.isEmpty
                    ? Center(
                        child: Text('No tutorials found',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 15,
                                color: isDark
                                    ? AppTheme.darkTextGrey
                                    : AppTheme.textGrey)))
                    : RefreshIndicator(
                        color: AppTheme.primaryAccent,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _buildCard(_filtered[i], isDark),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(TutorialModel t, bool isDark) {
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail / placeholder
          Stack(
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.12),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Icon(
                    t.videoUrl.isNotEmpty
                        ? Icons.play_circle_fill_rounded
                        : Icons.videocam_off_rounded,
                    color: AppTheme.primaryAccent.withValues(alpha: 0.5),
                    size: 56,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(t.category,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              if (t.videoUrl.isNotEmpty)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => _openVideo(t.videoUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text('Watch',
                            style: GoogleFonts.hindSiliguri(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(t.title,
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  if (_canManage) ...[
                    GestureDetector(
                      onTap: () => _showAddEditDialog(existing: t),
                      child: const Icon(Icons.edit_rounded,
                          size: 18, color: AppTheme.textGrey),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        await LocalStorageService.deleteTutorial(t.id);
                        _load();
                      },
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppTheme.error),
                    ),
                  ]
                ]),
                if (t.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextGrey
                              : AppTheme.textGrey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openVideo(String url) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Video link: $url',
          style: GoogleFonts.hindSiliguri()),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
          label: 'OK',
          onPressed: () {}),
    ));
  }
}
