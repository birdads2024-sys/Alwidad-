import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/course_model.dart';
import '../models/pdf_file_model.dart';
import '../models/question_model.dart';
import '../models/app_settings_model.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';

class CoursesProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final CacheService _cacheService = CacheService();

  AppSettingsModel? _appSettings;
  List<CourseModel> _courses = [];
  List<PdfFileModel> _pdfFiles = [];
  List<QuestionModel> _questions = [];

  bool _isLoadingSettings = false;
  bool _isLoadingCourses = false;
  bool _isLoadingPdfs = false;
  bool _isLoadingQuestions = false;

  bool _hasMoreCourses = true;
  DocumentSnapshot? _lastCourseDoc;

  // Getters
  AppSettingsModel? get appSettings => _appSettings;
  List<CourseModel> get courses => _courses.where((c) => c.isActive).toList();
  List<PdfFileModel> get pdfFiles => _pdfFiles.where((p) => p.isActive).toList();
  List<QuestionModel> get questions => _questions.where((q) => q.isActive).toList();

  bool get isLoadingSettings => _isLoadingSettings;
  bool get isLoadingCourses => _isLoadingCourses;
  bool get isLoadingPdfs => _isLoadingPdfs;
  bool get isLoadingQuestions => _isLoadingQuestions;
  bool get hasMoreCourses => _hasMoreCourses;

  // Initialize and load configurations
  Future<void> init() async {
    await _cacheService.init();
    await loadAppSettings();
  }

  // ===================== APP SETTINGS =====================
  Future<void> loadAppSettings() async {
    _isLoadingSettings = true;
    notifyListeners();

    // 1. Try to load from Cache first
    final cached = _cacheService.getCachedData('app_settings');
    if (cached != null) {
      try {
        final Map<String, dynamic> decoded = Map<String, dynamic>.from(json.decode(cached));
        _appSettings = AppSettingsModel.fromMap(decoded);
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing cached settings: $e');
      }
    }

    // 2. Fetch from Firestore
    try {
      final settings = await _firestoreService.getAppSettings();
      if (settings != null) {
        _appSettings = settings;
        await _cacheService.cacheData('app_settings', json.encode(settings.toMap()));
      }
    } catch (e) {
      debugPrint('Error fetching app settings from firestore: $e');
    } finally {
      _isLoadingSettings = false;
      notifyListeners();
    }
  }

  // ===================== COURSES (WITH PAGINATION & CACHE) =====================
  Future<void> loadCourses(String categoryId, {bool refresh = false}) async {
    if (_isLoadingCourses) return;

    if (refresh) {
      _courses = [];
      _lastCourseDoc = null;
      _hasMoreCourses = true;
      notifyListeners();

      // Load from cache first for this category
      final cached = _cacheService.getCachedData('courses_$categoryId');
      if (cached != null) {
        try {
          final List<dynamic> decoded = json.decode(cached);
          _courses = decoded.map((item) => CourseModel.fromMap(item['id'] ?? '', Map<String, dynamic>.from(item))).toList();
          notifyListeners();
        } catch (e) {
          debugPrint('Error parsing cached courses: $e');
        }
      }
    }

    if (!_hasMoreCourses) return;

    _isLoadingCourses = true;
    notifyListeners();

    try {
      // We need a paginated query.
      Query query = FirebaseFirestore.instance.collection('courses')
          .where('categoryId', isEqualTo: categoryId)
          .orderBy('order');

      if (_lastCourseDoc != null) {
        query = query.startAfterDocument(_lastCourseDoc!);
      }

      // نحدد مهلة 5 ثوانٍ فقط للحصول على الكورسات لتفادي تعليق الـ loading
      final snapshot = await query.limit(10).get().timeout(
        const Duration(seconds: 5),
      );

      if (snapshot.docs.isNotEmpty) {
        _lastCourseDoc = snapshot.docs.last;
        final newCourses = snapshot.docs.map((doc) => CourseModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
        
        if (refresh) {
          _courses = newCourses;
        } else {
          _courses.addAll(newCourses);
        }

        // Cache the updated list of courses safely using toCacheMap
        final toCache = _courses.map((c) => c.toCacheMap()).toList();
        await _cacheService.cacheData('courses_$categoryId', json.encode(toCache));

        if (newCourses.length < 10) {
          _hasMoreCourses = false;
        }
      } else {
        _hasMoreCourses = false;
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    } finally {
      _isLoadingCourses = false;
      notifyListeners();
    }
  }

  // ===================== PDF FILES (WITH CACHE) =====================
  Future<void> loadPdfFiles(String categoryId) async {
    _isLoadingPdfs = true;
    notifyListeners();

    // 1. Try Cache
    final cached = _cacheService.getCachedData('pdfs_$categoryId');
    if (cached != null) {
      try {
        final List<dynamic> decoded = json.decode(cached);
        _pdfFiles = decoded.map((item) => PdfFileModel.fromMap(item['id'] ?? '', Map<String, dynamic>.from(item))).toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing cached PDFs: $e');
      }
    }

    try {
      final pdfs = await _firestoreService.getPdfFilesByCategory(categoryId).timeout(
        const Duration(seconds: 5),
      );
      _pdfFiles = pdfs;
      
      final toCache = _pdfFiles.map((p) => p.toCacheMap()).toList();
      await _cacheService.cacheData('pdfs_$categoryId', json.encode(toCache));
    } catch (e) {
      debugPrint('Error fetching PDFs: $e');
    } finally {
      _isLoadingPdfs = false;
      notifyListeners();
    }
  }

  // ===================== QUESTIONS (WITH CACHE) =====================
  Future<void> loadQuestions(String categoryId) async {
    _isLoadingQuestions = true;
    notifyListeners();

    // 1. Try Cache
    final cached = _cacheService.getCachedData('questions_$categoryId');
    if (cached != null) {
      try {
        final List<dynamic> decoded = json.decode(cached);
        _questions = decoded.map((item) => QuestionModel.fromMap(item['id'] ?? '', Map<String, dynamic>.from(item))).toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error parsing cached questions: $e');
      }
    }

    try {
      final list = await _firestoreService.getQuestionsByCategory(categoryId).timeout(
        const Duration(seconds: 5),
      );
      _questions = list;

      final toCache = _questions.map((q) => q.toCacheMap()).toList();
      await _cacheService.cacheData('questions_$categoryId', json.encode(toCache));
    } catch (e) {
      debugPrint('Error fetching questions: $e');
    } finally {
      _isLoadingQuestions = false;
      notifyListeners();
    }
  }
}
