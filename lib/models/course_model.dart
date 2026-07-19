import 'package:cloud_firestore/cloud_firestore.dart';

class CourseModel {
  final String id;
  final String title;
  final String description;
  final String categoryId; // matching AppConstants.categories keys
  final String hlsUrl;
  final String mp4Url;
  final String thumbnailUrl;
  final bool isFree;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<VideoQuality> qualities;

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.hlsUrl,
    required this.mp4Url,
    required this.thumbnailUrl,
    required this.isFree,
    required this.order,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.qualities = const [],
  });

  factory CourseModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    List<VideoQuality> qualitiesList = [];
    if (map['qualities'] != null) {
      qualitiesList = (map['qualities'] as List)
          .map((item) => VideoQuality.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } else {
      // التوافق الرجعي: إذا لم يكن هناك جودات، ننشئ جودة افتراضية بالروابط القديمة
      final hls = map['hlsUrl'] ?? '';
      final mp4 = map['mp4Url'] ?? '';
      if (hls.isNotEmpty || mp4.isNotEmpty) {
        qualitiesList = [
          VideoQuality(
            qualityName: 'الافتراضية',
            hlsUrl: hls,
            mp4Url: mp4,
          )
        ];
      }
    }

    return CourseModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      categoryId: map['categoryId'] ?? '',
      hlsUrl: map['hlsUrl'] ?? '',
      mp4Url: map['mp4Url'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      isFree: map['isFree'] ?? false,
      order: map['order'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
      qualities: qualitiesList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'hlsUrl': hlsUrl,
      'mp4Url': mp4Url,
      'thumbnailUrl': thumbnailUrl,
      'isFree': isFree,
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'qualities': qualities.map((q) => q.toMap()).toList(),
    };
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'hlsUrl': hlsUrl,
      'mp4Url': mp4Url,
      'thumbnailUrl': thumbnailUrl,
      'isFree': isFree,
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'qualities': qualities.map((q) => q.toMap()).toList(),
    };
  }

  CourseModel copyWith({
    String? title,
    String? description,
    String? categoryId,
    String? hlsUrl,
    String? mp4Url,
    String? thumbnailUrl,
    bool? isFree,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<VideoQuality>? qualities,
  }) {
    return CourseModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      mp4Url: mp4Url ?? this.mp4Url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isFree: isFree ?? this.isFree,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      qualities: qualities ?? this.qualities,
    );
  }
}

class VideoQuality {
  final String qualityName; // مثال: 480p, 1080p
  final String hlsUrl;
  final String mp4Url;

  VideoQuality({
    required this.qualityName,
    required this.hlsUrl,
    required this.mp4Url,
  });

  factory VideoQuality.fromMap(Map<String, dynamic> map) {
    return VideoQuality(
      qualityName: map['qualityName'] ?? '',
      hlsUrl: map['hlsUrl'] ?? '',
      mp4Url: map['mp4Url'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'qualityName': qualityName,
      'hlsUrl': hlsUrl,
      'mp4Url': mp4Url,
    };
  }
}

