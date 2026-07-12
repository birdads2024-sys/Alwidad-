import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_constants.dart';
import '../../models/question_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/error_widget.dart';
import '../student/webview_screen.dart';

class QuestionsManagementScreen extends StatefulWidget {
  const QuestionsManagementScreen({super.key});

  @override
  State<QuestionsManagementScreen> createState() => _QuestionsManagementScreenState();
}

class _QuestionsManagementScreenState extends State<QuestionsManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedCategory = AppConstants.categories.keys.first;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  List<QuestionModel> _questionsList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestions(isRefresh: true);
  }

  Future<void> _loadQuestions({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _lastDocument = null;
        _hasMore = true;
        _questionsList = [];
      });
    }

    if (!_hasMore) return;

    setState(() {
      if (isRefresh) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
      _errorMessage = null;
    });

    try {
      QuerySnapshot querySnap;
      bool fallbackApplied = false;
      try {
        querySnap = await _firestoreService.getQuestionsQueryPaginated(
          _selectedCategory,
          startAfter: _lastDocument,
          limit: 10,
        );
      } catch (e) {
        debugPrint('Firestore query with orderBy failed. Applying local fallback. Error: $e');
        fallbackApplied = true;
        Query query = FirebaseFirestore.instance.collection('questions')
            .where('categoryId', isEqualTo: _selectedCategory);
        if (_lastDocument != null) {
          query = query.startAfterDocument(_lastDocument!);
        }
        querySnap = await query.limit(50).get();
      }

      List<QuestionModel> questions = querySnap.docs.map((doc) => QuestionModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map))).toList();

      if (fallbackApplied) {
        questions.sort((a, b) => a.order.compareTo(b.order));
      }

      setState(() {
        if (isRefresh) {
          _questionsList = questions;
        } else {
          _questionsList.addAll(questions);
        }

        if (querySnap.docs.length < (fallbackApplied ? 50 : 10)) {
          _hasMore = false;
        } else {
          _lastDocument = querySnap.docs.last;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء تحميل الاختبارات: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }


  void _showAddEditDialog([QuestionModel? question]) {
    final titleController = TextEditingController(text: question?.title ?? '');
    final urlController = TextEditingController(text: question?.formUrl ?? '');
    final orderController = TextEditingController(text: question?.order.toString() ?? '0');
    String dialogCategory = question?.categoryId ?? _selectedCategory;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A24),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              question == null ? 'إضافة اختبار جديد' : 'تعديل الاختبار',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: titleController,
                          labelText: 'عنوان الاختبار',
                          hintText: 'مثال: اختبار الشهر الأول - الهندسة التحليلية',
                          prefixIcon: const Icon(Icons.assignment_turned_in_rounded),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال عنوان الاختبار';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: urlController,
                          labelText: 'رابط اختبار نماذج جوجل (Google Forms Link)',
                          hintText: 'https://docs.google.com/forms/...',
                          prefixIcon: const Icon(Icons.link_rounded),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال رابط الاختبار';
                            }
                            if (!value.startsWith('http')) {
                              return 'يرجى إدخال رابط صحيح يبدأ بـ http';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: dialogCategory,
                                dropdownColor: const Color(0xFF1A1A24),
                                decoration: InputDecoration(
                                  labelText: 'الفئة / القسم',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                items: AppConstants.categories.entries.map((entry) {
                                  return DropdownMenuItem<String>(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      dialogCategory = value;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: CustomTextField(
                                controller: orderController,
                                labelText: 'الترتيب',
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.sort_rounded),
                                validator: (value) {
                                  if (value == null || int.tryParse(value) == null) {
                                    return 'غير صحيح';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  setDialogState(() {
                                    isSaving = true;
                                  });

                                  try {
                                    final id = question?.id ?? FirebaseFirestore.instance.collection('questions').doc().id;
                                    final newQuestion = QuestionModel(
                                      id: id,
                                      title: titleController.text.trim(),
                                      categoryId: dialogCategory,
                                      formUrl: urlController.text.trim(),
                                      order: int.parse(orderController.text.trim()),
                                      isActive: question?.isActive ?? true,
                                      createdAt: question?.createdAt ?? DateTime.now(),
                                    );

                                    if (question == null) {
                                      await _firestoreService.createQuestion(newQuestion);
                                    } else {
                                      await _firestoreService.updateQuestion(newQuestion);
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(question == null ? 'تمت إضافة الاختبار بنجاح' : 'تم تعديل الاختبار بنجاح'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      _loadQuestions(isRefresh: true);
                                    }
                                  } catch (e) {
                                    setDialogState(() {
                                      isSaving = false;
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('حدث خطأ أثناء الحفظ: $e'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                )
                              : Text(question == null ? 'إضافة الاختبار' : 'حفظ التعديلات'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteQuestion(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('حذف الاختبار', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذا الاختبار نهائياً؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _firestoreService.deleteQuestion(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الاختبار بنجاح'), backgroundColor: Colors.green),
          );
          _loadQuestions(isRefresh: true);
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء حذف الاختبار: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الاختبارات والروابط'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'إضافة اختبار جديد',
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Selector Tabs
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.5),
              border: Border(bottom: BorderSide(color: Colors.grey.shade900)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: AppConstants.categories.length,
              itemBuilder: (context, index) {
                final entry = AppConstants.categories.entries.elementAt(index);
                final isSelected = entry.key == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(
                      entry.value,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade400,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surface,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = entry.key;
                        });
                        _loadQuestions(isRefresh: true);
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // Main content list
          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'جاري تحميل الاختبارات...')
                : _errorMessage != null
                    ? CustomErrorWidget(errorMessage: _errorMessage!, onRetry: _loadQuestions)
                    : _questionsList.isEmpty
                        ? EmptyStateWidget(
                            title: 'لا يوجد اختبارات حالياً',
                            message: 'لم يتم العثور على اختبارات في هذا القسم، اضغط على زر الإضافة لإضافة اختبار جديد.',
                            icon: Icons.quiz_outlined,
                            actionLabel: 'إضافة اختبار جديد',
                            onActionPressed: () => _showAddEditDialog(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _questionsList.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _questionsList.length) {
                                if (_hasMore) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? const CircularProgressIndicator()
                                          : ElevatedButton(
                                              onPressed: () => _loadQuestions(),
                                              child: const Text('تحميل المزيد من الاختبارات'),
                                            ),
                                    ),
                                  );
                                } else {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Center(
                                      child: Text(
                                        'تم تحميل كل الاختبارات',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  );
                                }
                              }
                              final question = _questionsList[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                            child: Icon(Icons.assignment_rounded, color: theme.colorScheme.primary),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  question.title,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'الترتيب: ${question.order}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Transform.scale(
                                            scale: 0.8,
                                            child: Switch(
                                              value: question.isActive,
                                              activeColor: theme.colorScheme.primary,
                                              onChanged: (val) async {
                                                setState(() {
                                                  final index = _questionsList.indexWhere((q) => q.id == question.id);
                                                  if (index != -1) {
                                                    _questionsList[index] = question.copyWith(isActive: val);
                                                  }
                                                });
                                                try {
                                                  await _firestoreService.updateQuestion(question.copyWith(isActive: val));
                                                } catch (e) {
                                                  setState(() {
                                                    final index = _questionsList.indexWhere((q) => q.id == question.id);
                                                    if (index != -1) {
                                                      _questionsList[index] = question;
                                                    }
                                                  });
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('خطأ أثناء تحديث حالة الاختبار: $e', textAlign: TextAlign.right),
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
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8.0),
                                        child: Divider(height: 1, thickness: 1, color: Colors.white10),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () {
                                              if (question.formUrl.isNotEmpty) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => WebViewScreen(
                                                      url: question.formUrl,
                                                      title: question.title,
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('الرابط غير متوفر', textAlign: TextAlign.right),
                                                    backgroundColor: Colors.redAccent,
                                                  ),
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.visibility_rounded, size: 16),
                                            label: const Text('عرض', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.blue,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          TextButton.icon(
                                            onPressed: () => _showAddEditDialog(question),
                                            icon: const Icon(Icons.edit_rounded, size: 16),
                                            label: const Text('تعديل', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.amber,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          TextButton.icon(
                                            onPressed: () => _deleteQuestion(question.id),
                                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                            label: const Text('حذف', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.redAccent,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
