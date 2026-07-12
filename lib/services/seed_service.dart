import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_constants.dart';
import 'firestore_service.dart';

class SeedService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> seedAdmin() async {
    const String email = 'admin@alwidad.com';
    const String password = 'admin12345';
    
    try {
      // Check if already exists in FirebaseAuth
      UserCredential cred;
      try {
        cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          print('Admin auth already exists.');
          // Just sign in to get the UID, or we'll just set the firestore doc using email if we don't have UID
          // But actually if auth exists, we can sign in or skip. Let's try signing in.
          cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
        } else {
          rethrow;
        }
      }

      if (cred.user != null) {
        await _db.collection('users').doc(cred.user!.uid).set({
          'name': 'المدير العام (الأدمن)',
          'email': email,
          'phone': '+970599000000',
          'role': 'admin',
          'category': '',
          'isSubscribed': true,
          'deviceId': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Admin seeded successfully in Auth and Firestore!');
      }
    } catch (e) {
      print('Error seeding admin: $e');
    }
  }

  Future<void> seedDefaultSettings() async {
    try {
      final docRef = _db.collection('settings').doc('app_config');
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'introVideoUrl': AppConstants.defaultIntroVideoUrl,
          'bannerImages': AppConstants.defaultBannerImages,
          'introText': AppConstants.defaultIntroText,
          'whatsappNumber': AppConstants.defaultWhatsappNumber,
          'privacyPolicyUrl': 'https://alwidad-policy.web.app/privacy',
          'refundPolicyUrl': 'https://alwidad-policy.web.app/refund',
        });
        print('Default settings seeded successfully!');
      } else {
        print('Settings document already exists.');
      }
    } catch (e) {
      print('Error seeding settings: $e');
    }
  }

  Future<void> seedInitialContent() async {
    try {
      final categories = AppConstants.categories;
      
      for (var entry in categories.entries) {
        final catId = entry.key;
        final catName = entry.value;
        
        // Check courses for this category
        final courseSnap = await _db.collection('courses').where('categoryId', isEqualTo: catId).limit(1).get();
        if (courseSnap.docs.isEmpty) {
          // Course 1 (Free)
          await _db.collection('courses').add({
            'title': 'العمليات الحسابية والتأسيس - $catName (مجاني)',
            'description': 'فيديو تمهيدي وتأسيسي مجاني لمنهاج $catName مع تدريبات أساسية.',
            'categoryId': catId,
            'hlsUrl': 'https://video.gumlet.io/6a428b8f3583eb1726409087/6a46abece81b019c9740573c/main.m3u8',
            'mp4Url': 'https://video.gumlet.io/6a428b8f3583eb1726409087/6a46abece81b019c9740573c/download.mp4',
            'thumbnailUrl': 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=500',
            'isFree': true,
            'order': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Course 2 (Paid)
          await _db.collection('courses').add({
            'title': 'الدرس الأول: شرح الوحدة الأولى - $catName',
            'description': 'شرح تفصيلي للموضوع الأول من كتاب الطالب لمنهاج $catName.',
            'categoryId': catId,
            'hlsUrl': 'https://video.gumlet.io/6a428b8f3583eb1726409087/6a46aab718d11bffd520967a/main.m3u8',
            'mp4Url': 'https://video.gumlet.io/6a428b8f3583eb1726409087/6a46aab718d11bffd520967a/download.mp4',
            'thumbnailUrl': 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=500',
            'isFree': false,
            'order': 2,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Check PDFs for this category
        final pdfSnap = await _db.collection('pdf_files').where('categoryId', isEqualTo: catId).limit(1).get();
        if (pdfSnap.docs.isEmpty) {
          await _db.collection('pdf_files').add({
            'title': 'الملخص الشامل والمذكرة التوضيحية - $catName',
            'categoryId': catId,
            'driveUrl': 'https://education.github.com/git-cheat-sheet-education.pdf',
            'order': 1,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          await _db.collection('pdf_files').add({
            'title': 'أسئلة وتدريبات إضافية مع الحلول - $catName',
            'categoryId': catId,
            'driveUrl': 'https://education.github.com/git-cheat-sheet-education.pdf',
            'order': 2,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Check Questions/Tests for this category
        final questionSnap = await _db.collection('questions').where('categoryId', isEqualTo: catId).limit(1).get();
        if (questionSnap.docs.isEmpty) {
          await _db.collection('questions').add({
            'title': 'اختبار قياس مستوى ذكاء وسرعة - $catName',
            'categoryId': catId,
            'formUrl': 'https://docs.google.com/forms/d/e/1FAIpQLSfW7_84c6G5-kL6Xz_Nq9gJqK2jFfKspX04g_3c92k_l9d3fA/viewform?usp=sf_link',
            'order': 1,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          await _db.collection('questions').add({
            'title': 'الامتحان الإلكتروني التجريبي الأول - $catName',
            'categoryId': catId,
            'formUrl': 'https://docs.google.com/forms/d/e/1FAIpQLSfW7_84c6G5-kL6Xz_Nq9gJqK2jFfKspX04g_3c92k_l9d3fA/viewform?usp=sf_link',
            'order': 2,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      print('Initial course, pdf, and question content seeded for all categories successfully!');
    } catch (e) {
      print('Error seeding content: $e');
    }
  }

  Future<void> seedStudents() async {
    for (int i = 1; i <= 10; i++) {
      final String email = 'test$i@alwidad.com';
      const String password = '111111';
      final String name = 'طالب تجريبي $i';
      
      try {
        String? uid;
        UserCredential? cred;
        try {
          cred = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          uid = cred.user?.uid;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            print('User $email already exists in Auth. Looking up in Firestore...');
            final querySnap = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
            if (querySnap.docs.isNotEmpty) {
              uid = querySnap.docs.first.id;
            } else {
              print('User exists in Auth but not in Firestore. Attempting temporary sign-in to retrieve UID...');
              final tempCred = await _auth.signInWithEmailAndPassword(email: email, password: password);
              uid = tempCred.user?.uid;
              await _auth.signOut();
            }
          } else {
            print('Error creating user $email: ${e.message}');
            continue;
          }
        }
        
        if (uid != null) {
          await _db.collection('users').doc(uid).set({
            'name': name,
            'email': email,
            'phone': '+97059900000$i',
            'role': 'student',
            'category': 'scientific_1',
            'isSubscribed': false,
            'deviceId': '',
            'subscribedCategories': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('User $email seeded/updated successfully with isSubscribed: false!');
        }
      } catch (e) {
        print('Unknown error seeding user $email: $e');
      }
    }
  }

  Future<void> migrateExistingUsers() async {
    try {
      final snap = await _db.collection('users').where('role', isEqualTo: 'student').get();
      final batch = _db.batch();
      int count = 0;
      for (var doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        if (!data.containsKey('isSubscribed') || data['isSubscribed'] == null) {
          batch.update(doc.reference, {'isSubscribed': false});
          count++;
        }
      }
      if (count > 0) {
        await batch.commit();
        print('Migrated $count existing students to have isSubscribed: false.');
      } else {
        print('No students needed migration.');
      }
    } catch (e) {
      print('Error migrating existing users: $e');
    }
  }

  Future<void> seedAll() async {
    print('Starting all seeding operations...');
    await seedAdmin();
    await seedDefaultSettings();
    await seedInitialContent();
    await seedStudents();
    await migrateExistingUsers();
    // إضافة ملفات PDF وأسئلة تجريبية إن كانت فارغة
    try {
      final firestoreService = FirestoreService();
      await firestoreService.seedSampleData();
    } catch (e) {
      print('Error seeding sample data: $e');
    }
    print('All seeding operations completed!');
  }
}

