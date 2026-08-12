class TutorialModel {
  final String id;
  final String title;
  final String description;
  final String videoUrl; // YouTube link or direct URL
  final String thumbnailUrl;
  final String category; // 'ড্যাশবোর্ড' | 'লিড' | 'প্রপার্টি' | 'ফলো আপ' | 'সাধারণ'
  final int durationMinutes;
  final DateTime createdAt;

  TutorialModel({
    required this.id,
    required this.title,
    this.description = '',
    this.videoUrl = '',
    this.thumbnailUrl = '',
    this.category = 'সাধারণ',
    this.durationMinutes = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static const List<String> categoryOptions = [
    'সাধারণ',
    'ড্যাশবোর্ড',
    'লিড',
    'প্রপার্টি',
    'ফলো আপ',
    'সেটিং',
  ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'category': category,
        'durationMinutes': durationMinutes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TutorialModel.fromMap(Map<String, dynamic> m) => TutorialModel(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        description: m['description'] ?? '',
        videoUrl: m['videoUrl'] ?? '',
        thumbnailUrl: m['thumbnailUrl'] ?? '',
        category: m['category'] ?? 'সাধারণ',
        durationMinutes: m['durationMinutes'] ?? 0,
        createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
      );
}
