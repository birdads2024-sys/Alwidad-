import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courses_provider.dart';
import '../../config/app_constants.dart';
import 'webview_screen.dart';
import '../../widgets/shimmer_loading.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({Key? key}) : super(key: key);

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUserModel;

    // تعيين القسم الافتراضي لأول مرة عند توفر بيانات المستخدم
    if (_selectedCategoryId == null && user != null) {
      if (user.subscribedCategories.isNotEmpty) {
        _selectedCategoryId = user.subscribedCategories.first;
      } else if (user.category.isNotEmpty) {
        _selectedCategoryId = user.category;
      }
    }

    // جلب اختبارات القسم المختار عند التغيير فقط
    if (_selectedCategoryId != null && _selectedCategoryId != _lastLoadedCategoryId) {
      _lastLoadedCategoryId = _selectedCategoryId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<CoursesProvider>(context, listen: false)
            .loadQuestions(_selectedCategoryId!);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاختبارات'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Category Selector Horizontal tabs
          Container(
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
          ),

          // Questions List
          Expanded(
            child: _selectedCategoryId == null
                ? const Center(child: Text('الرجاء اختيار قسم لعرض الاختبارات'))
                : Consumer<CoursesProvider>(
                    builder: (context, coursesProvider, child) {
                      if (coursesProvider.isLoadingQuestions &&
                          coursesProvider.questions.isEmpty) {
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
                            await coursesProvider
                                .loadQuestions(_selectedCategoryId!);
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
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.primaryColor.withValues(alpha: 0.15),
                                  child: Icon(Icons.description,
                                      color: theme.primaryColor),
                                ),
                                title: Text(
                                  question.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.visibility,
                                      color: Colors.blue),
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
                  ),
          ),
        ],
      ),
    );
  }
}
