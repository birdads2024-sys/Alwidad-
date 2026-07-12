import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/excel_export_service.dart';

class AdminStudentsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final ExcelExportService _excelExportService = ExcelExportService();

  List<UserModel> _students = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';
  bool? _filterSubscribed; // null = الكل, true = مشترك كامل, false = مجاني (غير مشترك)
  DocumentSnapshot? _lastDocument;
  int _totalCount = 0;

  List<UserModel> get students => _students;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;
  bool? get filterSubscribed => _filterSubscribed;
  int get totalCount => _totalCount;

  // تحميل الطلاب لأول مرة أو عند التحديث (Refresh)
  Future<void> loadStudents({bool isRefresh = false}) async {
    if (isRefresh) {
      _lastDocument = null;
      _hasMore = true;
      _students = [];
      _totalCount = 0;
    }

    if (!_hasMore) return;

    if (isRefresh) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }
    notifyListeners();

    try {
      final searchText = _searchQuery.trim();
      if (isRefresh) {
        Query countQuery = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student');
        if (_filterSubscribed != null) {
          countQuery = countQuery.where('isSubscribed', isEqualTo: _filterSubscribed);
        }
        if (_searchQuery.isNotEmpty) {
          final searchText = _searchQuery.trim();
          countQuery = countQuery
              .where('name', isGreaterThanOrEqualTo: searchText)
              .where('name', isLessThanOrEqualTo: '$searchText\uf8ff');
        }
        try {
          final countSnapshot = await countQuery.count().get();
          _totalCount = countSnapshot.count ?? 0;
        } catch (e) {
          debugPrint('Error getting count: $e');
          _totalCount = 0;
        }
      }

      QuerySnapshot querySnapshot;
      bool fallbackApplied = false;
      try {
        querySnapshot = await _firestoreService.getStudentsQuery(
          search: _searchQuery,
          isSubscribed: _filterSubscribed,
          startAfter: _lastDocument,
          limit: 10,
        );
      } catch (e) {
        debugPrint('Firestore query with isSubscribed filter failed. Applying local fallback. Error: $e');
        fallbackApplied = true;
        querySnapshot = await _firestoreService.getStudentsQuery(
          search: _searchQuery,
          isSubscribed: null,
          startAfter: _lastDocument,
          limit: 50,
        );
      }

      List<UserModel> fetchedStudents = querySnapshot.docs.map((doc) {
        return UserModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map));
      }).toList();

      if (fallbackApplied && _filterSubscribed != null) {
        fetchedStudents = fetchedStudents.where((student) => student.isSubscribed == _filterSubscribed).toList();
      }

      // فلترة إضافية محلية للهواتف والإيميل لتسهيل البحث على الأدمن
      List<UserModel> finalStudents = fetchedStudents;
      if (_searchQuery.isNotEmpty) {
        final queryLower = _searchQuery.toLowerCase();
        // إذا كان هناك بحث، نقوم بفلترة النتائج للتأكد من مطابقة الاسم أو الهاتف أو البريد الإلكتروني
        // لأن فايرستور لا يدعم البحث الجزئي المتعدد الحقول بسهولة بدون كود إضافي
        // سنعتمد على الفلترة المحلية كعامل مساعد
        finalStudents = fetchedStudents.where((student) {
          return student.name.toLowerCase().contains(queryLower) ||
              student.phone.contains(queryLower) ||
              student.email.toLowerCase().contains(queryLower);
        }).toList();
      }

      if (isRefresh) {
        _students = finalStudents;
      } else {
        _students.addAll(finalStudents);
      }

      _students.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      // لو فيه بحث نوقف الـ pagination لأننا بنفلتر محلياً
      if (_searchQuery.isNotEmpty) {
        _hasMore = false;
      } else if (querySnapshot.docs.length < (fallbackApplied ? 50 : 10)) {
        _hasMore = false;
      } else {
        _lastDocument = querySnapshot.docs.last;
      }
    } catch (e) {
      print('خطأ في تحميل الطلاب: $e');
      _hasMore = false;
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // تحديث نص البحث
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    loadStudents(isRefresh: true);
  }

  // تحديث الفلتر (الكل / المشتركون / غير المشتركين)
  void setFilter(bool? subscribed) {
    if (_filterSubscribed == subscribed) return;
    _filterSubscribed = subscribed;
    loadStudents(isRefresh: true);
  }

  // تفعيل / إلغاء تفعيل الاشتراك
  Future<bool> toggleSubscription(String uid, bool currentStatus) async {
    try {
      final newStatus = !currentStatus;
      await _firestoreService.updateUserField(uid, 'isSubscribed', newStatus);
      
      // تحديث الحالة محلياً في القائمة فوراً
      final index = _students.indexWhere((s) => s.uid == uid);
      if (index != -1) {
        _students[index] = _students[index].copyWith(isSubscribed: newStatus);
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('خطأ أثناء تعديل الاشتراك: $e');
      return false;
    }
  }

  // تحديث حالة الاشتراك والأقسام المشتركة
  Future<bool> updateSubscription(String uid, bool isSubscribed, List<String> subscribedCategories) async {
    try {
      await _firestoreService.updateUserDocument(uid, {
        'isSubscribed': isSubscribed,
        'subscribedCategories': subscribedCategories,
      });
      
      // تحديث الحالة محلياً في القائمة فوراً
      final index = _students.indexWhere((s) => s.uid == uid);
      if (index != -1) {
        _students[index] = _students[index].copyWith(
          isSubscribed: isSubscribed,
          subscribedCategories: subscribedCategories,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('خطأ أثناء تحديث الاشتراك والأقسام: $e');
      return false;
    }
  }

  // تعديل اسم الطالب
  Future<bool> editStudentName(String uid, String newName) async {
    try {
      await _firestoreService.updateUserField(uid, 'name', newName);
      
      // تحديث الاسم محلياً في القائمة فوراً
      final index = _students.indexWhere((s) => s.uid == uid);
      if (index != -1) {
        _students[index] = _students[index].copyWith(name: newName);
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('خطأ أثناء تعديل الاسم: $e');
      return false;
    }
  }

  // حذف معرّف الجهاز (Device ID) لإعادة التعيين
  Future<bool> resetDeviceId(String uid) async {
    try {
      await _firestoreService.clearUserDeviceId(uid);
      
      // تحديث معرّف الجهاز محلياً في القائمة فوراً
      final index = _students.indexWhere((s) => s.uid == uid);
      if (index != -1) {
        _students[index] = _students[index].copyWith(deviceId: '');
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('خطأ أثناء إعادة تعيين معرّف الجهاز: $e');
      return false;
    }
  }

  // تصدير الطلاب إلى ملف إكسل
  Future<String?> exportStudents() async {
    try {
      // لجلب كافة الطلاب (دون اقتصار على 10 لغرض التصدير)
      final allStudentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      List<UserModel> allStudents = allStudentsQuery.docs.map((doc) {
        return UserModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map));
      }).toList();

      // تطبيق فلترة الاشتراك الحالية
      if (_filterSubscribed != null) {
        allStudents = allStudents.where((student) => student.isSubscribed == _filterSubscribed).toList();
      }

      // تطبيق فلترة البحث الحالية
      if (_searchQuery.trim().isNotEmpty) {
        final queryLower = _searchQuery.trim().toLowerCase();
        allStudents = allStudents.where((student) {
          return student.name.toLowerCase().contains(queryLower) ||
              student.phone.contains(queryLower) ||
              student.email.toLowerCase().contains(queryLower);
        }).toList();
      }

      if (allStudents.isEmpty) {
        return null;
      }

      return await _excelExportService.exportStudentsToExcel(allStudents);
    } catch (e) {
      print('خطأ أثناء تصدير الإكسل: $e');
      return null;
    }
  }
}
