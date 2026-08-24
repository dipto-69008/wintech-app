import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../models/survey_model.dart';

class SurveyDetailsScreen extends StatelessWidget {
  final SurveyModel survey;
  final List<SurveyModel> previousVisits;

  const SurveyDetailsScreen({
    super.key,
    required this.survey,
    this.previousVisits = const [],
  });

  String _date(String raw) {
    final value = DateTime.tryParse(raw);
    return value == null ? raw : DateFormat('dd MMM yyyy · hh:mm a').format(value);
  }

  Widget _photo(String path) {
    final image = path.startsWith('http')
        ? Image.network(path, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))
        : Image.file(File(path), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 240,
        height: 190,
        color: AppTheme.lightAccent,
        child: image,
      ),
    );
  }

  Widget _detail(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label,
                style: GoogleFonts.hindSiliguri(
                    color: AppTheme.textGrey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, String>> _fields() {
    final farmer = survey.type == SurveyModel.typeFarmer;
    return [
      MapEntry('Officer', survey.workerName),
      MapEntry('Posting / ID', survey.postingId),
      MapEntry('Visit Date', _date(survey.visitDate)),
      if (farmer) ...[
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
        MapEntry('Wintech Stock', survey.wintechStock),
        MapEntry('Competitor Product', survey.competitorProduct),
        MapEntry('Collection', survey.collectionAmount == null
            ? ''
            : '৳${NumberFormat('#,##0').format(survey.collectionAmount)}'),
        MapEntry('Remarks', survey.remarks),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final farmer = survey.type == SurveyModel.typeFarmer;
    final accent = farmer ? const Color(0xFF2E9B67) : const Color(0xFF2477C5);
    return Scaffold(
      appBar: AppBar(
        title: Text(farmer ? 'Farmer Visit Details' : 'Dealer Visit Details',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w800)),
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: [
          if (survey.allPhotos.isNotEmpty)
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: survey.allPhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) => _photo(survey.allPhotos[index]),
              ),
            ),
          if (survey.allPhotos.isNotEmpty) const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                children: _fields()
                    .map((field) => _detail(field.key, field.value))
                    .toList(),
              ),
            ),
          ),
          if (previousVisits.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('Previous visits (${previousVisits.length})',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...previousVisits.map((visit) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                        visit.type == SurveyModel.typeFarmer
                            ? Icons.grass_rounded
                            : Icons.storefront_rounded,
                        color: accent),
                    title: Text(
                        visit.type == SurveyModel.typeFarmer
                            ? visit.farmName
                            : visit.shopName,
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${_date(visit.visitDate)} · ${visit.workerName}',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 11, color: AppTheme.textGrey)),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}