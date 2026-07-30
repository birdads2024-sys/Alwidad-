import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courses_provider.dart';
import '../../config/app_constants.dart';
import 'webview_screen.dart';
import '../../widgets/shimmer_loading.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({Key? key}) : super(key: key);

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String? _selectedCategoryId;
  String? _lastLoadedCategoryId;

  @override
  void initState() {
    super.initState();
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

  void _navigateToWhatsapp() async {
    final coursesProvider = Provider.of<CoursesProvider>(context, listen: false);
    String phone = coursesProvider.appSettings?.whatsappNumber ?? AppConstants.defaultWhatsappNumber;
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

  Widget _buildLockedUI(ThemeData theme) {
    final isIos = Platform.isIOS;
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 80,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'محتوى مخصص للطلاب المسجلين 📚',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'هذا القسم مخصص لطلاب الفصل الدراسي المسجلين.',
              style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ThemeData theme, dynamic user) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: AppConstants.categories.entries.where((entry) {
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
                if (selected && _selectedCategoryId != entry.key) {
                  setState(() {
                    _selectedCategoryId = entry.key;
                    _lastLoadedCategoryId = null; // trigger reload
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPdfTab() {
    return Consumer<CoursesProvider>(
      builder: (context, coursesProvider, child) {
        if (coursesProvider.isLoadingPdfs && coursesProvider.pdfFiles.isEmpty) {
          return ShimmerLoading.buildTileList(context);
        }

        if (coursesProvider.pdfFiles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 64,
                  color: Colors.redAccent.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد ملفات PDF متوفرة حالياً لهذا القسم.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (_selectedCategoryId != null) {
              await coursesProvider.loadPdfFiles(_selectedCategoryId!);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: coursesProvider.pdfFiles.length,
            itemBuilder: (context, index) {
              final pdf = coursesProvider.pdfFiles[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x26FF5252),
                    child: Icon(Icons.picture_as_pdf, color: Colors.red),
                  ),
                  title: Text(
                    pdf.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        tooltip: 'معاينة',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WebViewScreen(
                                url: pdf.driveUrl,
                                title: pdf.title,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.green),
                        tooltip: 'تحميل',
                        onPressed: () async {
                          final uri = Uri.parse(pdf.driveUrl);
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('لا يمكن فتح رابط التحميل')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WebViewScreen(
                          url: pdf.driveUrl,
                          title: pdf.title,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildQuestionsTab(ThemeData theme) {
    return Consumer<CoursesProvider>(
      builder: (context, coursesProvider, child) {
        if (coursesProvider.isLoadingQuestions && coursesProvider.questions.isEmpty) {
          return ShimmerLoading.buildTileList(context);
        }

        if (coursesProvider.questions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.question_answer_outlined,
                  size: 64,
                  color: theme.primaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد اختبارات متوفرة حالياً لهذا القسم.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (_selectedCategoryId != null) {
              await coursesProvider.loadQuestions(_selectedCategoryId!);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: coursesProvider.questions.length,
            itemBuilder: (context, index) {
              final question = coursesProvider.questions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                    child: Icon(Icons.description, color: theme.primaryColor),
                  ),
                  title: Text(
                    question.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.blue),
                    tooltip: 'معاينة',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebViewScreen(
                            url: question.formUrl,
                            title: question.title,
                          ),
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WebViewScreen(
                          url: question.formUrl,
                          title: question.title,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUserModel;
    final isSubscribed = user?.isSubscribed ?? false;

    // تعيين القسم الافتراضي لأول مرة عند توفر بيانات المستخدم
    if (_selectedCategoryId == null && user != null) {
      if (user.subscribedCategories.isNotEmpty) {
        _selectedCategoryId = user.subscribedCategories.first;
      } else if (user.category.isNotEmpty) {
        _selectedCategoryId = user.category;
      }
    }

    // جلب البيانات عند التغيير فقط للمستخدمين المشتركين
    if (isSubscribed && _selectedCategoryId != null && _selectedCategoryId != _lastLoadedCategoryId) {
      _lastLoadedCategoryId = _selectedCategoryId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = Provider.of<CoursesProvider>(context, listen: false);
        provider.loadPdfFiles(_selectedCategoryId!);
        provider.loadQuestions(_selectedCategoryId!);
      });
    }

    if (!isSubscribed) {
      // على iOS: شاشة ترحيبية بسيطة بدون أي إشارة للقفل أو اشتراك
      if (Platform.isIOS) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('الملفات والاختبارات'),
            centerTitle: true,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 80,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'مرحباً بك في منصة الوداد للرياضيات 📚',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تواصل مع إدارة المركز لتفعيل حسابك.',
                    style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('الملفات والاختبارات'),
          centerTitle: true,
        ),
        body: _buildLockedUI(theme),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الملفات والاختبارات'),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: theme.primaryColor,
            labelColor: theme.primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: const [
              Tab(
                text: 'ملفات PDF والملخصات',
                icon: Icon(Icons.picture_as_pdf_outlined),
              ),
              Tab(
                text: 'الاختبارات',
                icon: Icon(Icons.quiz_outlined),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildCategorySelector(theme, user),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPdfTab(),
                  _buildQuestionsTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
