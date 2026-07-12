import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_constants.dart';
import '../../models/course_model.dart';
import '../../services/firestore_service.dart';
import 'add_edit_course_screen.dart';

class CoursesManagementScreen extends StatefulWidget {
  const CoursesManagementScreen({super.key});

  @override
  State<CoursesManagementScreen> createState() => _CoursesManagementScreenState();
}

class _CoursesManagementScreenState extends State<CoursesManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedCategoryId;
  List<CourseModel> _courses = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    if (AppConstants.categories.isNotEmpty) {
      _selectedCategoryId = AppConstants.categories.keys.first;
      _loadCourses(isRefresh: true);
    }
  }

  // تحميل الكورسات للقسم المحدد
  Future<void> _loadCourses({bool isRefresh = false}) async {
    if (_selectedCategoryId == null) return;

    if (isRefresh) {
      setState(() {
        _lastDocument = null;
        _hasMore = true;
        _courses = [];
      });
    }

    if (!_hasMore) return;

    setState(() {
      if (isRefresh) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      QuerySnapshot querySnap;
      bool fallbackApplied = false;
      try {
        querySnap = await _firestoreService.getCoursesQueryPaginated(
          _selectedCategoryId!,
          startAfter: _lastDocument,
          limit: 10,
        );
      } catch (e) {
        debugPrint('Firestore query with orderBy order failed. Applying local fallback. Error: $e');
        fallbackApplied = true;
        Query query = FirebaseFirestore.instance.collection('courses')
            .where('categoryId', isEqualTo: _selectedCategoryId!);
        if (_lastDocument != null) {
          query = query.startAfterDocument(_lastDocument!);
        }
        querySnap = await query.limit(50).get();
      }

      List<CourseModel> courses = querySnap.docs.map((doc) => CourseModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map))).toList();

      if (fallbackApplied) {
        courses.sort((a, b) => a.order.compareTo(b.order));
      }

      setState(() {
        if (isRefresh) {
          _courses = courses;
        } else {
          _courses.addAll(courses);
        }

        if (querySnap.docs.length < (fallbackApplied ? 50 : 10)) {
          _hasMore = false;
        } else {
          _lastDocument = querySnap.docs.last;
        }
      });
    } catch (e) {
      print('خطأ في تحميل الكورسات: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تحميل الكورسات، يرجى المحاولة مرة أخرى', textAlign: TextAlign.right),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }


  // حذف كورس مع تأكيد
  void _deleteCourse(CourseModel course) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'حذف الكورس؟',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف الكورس (${course.title}) نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
            textAlign: TextAlign.right,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
              onPressed: () async {
                Navigator.pop(dialogContext);
                setState(() {
                  _isLoading = true;
                });
                try {
                  await _firestoreService.deleteCourse(course.id);
                  await _loadCourses(isRefresh: true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حذف الكورس بنجاح', textAlign: TextAlign.right),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('خطأ أثناء الحذف: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('فشل حذف الكورس', textAlign: TextAlign.right),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
  }

  // التنقل لشاشة الإضافة/التعديل
  Future<void> _navigateToAddEditScreen({CourseModel? course}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCourseScreen(
          course: course,
          initialCategoryId: _selectedCategoryId,
        ),
      ),
    );

    if (result == true) {
      _loadCourses(isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الكورسات والدروس'),
        actions: [
          IconButton(
            tooltip: 'إضافة كورس جديد',
            icon: const Icon(Icons.add_rounded, color: Color(0xFF03DAC6)),
            onPressed: () => _navigateToAddEditScreen(),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط الأقسام الأفقي
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: AppConstants.categories.length,
              itemBuilder: (context, index) {
                final key = AppConstants.categories.keys.elementAt(index);
                final name = AppConstants.categories[key]!;
                final isSelected = _selectedCategoryId == key;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: isSelected,
                    selectedColor: theme.primaryColor.withValues(alpha: 0.25),
                    checkmarkColor: theme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? theme.primaryColor : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategoryId = key;
                        });
                        _loadCourses(isRefresh: true);
                      }
                    },
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // قائمة الكورسات
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _courses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library_outlined, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد كورسات مضافة في هذا القسم بعد',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _navigateToAddEditScreen(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('أضف كورسك الأول الآن'),
                            )
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12.0),
                        itemCount: _courses.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _courses.length) {
                            if (_hasMore) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: _isLoadingMore
                                      ? const CircularProgressIndicator()
                                      : ElevatedButton(
                                          onPressed: () => _loadCourses(),
                                          child: const Text('تحميل المزيد من الكورسات'),
                                        ),
                                ),
                              );
                            } else {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    'تم تحميل كل الكورسات',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              );
                            }
                          }
                          final course = _courses[index];
                          return _buildCourseCard(context, course);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // كرت عرض الكورس
  Widget _buildCourseCard(BuildContext context, CourseModel course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToAddEditScreen(course: course),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ترتيب العرض: ${course.order}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  // شارة مجاني/مدفوع ومفتاح التفعيل
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: course.isFree
                              ? Colors.teal.shade900.withValues(alpha: 0.5)
                              : Colors.purple.shade900.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: course.isFree ? Colors.teal : Colors.purple,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          course.isFree ? 'مجاني 🆓' : 'مدفوع 🔒',
                          style: TextStyle(
                            fontSize: 11,
                            color: course.isFree ? Colors.tealAccent : Colors.purpleAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: course.isActive,
                          activeColor: Colors.tealAccent,
                          onChanged: (val) async {
                            setState(() {
                              final index = _courses.indexWhere((c) => c.id == course.id);
                              if (index != -1) {
                                _courses[index] = course.copyWith(isActive: val);
                              }
                            });
                            try {
                              await _firestoreService.updateCourse(course.copyWith(isActive: val));
                            } catch (e) {
                              setState(() {
                                final index = _courses.indexWhere((c) => c.id == course.id);
                                if (index != -1) {
                                  _courses[index] = course;
                                }
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('خطأ أثناء تحديث حالة الكورس: $e', textAlign: TextAlign.right),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (course.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  course.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Divider(color: Colors.grey, height: 24, thickness: 0.5),
              Row(
                children: [
                  const Icon(Icons.link, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('رابط HLS (البث الآمن): ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Expanded(
                    child: Text(
                      course.hlsUrl.isNotEmpty ? 'متاح 🟢' : 'غير متوفر 🔴',
                      style: TextStyle(
                        fontSize: 12,
                        color: course.hlsUrl.isNotEmpty ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.download, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('رابط MP4 (للتحميل): ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Expanded(
                    child: Text(
                      course.mp4Url.isNotEmpty ? 'متاح 🟢' : 'غير متوفر 🔴',
                      style: TextStyle(
                        fontSize: 12,
                        color: course.mp4Url.isNotEmpty ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.grey, height: 24, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _deleteCourse(course),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    label: const Text('حذف', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                  const SizedBox(width: 4),
                  // زر معاينة الفيديو
                  if (course.hlsUrl.isNotEmpty || course.mp4Url.isNotEmpty)
                    IconButton(
                      tooltip: 'معاينة الفيديو',
                      icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.tealAccent, size: 26),
                      onPressed: () async {
                        final url = course.hlsUrl.isNotEmpty ? course.hlsUrl : course.mp4Url;
                        final uri = Uri.tryParse(url);
                        if (uri != null) {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('لا يمكن فتح رابط الفيديو')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToAddEditScreen(course: course),
                    icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                    label: const Text('تعديل', style: TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
