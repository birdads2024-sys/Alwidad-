import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // 'student' | 'admin'
  final String category; // e.g. 'scientific_1', 'literary_2'
  final bool isSubscribed;
  final String deviceId;
  final List<String> subscribedCategories; // قائمة الأقسام المشترك بها الطالب
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.category,
    required this.isSubscribed,
    required this.deviceId,
    this.subscribedCategories = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    DateTime? getCreatedAt() {
      final val = map['createdAt'];
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    DateTime? getUpdatedAt() {
      final val = map['updatedAt'];
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    List<String> getSubscribedCategories() {
      final val = map['subscribedCategories'];
      if (val is List) {
        return List<String>.from(val);
      }
      return [];
    }

    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'student',
      category: map['category'] ?? '',
      isSubscribed: map['isSubscribed'] ?? false,
      deviceId: map['deviceId'] ?? '',
      subscribedCategories: getSubscribedCategories(),
      createdAt: getCreatedAt(),
      updatedAt: getUpdatedAt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'category': category,
      'isSubscribed': isSubscribed,
      'deviceId': deviceId,
      'subscribedCategories': subscribedCategories,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'category': category,
      'isSubscribed': isSubscribed,
      'deviceId': deviceId,
      'subscribedCategories': subscribedCategories,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? category,
    bool? isSubscribed,
    String? deviceId,
    List<String>? subscribedCategories,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      category: category ?? this.category,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      deviceId: deviceId ?? this.deviceId,
      subscribedCategories: subscribedCategories ?? this.subscribedCategories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
