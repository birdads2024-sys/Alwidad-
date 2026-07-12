import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/admin_students_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/student_card.dart';
import '../../config/app_constants.dart';

class StudentsManagementScreen extends StatefulWidget {
  const StudentsManagementScreen({super.key});

  @override
  State<StudentsManagementScreen> createState() => _StudentsManagementScreenState();
}

class _StudentsManagementScreenState extends State<StudentsManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // تحميل البيانات عند فتح الشاشة لأول مرة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminStudentsProvider>().loadStudents(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // دالة لعرض نافذة تعديل اسم الطالب
  void _showEditNameDialog(BuildContext context, UserModel student) {
    final nameController = TextEditingController(text: student.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'تعديل اسم الطالب',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'الاسم الجديد',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال الاسم';
                }
                return null;
              },
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final success = await context
                      .read<AdminStudentsProvider>()
                      .editStudentName(student.uid, nameController.text.trim());
                  
                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'تم تحديث الاسم بنجاح' : 'فشل تحديث الاسم',
                          textAlign: TextAlign.right,
                        ),
                        backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  // دالة لتأكيد وإعادة تعيين معرّف الجهاز
  void _showResetDeviceDialog(BuildContext context, UserModel student) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'إعادة تعيين الجهاز؟',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في إلغاء قفل جهاز الطالب (${student.name})؟ سيتمكن من تسجيل الدخول من هاتف جديد.',
            textAlign: TextAlign.right,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900),
              onPressed: () async {
                final success = await context
                    .read<AdminStudentsProvider>()
                    .resetDeviceId(student.uid);
                
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'تم إلغاء قفل الجهاز بنجاح' : 'فشل إلغاء قفل الجهاز',
                        textAlign: TextAlign.right,
                      ),
                      backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  );
                }
              },
              child: const Text('إلغاء القفل'),
            ),
          ],
        );
      },
    );
  }

  // دالة لتغيير حالة الاشتراك وتحديد الأقسام المشترك بها الطالب
  void _showToggleSubscriptionDialog(BuildContext context, UserModel student) {
    // سنستخدم StatefulBuilder للحفاظ على حالة الاختيارات داخل الـ Dialog
    List<String> selectedCategories = List<String>.from(student.subscribedCategories);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'تفعيل الاشتراك وتحديد الأقسام',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'اختر الأقسام التي تريد تفعيل اشتراك الطالب (${student.name}) فيها:',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      ...AppConstants.categories.entries.map((entry) {
                        final key = entry.key;
                        final value = entry.value;
                        final isChecked = selectedCategories.contains(key);
                        return CheckboxListTile(
                          title: Text(
                            value,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 14),
                          ),
                          value: isChecked,
                          activeColor: Theme.of(context).primaryColor,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (bool? checked) {
                            setState(() {
                              if (checked == true) {
                                if (!selectedCategories.contains(key)) {
                                  selectedCategories.add(key);
                                }
                              } else {
                                selectedCategories.remove(key);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                // زر إلغاء الاشتراك بالكامل
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                  ),
                  onPressed: () async {
                    final success = await context
                        .read<AdminStudentsProvider>()
                        .updateSubscription(student.uid, false, []);

                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'تم إلغاء الاشتراك بنجاح',
                            textAlign: TextAlign.right,
                          ),
                          backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      );
                    }
                  },
                  child: const Text('إلغاء الاشتراك'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade800,
                      ),
                      onPressed: () async {
                        // تفعيل الاشتراك مع الأقسام المحددة
                        final success = await context
                            .read<AdminStudentsProvider>()
                            .updateSubscription(student.uid, true, selectedCategories);

                        if (context.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success ? 'تم تفعيل الاشتراك بنجاح' : 'فشل تعديل الاشتراك',
                                textAlign: TextAlign.right,
                              ),
                              backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          );
                        }
                      },
                      child: const Text('تفعيل'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // تصدير ملف الإكسل
  void _exportStudentsList(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري تحضير وتصدير ملف الإكسل...', textAlign: TextAlign.right),
        duration: Duration(seconds: 1),
      ),
    );

    final filePath = await context.read<AdminStudentsProvider>().exportStudents();
    
    if (context.mounted) {
      if (filePath != null) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('تم تصدير ملف الطلاب بنجاح 🎉', textAlign: TextAlign.right),
            content: const Text(
              'يمكنك الآن فتح الملف مباشرة أو مشاركته عبر التطبيقات المختلفة.',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      try {
                        debugPrint('Attempting to share file: $filePath');
                        final file = File(filePath);
                        if (!await file.exists()) {
                          debugPrint('File does not exist at path: $filePath');
                          return;
                        }
                        await Share.shareXFiles([XFile(filePath)], text: 'ملف الطلاب من منصة الوداد');
                      } catch (e) {
                        debugPrint('Error sharing file: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('حدث خطأ أثناء المشاركة: $e', textAlign: TextAlign.right),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('مشاركة'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      try {
                        debugPrint('Attempting to open file: $filePath');
                        final file = File(filePath);
                        if (!await file.exists()) {
                          debugPrint('File does not exist at path: $filePath');
                          return;
                        }
                        final result = await OpenFilex.open(filePath);
                        debugPrint('OpenFilex result type: ${result.type}, message: ${result.message}');
                        if (result.type != ResultType.done && context.mounted) {
                          String errorMsg = 'تعذر فتح الملف';
                          if (result.type == ResultType.noAppToOpen) {
                            errorMsg = 'لا يوجد تطبيق مثبت لفتح ملفات الإكسيل (.xlsx)';
                          } else if (result.type == ResultType.permissionDenied) {
                            errorMsg = 'تم رفض الإذن لفتح الملف';
                          } else if (result.type == ResultType.fileNotFound) {
                            errorMsg = 'لم يتم العثور على الملف';
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg, textAlign: TextAlign.right),
                              backgroundColor: Colors.amber.shade900,
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('Error opening file: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('حدث خطأ أثناء فتح الملف: $e', textAlign: TextAlign.right),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('فتح الملف'),
                  ),
                ],
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تصدير الطلاب إلى ملف Excel', textAlign: TextAlign.right),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminStudentsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلاب والاشتراكات'),
        actions: [
          IconButton(
            tooltip: 'تصدير إكسل',
            icon: const Icon(Icons.file_download, color: Color(0xFF03DAC6)),
            onPressed: () => _exportStudentsList(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحث باسم الطالب، هاتفه، أو بريده الإلكتروني...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
              ),
              onChanged: (value) {
                provider.setSearchQuery(value);
              },
            ),
          ),

          // أزرار الفلترة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(context, label: 'الكل', value: null),
                _buildFilterChip(context, label: 'مشترك كامل', value: true),
                _buildFilterChip(context, label: 'مجاني', value: false),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // قائمة الطلاب
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadStudents(isRefresh: true),
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade600),
                              const SizedBox(height: 16),
                              Text(
                                'لم يتم العثور على طلاب مطابقين للبحث',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12.0),
                          itemCount: provider.students.length + 1,
                          itemBuilder: (context, index) {
                            if (index == provider.students.length) {
                              if (provider.hasMore) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: Center(
                                    child: provider.isLoadingMore
                                        ? const CircularProgressIndicator()
                                        : ElevatedButton(
                                            onPressed: () => provider.loadStudents(),
                                            child: const Text('تحميل المزيد من الطلاب'),
                                          ),
                                  ),
                                );
                              } else {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: Center(
                                    child: Text(
                                      'تم تحميل كل الطلاب',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                );
                              }
                            }

                            final student = provider.students[index];
                            return StudentCard(
                              student: student,
                              indexNumber: provider.totalCount - index,
                              onSubscriptionToggled: (val) => _showToggleSubscriptionDialog(context, student),
                              onResetDeviceId: () => _showResetDeviceDialog(context, student),
                              onEditName: () => _showEditNameDialog(context, student),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  // ويدجت لبناء أزرار الفلترة
  Widget _buildFilterChip(BuildContext context, {required String label, required bool? value}) {
    final provider = Provider.of<AdminStudentsProvider>(context, listen: false);
    final isSelected = provider.filterSubscribed == value;
    final primaryColor = Theme.of(context).primaryColor;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor.withValues(alpha: 0.25),
      checkmarkColor: primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          provider.setFilter(value);
        }
      },
    );
  }
}
