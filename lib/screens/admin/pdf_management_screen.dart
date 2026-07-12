import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_constants.dart';
import '../../models/pdf_file_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/error_widget.dart';
import '../student/webview_screen.dart';

class PdfManagementScreen extends StatefulWidget {
  const PdfManagementScreen({super.key});

  @override
  State<PdfManagementScreen> createState() => _PdfManagementScreenState();
}

class _PdfManagementScreenState extends State<PdfManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedCategory = AppConstants.categories.keys.first;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  List<PdfFileModel> _pdfList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdfs(isRefresh: true);
  }

  Future<void> _loadPdfs({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _lastDocument = null;
        _hasMore = true;
        _pdfList = [];
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
        querySnap = await _firestoreService.getPdfFilesQueryPaginated(
          _selectedCategory,
          startAfter: _lastDocument,
          limit: 10,
        );
      } catch (e) {
        debugPrint('Firestore query with orderBy failed. Applying local fallback. Error: $e');
        fallbackApplied = true;
        Query query = FirebaseFirestore.instance.collection('pdf_files')
            .where('categoryId', isEqualTo: _selectedCategory);
        if (_lastDocument != null) {
          query = query.startAfterDocument(_lastDocument!);
        }
        querySnap = await query.limit(50).get();
      }

      List<PdfFileModel> pdfs = querySnap.docs.map((doc) => PdfFileModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map))).toList();

      if (fallbackApplied) {
        pdfs.sort((a, b) => a.order.compareTo(b.order));
      }

      setState(() {
        if (isRefresh) {
          _pdfList = pdfs;
        } else {
          _pdfList.addAll(pdfs);
        }

        if (querySnap.docs.length < (fallbackApplied ? 50 : 10)) {
          _hasMore = false;
        } else {
          _lastDocument = querySnap.docs.last;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء تحميل الملفات: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }


  void _showAddEditDialog([PdfFileModel? pdf]) {
    final titleController = TextEditingController(text: pdf?.title ?? '');
    final urlController = TextEditingController(text: pdf?.driveUrl ?? '');
    final orderController = TextEditingController(text: pdf?.order.toString() ?? '0');
    String dialogCategory = pdf?.categoryId ?? _selectedCategory;
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
                              pdf == null ? 'إضافة ملف PDF جديد' : 'تعديل ملف PDF',
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
                          labelText: 'عنوان الملف',
                          hintText: 'مثال: أسئلة السنوات السابقة - الوحدة الأولى',
                          prefixIcon: const Icon(Icons.title_rounded),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال عنوان الملف';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: urlController,
                          labelText: 'رابط جوجل درايف (Drive URL)',
                          hintText: 'https://drive.google.com/...',
                          prefixIcon: const Icon(Icons.link_rounded),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال رابط الملف';
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
                                    final id = pdf?.id ?? FirebaseFirestore.instance.collection('pdf_files').doc().id;
                                    final newPdf = PdfFileModel(
                                      id: id,
                                      title: titleController.text.trim(),
                                      categoryId: dialogCategory,
                                      driveUrl: urlController.text.trim(),
                                      order: int.parse(orderController.text.trim()),
                                      isActive: pdf?.isActive ?? true,
                                      createdAt: pdf?.createdAt ?? DateTime.now(),
                                    );

                                    if (pdf == null) {
                                      await _firestoreService.createPdfFile(newPdf);
                                    } else {
                                      await _firestoreService.updatePdfFile(newPdf);
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(pdf == null ? 'تمت إضافة الملف بنجاح' : 'تم تعديل الملف بنجاح'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      _loadPdfs(isRefresh: true);
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
                              : Text(pdf == null ? 'إضافة الملف' : 'حفظ التعديلات'),
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

  Future<void> _deletePdf(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('حذف الملف', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذا الملف نهائياً؟', style: TextStyle(color: Colors.white70)),
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
        await _firestoreService.deletePdfFile(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الملف بنجاح'), backgroundColor: Colors.green),
          );
          _loadPdfs(isRefresh: true);
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء حذف الملف: $e';
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
        title: const Text('إدارة ملفات PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'إضافة ملف جديد',
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
                        _loadPdfs(isRefresh: true);
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
                ? const LoadingWidget(message: 'جاري تحميل ملفات PDF...')
                : _errorMessage != null
                    ? CustomErrorWidget(errorMessage: _errorMessage!, onRetry: _loadPdfs)
                    : _pdfList.isEmpty
                        ? EmptyStateWidget(
                            title: 'لا يوجد ملفات PDF حالياً',
                            message: 'لم يتم العثور على ملفات في هذا القسم، اضغط على زر الإضافة لإضافة ملف جديد.',
                            icon: Icons.picture_as_pdf_outlined,
                            actionLabel: 'إضافة ملف PDF',
                            onActionPressed: () => _showAddEditDialog(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _pdfList.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _pdfList.length) {
                                if (_hasMore) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? const CircularProgressIndicator()
                                          : ElevatedButton(
                                              onPressed: () => _loadPdfs(),
                                              child: const Text('تحميل المزيد من الملفات'),
                                            ),
                                    ),
                                  );
                                } else {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Center(
                                      child: Text(
                                        'تم تحميل كل الملفات',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  );
                                }
                              }
                              final pdf = _pdfList[index];
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
                                            backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                            child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  pdf.title,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'الترتيب: ${pdf.order}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Transform.scale(
                                            scale: 0.8,
                                            child: Switch(
                                              value: pdf.isActive,
                                              activeColor: Colors.redAccent,
                                              onChanged: (val) async {
                                                setState(() {
                                                  final index = _pdfList.indexWhere((p) => p.id == pdf.id);
                                                  if (index != -1) {
                                                    _pdfList[index] = pdf.copyWith(isActive: val);
                                                  }
                                                });
                                                try {
                                                  await _firestoreService.updatePdfFile(pdf.copyWith(isActive: val));
                                                } catch (e) {
                                                  setState(() {
                                                    final index = _pdfList.indexWhere((p) => p.id == pdf.id);
                                                    if (index != -1) {
                                                      _pdfList[index] = pdf;
                                                    }
                                                  });
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('خطأ أثناء تحديث حالة الملف: $e', textAlign: TextAlign.right),
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
                                              if (pdf.driveUrl.isNotEmpty) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => WebViewScreen(
                                                      url: pdf.driveUrl,
                                                      title: pdf.title,
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
                                            onPressed: () => _showAddEditDialog(pdf),
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
                                            onPressed: () => _deletePdf(pdf.id),
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
