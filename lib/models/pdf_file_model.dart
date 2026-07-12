import 'package:cloud_firestore/cloud_firestore.dart';

class PdfFileModel {
  final String id;
  final String title;
  final String categoryId;
  final String driveUrl;
  final int order;
  final bool isActive;
  final DateTime? createdAt;

  PdfFileModel({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.driveUrl,
    required this.order,
    this.isActive = true,
    this.createdAt,
  });

  factory PdfFileModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return PdfFileModel(
      id: id,
      title: map['title'] ?? '',
      categoryId: map['categoryId'] ?? '',
      driveUrl: map['driveUrl'] ?? '',
      order: map['order'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: parseDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'categoryId': categoryId,
      'driveUrl': driveUrl,
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'title': title,
      'categoryId': categoryId,
      'driveUrl': driveUrl,
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }

  PdfFileModel copyWith({
    String? title,
    String? categoryId,
    String? driveUrl,
    int? order,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return PdfFileModel(
      id: id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      driveUrl: driveUrl ?? this.driveUrl,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
