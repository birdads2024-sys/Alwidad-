import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/course_model.dart';
import '../models/pdf_file_model.dart';
import '../models/question_model.dart';
import '../models/app_settings_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===================== USERS MANAGEMENT =====================

  Future<void> createUserDocument(String uid, Map<String, dynamic> userData) async {
    await _db.collection('users').doc(uid).set(userData);
  }

  Future<DocumentSnapshot> getUserDocument(String uid) async {
    return await _db.collection('users').doc(uid).get();
  }

  Future<UserModel?> getUserModel(String uid) async {
    final doc = await getUserDocument(uid);
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map));
    }
    return null;
  }

  Future<void> updateUserField(String uid, String field, dynamic value) async {
    await _db.collection('users').doc(uid).update({
      field: value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserDocument(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearUserDeviceId(String uid) async {
    await updateUserField(uid, 'deviceId', '');
  }

  // Get users/students with Search, Filters, and Pagination
  Future<QuerySnapshot> getStudentsQuery({
    String? search,
    bool? isSubscribed,
    DocumentSnapshot? startAfter,
    int limit = 10,
  }) async {
    Query query;
    final searchText = search?.trim() ?? '';
    final searchClean = searchText.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final isEmail = searchText.contains('@');
    // رقم الهاتف: يبدأ بـ + أو أرقام فقط وطوله 7 أرقام على الأقل
    final isPhone = RegExp(r'^[\+]?\d{7,}$').hasMatch(searchClean);

    if (isEmail) {
      query = _db.collection('users')
          .where('role', isEqualTo: 'student')
          .where('email', isEqualTo: searchText.toLowerCase());
    } else if (isPhone) {
      // بحث برقم الهاتف: نجيب كل الطلاب ونفلتر محلياً (بدون orderBy لتجنب Index)
      query = _db.collection('users')
          .where('role', isEqualTo: 'student');
    } else {
      query = _db.collection('users').where('role', isEqualTo: 'student');
      if (isSubscribed != null) {
        query = query.where('isSubscribed', isEqualTo: isSubscribed);
      }
      if (searchText.isNotEmpty) {
        query = query
            .where('name', isGreaterThanOrEqualTo: searchText)
            .where('name', isLessThanOrEqualTo: '$searchText\uf8ff')
            .orderBy('name');
      } else {
        query = query.orderBy('createdAt', descending: true);
      }
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
    }

    // للبحث برقم الهاتف نجيب عدد أكبر ونفلتر محلياً
    final fetchLimit = isPhone ? 500 : limit;
    return await query.limit(fetchLimit).get();
  }

  // ===================== COURSES MANAGEMENT =====================

  Future<void> createCourse(CourseModel course) async {
    await _db.collection('courses').doc(course.id).set(course.toMap());
  }

  Future<void> updateCourse(CourseModel course) async {
    await _db.collection('courses').doc(course.id).update(course.toMap());
  }

  Future<void> deleteCourse(String courseId) async {
    await _db.collection('courses').doc(courseId).delete();
  }

  Future<List<CourseModel>> getCoursesByCategory(String categoryId) async {
    final snapshot = await _db.collection('courses')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) => CourseModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map))).toList();
  }

  Future<List<CourseModel>> getCoursesPaginated(String categoryId, {DocumentSnapshot? startAfter, int limit = 10}) async {
    Query query = _db.collection('courses')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('order');

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs.map((doc) => CourseModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map))).toList();
  }

  Future<QuerySnapshot> getCoursesQueryPaginated(String categoryId, {DocumentSnapshot? startAfter, int limit = 10}) async {
    Query query = _db.collection('courses')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('order');

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.limit(limit).get();
  }

  // ===================== PDF FILES MANAGEMENT =====================

  Future<void> createPdfFile(PdfFileModel pdf) async {
    await _db.collection('pdf_files').doc(pdf.id).set(pdf.toMap());
  }

  Future<void> updatePdfFile(PdfFileModel pdf) async {
    await _db.collection('pdf_files').doc(pdf.id).update(pdf.toMap());
  }

  Future<void> deletePdfFile(String pdfId) async {
    await _db.collection('pdf_files').doc(pdfId).delete();
  }

  Future<List<PdfFileModel>> getPdfFilesByCategory(String categoryId) async {
    final snapshot = await _db.collection('pdf_files')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) => PdfFileModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map))).toList();
  }

  Future<QuerySnapshot> getPdfFilesQueryPaginated(String categoryId, {DocumentSnapshot? startAfter, int limit = 10}) async {
    Query query = _db.collection('pdf_files')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('order');

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.limit(limit).get();
  }


  // ===================== QUESTIONS MANAGEMENT =====================

  Future<void> createQuestion(QuestionModel question) async {
    await _db.collection('questions').doc(question.id).set(question.toMap());
  }

  Future<void> updateQuestion(QuestionModel question) async {
    await _db.collection('questions').doc(question.id).update(question.toMap());
  }

  Future<void> deleteQuestion(String questionId) async {
    await _db.collection('questions').doc(questionId).delete();
  }

  Future<List<QuestionModel>> getQuestionsByCategory(String categoryId) async {
    final snapshot = await _db.collection('questions')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) => QuestionModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map))).toList();
  }

  Future<QuerySnapshot> getQuestionsQueryPaginated(String categoryId, {DocumentSnapshot? startAfter, int limit = 10}) async {
    Query query = _db.collection('questions')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('order');

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.limit(limit).get();
  }

  // ===================== APP CONFIG / SETTINGS =====================


  Future<AppSettingsModel?> getAppSettings() async {
    final doc = await _db.collection('settings').doc('app_config').get();
    if (doc.exists && doc.data() != null) {
      return AppSettingsModel.fromMap(Map<String, dynamic>.from(doc.data() as Map));
    }
    return null;
  }

  Future<void> updateAppSettings(AppSettingsModel settings) async {
    await _db.collection('settings').doc('app_config').set(settings.toMap());
  }

  /// يضيف/يحدّث بيانات تجريبية حقيقية لـ pdf_files و questions (يعمل overwrite دايمًا)
  Future<void> seedSampleData() async {
    const realPdfUrl = 'https://education.github.com/git-cheat-sheet-education.pdf';
    const realFormUrl = 'https://docs.google.com/forms/d/e/1FAIpQLSe4BVKR_v2HgOUzz3gMWnWkZsEo9jtaEzTzFKzKt0m4MHPKg/viewform';

    final samplePdfs = [
      // توجيهي علمي فصل أول
      {'id': 'pdf_sci1_1', 'title': 'ملخص الرياضيات - الفصل الأول', 'categoryId': 'scientific_1', 'driveUrl': realPdfUrl, 'order': 1},
      {'id': 'pdf_sci1_2', 'title': 'ملخص الفيزياء - الفصل الأول', 'categoryId': 'scientific_1', 'driveUrl': realPdfUrl, 'order': 2},
      {'id': 'pdf_sci1_3', 'title': 'ملخص الكيمياء - الفصل الأول', 'categoryId': 'scientific_1', 'driveUrl': realPdfUrl, 'order': 3},
      // توجيهي علمي فصل ثاني
      {'id': 'pdf_sci2_1', 'title': 'ملخص الرياضيات - الفصل الثاني', 'categoryId': 'scientific_2', 'driveUrl': realPdfUrl, 'order': 1},
      {'id': 'pdf_sci2_2', 'title': 'ملخص الأحياء - الفصل الثاني', 'categoryId': 'scientific_2', 'driveUrl': realPdfUrl, 'order': 2},
      // توجيهي أدبي فصل أول
      {'id': 'pdf_lit1_1', 'title': 'ملخص اللغة العربية - الفصل الأول', 'categoryId': 'literary_1', 'driveUrl': realPdfUrl, 'order': 1},
      {'id': 'pdf_lit1_2', 'title': 'ملخص التاريخ والجغرافيا - الفصل الأول', 'categoryId': 'literary_1', 'driveUrl': realPdfUrl, 'order': 2},
      // توجيهي أدبي فصل ثاني
      {'id': 'pdf_lit2_1', 'title': 'ملخص اللغة العربية - الفصل الثاني', 'categoryId': 'literary_2', 'driveUrl': realPdfUrl, 'order': 1},
      // حادي عشر فصل أول
      {'id': 'pdf_11_1', 'title': 'ملخص الرياضيات - الحادي عشر', 'categoryId': 'eleventh_1', 'driveUrl': realPdfUrl, 'order': 1},
      // حادي عشر فصل ثاني
      {'id': 'pdf_11_2_1', 'title': 'ملخص الأحياء - الحادي عشر ثاني', 'categoryId': 'eleventh_2', 'driveUrl': realPdfUrl, 'order': 1},
    ];

    final pdfBatch = _db.batch();
    for (final pdf in samplePdfs) {
      final docRef = _db.collection('pdf_files').doc(pdf['id'] as String);
      pdfBatch.set(docRef, {
        'title': pdf['title'],
        'categoryId': pdf['categoryId'],
        'driveUrl': pdf['driveUrl'],
        'order': pdf['order'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await pdfBatch.commit();
    debugPrint('✅ تم تحديث ملفات PDF التجريبية بنجاح'); // ignore: avoid_print

    final sampleQuestions = [
      // توجيهي علمي فصل أول
      {'id': 'q_sci1_1', 'title': 'أسئلة الرياضيات - الفصل الأول', 'categoryId': 'scientific_1', 'formUrl': realFormUrl, 'order': 1},
      {'id': 'q_sci1_2', 'title': 'أسئلة الفيزياء - الفصل الأول', 'categoryId': 'scientific_1', 'formUrl': realFormUrl, 'order': 2},
      // توجيهي علمي فصل ثاني
      {'id': 'q_sci2_1', 'title': 'أسئلة الرياضيات - الفصل الثاني', 'categoryId': 'scientific_2', 'formUrl': realFormUrl, 'order': 1},
      // توجيهي أدبي فصل أول
      {'id': 'q_lit1_1', 'title': 'أسئلة اللغة العربية - الفصل الأول', 'categoryId': 'literary_1', 'formUrl': realFormUrl, 'order': 1},
      // توجيهي أدبي فصل ثاني
      {'id': 'q_lit2_1', 'title': 'أسئلة التاريخ - الفصل الثاني', 'categoryId': 'literary_2', 'formUrl': realFormUrl, 'order': 1},
      // حادي عشر فصل أول
      {'id': 'q_11_1', 'title': 'أسئلة الرياضيات - الحادي عشر أول', 'categoryId': 'eleventh_1', 'formUrl': realFormUrl, 'order': 1},
      // حادي عشر فصل ثاني
      {'id': 'q_11_2_1', 'title': 'أسئلة الأحياء - الحادي عشر ثاني', 'categoryId': 'eleventh_2', 'formUrl': realFormUrl, 'order': 1},
    ];

    final qBatch = _db.batch();
    for (final q in sampleQuestions) {
      final docRef = _db.collection('questions').doc(q['id'] as String);
      qBatch.set(docRef, {
        'title': q['title'],
        'categoryId': q['categoryId'],
        'formUrl': q['formUrl'],
        'order': q['order'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await qBatch.commit();
    debugPrint('✅ تم تحديث الأسئلة التجريبية بنجاح'); // ignore: avoid_print
  }
}
