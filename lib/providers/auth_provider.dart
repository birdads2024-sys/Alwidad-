import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/device_service.dart';
import '../services/cache_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceService _deviceService = DeviceService();
  final CacheService _cacheService = CacheService();

  UserModel? _currentUserModel;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDeviceMismatch = false;

  UserModel? get currentUserModel => _currentUserModel;
  UserModel? get currentUser => _currentUserModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isDeviceMismatch => _isDeviceMismatch;
  bool get isAuthenticated => _currentUserModel != null;

  fb_auth.User? get firebaseUser => _authService.currentUser;

  AuthProvider() {
    // Check is triggered explicitly by SplashScreen post-frame callback
  }

  // تهيئة وفحص حالة المستخدم الحالي
  Future<void> checkCurrentUser() async {
    _isLoading = true;
    _errorMessage = null;
    _isDeviceMismatch = false;
    notifyListeners();

    try {
      final fbUser = _authService.currentUser;
      if (fbUser != null) {
        // نحدد مهلة ثانيتين فقط لجلب البيانات لتسريع وقت التحميل وتفادي تعليق الشبكة
        final userModel = await _firestoreService.getUserModel(fbUser.uid).timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('Firestore getUserModel timeout');
            return null;
          },
        );

        if (userModel != null) {
          final deviceId = await _deviceService.getUniqueDeviceId();
          if (userModel.role == 'student') {
            if (userModel.deviceId.isEmpty) {
              // ربط الجهاز لأول مرة
              await _firestoreService.updateUserField(userModel.uid, 'deviceId', deviceId);
              _currentUserModel = userModel.copyWith(deviceId: deviceId);
            } else if (userModel.deviceId != deviceId) {
              _isDeviceMismatch = true;
              _currentUserModel = null;
              await _authService.signOut();
              _isLoading = false;
              notifyListeners();
              return;
            } else {
              _currentUserModel = userModel;
            }
          } else {
            _currentUserModel = userModel;
          }

          if (_currentUserModel != null) {
            await _cacheUserLocally(_currentUserModel!);
          }
        } else {
          await _checkOfflineSession();
        }
      } else {
        await _checkOfflineSession();
      }
    } catch (e) {
      debugPrint('Error checking current user: $e');
      await _checkOfflineSession();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // فحص الجلسة غير المتصلة بالإنترنت (صلاحية شهر)
  Future<void> _checkOfflineSession() async {
    try {
      final cachedUserMap = _cacheService.getCachedData('cached_user_model');
      final cachedTimeMs = _cacheService.getCachedData('cached_user_time');

      if (cachedUserMap != null && cachedTimeMs != null) {
        final cachedDate = DateTime.fromMillisecondsSinceEpoch(cachedTimeMs as int);
        final difference = DateTime.now().difference(cachedDate).inDays;

        if (difference < 30) {
          Map<String, dynamic> userMap = Map<String, dynamic>.from(
            cachedUserMap is String ? jsonDecode(cachedUserMap) : cachedUserMap,
          );
          final user = UserModel.fromMap(userMap['uid'] ?? '', userMap);
          
          final deviceId = await _deviceService.getUniqueDeviceId();
          if (user.role == 'student') {
            if (user.deviceId.isNotEmpty && user.deviceId != deviceId) {
              _isDeviceMismatch = true;
              _currentUserModel = null;
              return;
            }
          }
          _currentUserModel = user;
        } else {
          await clearCache();
        }
      }
    } catch (e) {
      debugPrint('Error loading offline session: $e');
    }
  }

  // كاش البيانات محلياً
  Future<void> _cacheUserLocally(UserModel user) async {
    try {
      final userMap = user.toCacheMap();
      final sanitizedMap = <String, dynamic>{};
      userMap.forEach((key, val) {
        if (val is DateTime) {
          sanitizedMap[key] = val.millisecondsSinceEpoch;
        } else if (val is Timestamp) {
          sanitizedMap[key] = val.millisecondsSinceEpoch;
        } else {
          sanitizedMap[key] = val;
        }
      });
      await _cacheService.cacheData('cached_user_model', jsonEncode(sanitizedMap));
      await _cacheService.cacheData('cached_user_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching user locally: $e');
    }
  }

  // مسح الكاش بالكامل لتفريغ الذاكرة وتنظيف جلسة الأدمن/الطالب السابقة تماماً
  Future<void> clearCache() async {
    await _cacheService.clearCache();
  }

  // تسجيل الدخول
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _isDeviceMismatch = false;
    notifyListeners();

    try {
      final credential = await _authService.signInWithEmailAndPassword(email, password);
      final uid = credential.user!.uid;

      final userModel = await _firestoreService.getUserModel(uid).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('TimeoutException: انتهت مهلة الاتصال لجلب بيانات المستخدم'),
      );
      if (userModel == null) {
        throw Exception('بيانات المستخدم غير موجودة في السيرفر');
      }

      final deviceId = await _deviceService.getUniqueDeviceId();
      if (userModel.role == 'student') {
        if (userModel.deviceId.isEmpty) {
          await _firestoreService.updateUserField(uid, 'deviceId', deviceId);
          _currentUserModel = userModel.copyWith(deviceId: deviceId);
        } else if (userModel.deviceId != deviceId) {
          _isDeviceMismatch = true;
          _currentUserModel = null;
          await _authService.signOut();
          _isLoading = false;
          notifyListeners();
          return false;
        } else {
          _currentUserModel = userModel;
        }
      } else {
        _currentUserModel = userModel;
      }

      if (_currentUserModel != null) {
        await _cacheUserLocally(_currentUserModel!);
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getArabicErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // تسجيل حساب جديد
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required List<String> categories,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _isDeviceMismatch = false;
    notifyListeners();

    try {
      final credential = await _authService.registerWithEmailAndPassword(email, password);
      final user = credential.user;
      if (user == null) {
        throw Exception('فشل تسجيل المستخدم في المصادقة');
      }

      final deviceId = await _deviceService.getUniqueDeviceId().timeout(
        const Duration(seconds: 10),
        onTimeout: () => 'fallback_device_id_${DateTime.now().millisecondsSinceEpoch}',
      );
      final newUser = UserModel(
        uid: user.uid,
        name: name,
        email: email,
        phone: phone,
        role: 'student',
        category: categories.isNotEmpty ? categories.first : '',
        isSubscribed: false,
        deviceId: deviceId,
        subscribedCategories: categories,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.createUserDocument(user.uid, newUser.toMap());
      _currentUserModel = newUser;
      await _cacheUserLocally(newUser);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getArabicErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // الدخول بحساب جوجل
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    _isDeviceMismatch = false;
    notifyListeners();

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final uid = credential.user!.uid;
      final deviceId = await _deviceService.getUniqueDeviceId().timeout(
        const Duration(seconds: 10),
        onTimeout: () => 'fallback_device_id_${DateTime.now().millisecondsSinceEpoch}',
      );

      var userModel = await _firestoreService.getUserModel(uid).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('TimeoutException: انتهت مهلة الاتصال لجلب بيانات المستخدم'),
      );

      if (userModel == null) {
        userModel = UserModel(
          uid: uid,
          name: credential.user!.displayName ?? 'مستخدم جوجل',
          email: credential.user!.email ?? '',
          phone: credential.user!.phoneNumber ?? '',
          role: 'student',
          category: 'scientific_1',
          isSubscribed: false,
          deviceId: deviceId,
          subscribedCategories: const ['scientific_1', 'scientific_2', 'literary_1', 'literary_2'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _firestoreService.createUserDocument(uid, userModel.toMap());
      } else {
        if (userModel.role == 'student') {
          if (userModel.deviceId.isEmpty) {
            await _firestoreService.updateUserField(uid, 'deviceId', deviceId);
            userModel = userModel.copyWith(deviceId: deviceId);
          } else if (userModel.deviceId != deviceId) {
            _isDeviceMismatch = true;
            _currentUserModel = null;
            await _authService.signOut();
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }
      }

      _currentUserModel = userModel;
      await _cacheUserLocally(userModel);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getArabicErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // الدخول بحساب أبل (Apple Sign In)
  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    _isDeviceMismatch = false;
    notifyListeners();

    try {
      final credential = await _authService.signInWithApple();
      if (credential == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final uid = credential.user!.uid;
      final deviceId = await _deviceService.getUniqueDeviceId().timeout(
        const Duration(seconds: 10),
        onTimeout: () => 'fallback_device_id_${DateTime.now().millisecondsSinceEpoch}',
      );

      var userModel = await _firestoreService.getUserModel(uid).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('TimeoutException: انتهت مهلة الاتصال لجلب بيانات المستخدم'),
      );

      if (userModel == null) {
        userModel = UserModel(
          uid: uid,
          name: credential.user!.displayName ?? 'مستخدم Apple',
          email: credential.user!.email ?? '',
          phone: credential.user!.phoneNumber ?? '',
          role: 'student',
          category: 'scientific_1',
          isSubscribed: false,
          deviceId: deviceId,
          subscribedCategories: const ['scientific_1', 'scientific_2', 'literary_1', 'literary_2'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _firestoreService.createUserDocument(uid, userModel.toMap());
      } else {
        if (userModel.role == 'student') {
          if (userModel.deviceId.isEmpty) {
            await _firestoreService.updateUserField(uid, 'deviceId', deviceId);
            userModel = userModel.copyWith(deviceId: deviceId);
          } else if (userModel.deviceId != deviceId) {
            _isDeviceMismatch = true;
            _currentUserModel = null;
            await _authService.signOut();
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }
      }

      _currentUserModel = userModel;
      await _cacheUserLocally(userModel);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getArabicErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // استعادة كلمة المرور
  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getArabicErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // تعديل الملف الشخصي
  Future<void> updateProfile({
    required String name,
    required String phone,
    required String email,
    String? password,
  }) async {
    if (_currentUserModel == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      if (email != user.email) {
        await user.verifyBeforeUpdateEmail(email);
      }

      if (password != null && password.trim().isNotEmpty) {
        await _authService.updatePassword(password.trim());
      }

      final updatedData = {
        'name': name,
        'phone': phone,
        'email': email,
      };
      await _firestoreService.updateUserDocument(user.uid, updatedData);
      
      _currentUserModel = _currentUserModel!.copyWith(
        name: name,
        phone: phone,
        email: email,
      );
      await _cacheUserLocally(_currentUserModel!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تسجيل الخروج
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signOut();
      await clearCache();
      _currentUserModel = null;
      _isDeviceMismatch = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تسجيل الخروج (اسم بديل متوافق)
  Future<void> signOut() async {
    await logout();
  }

  // حذف الحساب
  Future<void> deleteAccount() async {
    if (_currentUserModel == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final user = _authService.currentUser;
      if (user != null) {
        final uid = user.uid;
        await _firestoreService.clearUserDeviceId(uid);
        await _firestoreService.updateUserField(uid, 'role', 'deleted');
        await user.delete();
        await clearCache();
        _currentUserModel = null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ترجمة رسائل أخطاء المصادقة للعربية
  String _getArabicErrorMessage(Object error) {
    if (error.toString().contains('TimeoutException')) {
      return 'انتهت مهلة الاتصال بالخادم، يرجى التحقق من جودة الإنترنت والمحاولة مجدداً';
    }
    if (error is fb_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'لا يوجد حساب مسجل بهذا البريد الإلكتروني';
        case 'wrong-password':
          return 'كلمة المرور غير صحيحة';
        case 'invalid-email':
          return 'صيغة البريد الإلكتروني غير صحيحة';
        case 'user-disabled':
          return 'تم تعطيل هذا الحساب من قبل الإدارة';
        case 'invalid-credential':
          return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
        case 'email-already-in-use':
          return 'البريد الإلكتروني مستخدم بالفعل في حساب آخر';
        case 'weak-password':
          return 'كلمة المرور ضعيفة جداً، يجب أن تكون 6 أحرف على الأقل';
        case 'network-request-failed':
          return 'فشل الاتصال بالشبكة، يرجى التحقق من اتصال الإنترنت';
        default:
          return error.message ?? 'حدث خطأ أثناء العملية';
      }
    }
    return error.toString();
  }
}
