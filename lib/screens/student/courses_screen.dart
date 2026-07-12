import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courses_provider.dart';
import '../../config/app_constants.dart';
import '../../models/course_model.dart';
import 'course_videos_screen.dart';
import '../../widgets/course_card.dart';
import '../../widgets/shimmer_loading.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({Key? key}) : super(key: key);

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  String? _selectedCategoryId;
  String? _lastLoadedCategoryId;

  @override
  void initState() {
    super.initState();
    // Default select student's first subscribed category
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUserModel;
    if (user != null) {
      if (user.subscribedCategories.isNotEmpty) {
        _selectedCategoryId = user.subscribedCategories.first;
      } else if (user.category.isNotEmpty) {
        _selectedCategoryId = user.category;
      }
    }
  }

  void _loadCoursesForSelectedCategory({bool refresh = false}) {
    if (_selectedCategoryId != null) {
      Provider.of<CoursesProvider>(context, listen: false)
          .loadCourses(_selectedCategoryId!, refresh: refresh);
    }
  }

  void _navigateToWhatsapp(String courseTitle) async {
    final coursesProvider = Provider.of<CoursesProvider>(context, listen: false);
    String phone = coursesProvider.appSettings?.whatsappNumber ?? AppConstants.defaultWhatsappNumber;
    
    // Clean up phone number format if necessary (should be e.g. +970599000000)
    phone = phone.replaceAll('+', '').replaceAll(' ', '');
    
    final message = Uri.encodeComponent('اريد تفعيل الاشتراك');
    final url = 'https://wa.me/$phone?text=$message';
    
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح تطبيق واتساب حالياً. الرجاء المحاولة لاحقاً.')),
        );
      }
    }
  }

  void _showSubscriptionDialog(CourseModel course) {
    final isIos = Platform.isIOS;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIos ? 'محتوى مخصص للطلاب 📚' : 'محتوى مدفوع 🔒'),
        content: Text(isIos
            ? 'هذا المحتوى مخصص للطلاب المسجلين بالفصل الدراسي. لطلب المساعدة أو للاستفسار الفني يرجى التواصل مع الدعم الفني.'
            : 'هذا الكورس غير مجاني ومخصص للمشتركين فقط. للاشتراك وتفعيل المحتوى، يرجى التواصل مع الإدارة عبر الواتساب.'),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(isIos ? 'تواصل مع الدعم الفني' : 'تواصل للاشتراك'),
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToWhatsapp(course.title);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final coursesProvider = Provider.of<CoursesProvider>(context);
    
    final user = auth.currentUserModel;
    final isSubscribed = user?.isSubscribed ?? false;

    // تهيئة ذكية لتفادي التعليق عند أول دخول للـ Gmail/Apple Sign-in
    if (_selectedCategoryId == null && user != null) {
      if (user.subscribedCategories.isNotEmpty) {
        _selectedCategoryId = user.subscribedCategories.first;
      } else if (user.category.isNotEmpty) {
        _selectedCategoryId = user.category;
      }
    }

    if (_selectedCategoryId != null && _selectedCategoryId != _lastLoadedCategoryId) {
      _lastLoadedCategoryId = _selectedCategoryId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCoursesForSelectedCategory(refresh: true);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الكورسات التعليمية'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Category Selector Horizontal list
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: AppConstants.categories.entries.where((entry) {
                final user = auth.currentUserModel;
                if (user == null) return false;
                if (user.role == 'admin') return true;
                
                final subscribed = user.subscribedCategories.isNotEmpty 
                    ? user.subscribedCategories 
                    : [user.category];
                return subscribed.contains(entry.key);
              }).map((entry) {
                final isSelected = _selectedCategoryId == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      entry.value,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.grey.shade400,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: theme.primaryColor,
                    backgroundColor: theme.colorScheme.surface,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategoryId = entry.key;
                        });
                        _loadCoursesForSelectedCategory(refresh: true);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Courses List
          Expanded(
            child: _selectedCategoryId == null
                ? const Center(child: Text('الرجاء اختيار قسم لعرض الكورسات'))
                : Consumer<CoursesProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoadingCourses && provider.courses.isEmpty) {
                        return ShimmerLoading.buildCourseList(context);
                      }

                      if (provider.courses.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                size: 64,
                                color: theme.primaryColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'لا توجد كورسات في هذا القسم حالياً',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          _loadCoursesForSelectedCategory(refresh: true);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.courses.length + (provider.hasMoreCourses ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == provider.courses.length) {
                              // Load More Button
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: provider.isLoadingCourses
                                      ? const CircularProgressIndicator()
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.colorScheme.surface,
                                            foregroundColor: theme.primaryColor,
                                          ),
                                          onPressed: () {
                                            _loadCoursesForSelectedCategory();
                                          },
                                          child: const Text('تحميل المزيد 📥'),
                                        ),
                                ),
                              );
                            }

                            final course = provider.courses[index];
                            return CourseCard(
                              course: course,
                              isSubscribed: isSubscribed,
                              onTap: () {
                                final isLocked = !course.isFree && !isSubscribed;
                                if (isLocked) {
                                  _showSubscriptionDialog(course);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CourseVideosScreen(course: course),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
