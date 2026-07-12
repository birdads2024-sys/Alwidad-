import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionModel {
  final String id;
  final String title;
  final String categoryId;
  final String formUrl;
  final int order;
  final bool isActive;
  final DateTime? createdAt;

  QuestionModel({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.formUrl,
    required this.order,
    this.isActive = true,
    this.createdAt,
  });

  factory QuestionModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return QuestionModel(
      id: id,
      title: map['title'] ?? '',
      categoryId: map['categoryId'] ?? '',
      formUrl: map['formUrl'] ?? '',
      order: map['order'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: parseDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'categoryId': categoryId,
      'formUrl': formUrl,
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
      'formUrl': formUrl,
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }

  QuestionModel copyWith({
    String? title,
    String? categoryId,
    String? formUrl,
    int? order,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return QuestionModel(
      id: id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      formUrl: formUrl ?? this.formUrl,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
