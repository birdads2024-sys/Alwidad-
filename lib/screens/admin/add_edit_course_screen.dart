import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_constants.dart';
import '../../models/course_model.dart';
import '../../services/firestore_service.dart';

class AddEditCourseScreen extends StatefulWidget {
  final CourseModel? course;
  final String? initialCategoryId;

  const AddEditCourseScreen({
    super.key,
    this.course,
    this.initialCategoryId,
  });

  @override
  State<AddEditCourseScreen> createState() => _AddEditCourseScreenState();
}

class _AddEditCourseScreenState extends State<AddEditCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _orderController;
  late TextEditingController _thumbnailUrlController;
  List<VideoQualityInput> _qualities = [];

  String? _selectedCategoryId;
  bool _isFree = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.course;

    _titleController = TextEditingController(text: c?.title ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _orderController = TextEditingController(text: c?.order != null ? c!.order.toString() : '0');
    _thumbnailUrlController = TextEditingController(text: c?.thumbnailUrl ?? '');

    _selectedCategoryId = c?.categoryId ?? widget.initialCategoryId;
    // للتأكد من أن القسم المختار موجود في قائمة الأقسام المتاحة
    if (_selectedCategoryId != null && !AppConstants.categories.containsKey(_selectedCategoryId)) {
      _selectedCategoryId = null;
    }
    _isFree = c?.isFree ?? false;

    // تهيئة الجودات
    if (c != null) {
      _qualities = c.qualities.map((q) => VideoQualityInput(
        name: q.qualityName,
        hls: q.hlsUrl,
        mp4: q.mp4Url,
        isDrm: q.isDrm,
      )).toList();

      if (_qualities.isEmpty && (c.hlsUrl.isNotEmpty || c.mp4Url.isNotEmpty)) {
        _qualities.add(VideoQualityInput(
          name: 'الافتراضية',
          hls: c.hlsUrl,
          mp4: c.mp4Url,
          isDrm: false,
        ));
      }
    } else {
      // افتراضياً نضيف جودة فارغة
      _qualities.add(VideoQualityInput(name: '1080p', hls: '', mp4: '', isDrm: false));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    _thumbnailUrlController.dispose();
    for (var q in _qualities) {
      q.dispose();
    }
    super.dispose();
  }

  // التحقق من صحة رابط الويب
  bool _isValidUrl(String url) {
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }

  // إضافة جودة جديدة
  void _addQualityField() {
    setState(() {
      _qualities.add(VideoQualityInput(name: '', hls: '', mp4: '', isDrm: false));
    });
  }

  // حذف جودة من القائمة
  void _removeQualityField(int index) {
    if (_qualities.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب توفر جودة واحدة للفيديو على الأقل', textAlign: TextAlign.right),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }
    setState(() {
      final removed = _qualities.removeAt(index);
      removed.dispose();
    });
  }

  // حفظ الكورس
  void _saveCourse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_qualities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة جودة فيديو واحدة على الأقل', textAlign: TextAlign.right),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final thumbnailUrl = _thumbnailUrlController.text.trim();
      final order = int.tryParse(_orderController.text.trim()) ?? 0;
      final categoryId = _selectedCategoryId!;

      final id = widget.course?.id ?? FirebaseFirestore.instance.collection('courses').doc().id;
      final defaultThumbnail = thumbnailUrl.isNotEmpty 
          ? thumbnailUrl 
          : (widget.course?.thumbnailUrl ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800');

      // تجميع الجودات
      final qualitiesList = _qualities.map((q) => VideoQuality(
        qualityName: q.nameController.text.trim(),
        hlsUrl: q.hlsController.text.trim(),
        mp4Url: q.isDrm ? '' : q.mp4Controller.text.trim(),
        isDrm: q.isDrm,
      )).toList();

      // تعيين الحقول القديمة لأول جودة لضمان التوافق التام
      final defaultHls = qualitiesList.first.hlsUrl;
      final defaultMp4 = qualitiesList.first.mp4Url;

      final courseModel = CourseModel(
        id: id,
        title: title,
        description: description,
        categoryId: categoryId,
        hlsUrl: defaultHls,
        mp4Url: defaultMp4,
        thumbnailUrl: defaultThumbnail,
        isFree: _isFree,
        order: order,
        isActive: widget.course?.isActive ?? true,
        createdAt: widget.course?.createdAt,
        updatedAt: DateTime.now(),
        qualities: qualitiesList,
      );

      if (widget.course == null) {
        await _firestoreService.createCourse(courseModel);
      } else {
        await _firestoreService.updateCourse(courseModel);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.course == null ? 'تم إضافة الكورس بنجاح 🎉' : 'تم تعديل الكورس بنجاح',
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('خطأ أثناء حفظ الكورس: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ الكورس: $e', textAlign: TextAlign.right),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.course != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل بيانات الكورس' : 'إضافة كورس جديد'),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // العنوان
                    TextFormField(
                      controller: _titleController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الكورس / الدرس',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال عنوان الكورس';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // الوصف
                    TextFormField(
                      controller: _descriptionController,
                      textAlign: TextAlign.right,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'وصف تفصيلي للكورس',
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال وصف الكورس';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // القسم الدراسي (Dropdown)
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      alignment: Alignment.centerRight,
                      decoration: const InputDecoration(
                        labelText: 'القسم الدراسي (الفئة)',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: AppConstants.categories.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          alignment: Alignment.centerRight,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'يرجى اختيار القسم الدراسي';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // رابط الصورة المصغرة Thumbnail URL
                    TextFormField(
                      controller: _thumbnailUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'رابط الصورة المصغرة (Thumbnail URL)',
                        prefixIcon: Icon(Icons.image),
                        hintText: 'https://example.com/image.jpg',
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty && !_isValidUrl(value.trim())) {
                          return 'يرجى إدخال رابط ويب صحيح يبدأ بـ http/https';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // عنوان قسم الجودات
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'جودات وروابط الفيديو',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addQualityField,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إضافة جودة أخرى'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor.withOpacity(0.1),
                            foregroundColor: theme.primaryColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // قائمة الجودات
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _qualities.length,
                      itemBuilder: (context, index) {
                        final quality = _qualities[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'جودة الفيديو #${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                    if (_qualities.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () => _removeQualityField(index),
                                        tooltip: 'حذف هذه الجودة',
                                      ),
                                  ],
                                ),
                                const Divider(),
                                const SizedBox(height: 8),
                                // اسم الجودة
                                TextFormField(
                                  controller: quality.nameController,
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم الجودة (مثال: 480p، 1080p)',
                                    prefixIcon: Icon(Icons.high_quality),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'يرجى إدخال اسم الجودة';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                // رابط HLS
                                TextFormField(
                                  controller: quality.hlsController,
                                  keyboardType: TextInputType.url,
                                  decoration: const InputDecoration(
                                    labelText: 'رابط البث الآمن HLS URL (.m3u8)',
                                    prefixIcon: Icon(Icons.stream),
                                    hintText: 'https://example.com/stream/main.m3u8',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'يرجى إدخال رابط البث HLS';
                                    }
                                    if (!_isValidUrl(value.trim())) {
                                      return 'يرجى إدخال رابط ويب صحيح يبدأ بـ http/https';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                // خيار حماية DRM
                                CheckboxListTile(
                                  title: const Text('حماية DRM (فيديو مشفر ومحمي)'),
                                  subtitle: const Text('سيتم تعطيل خيار التحميل لهذا الفيديو تلقائياً'),
                                  value: quality.isDrm,
                                  activeColor: theme.primaryColor,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) {
                                    setState(() {
                                      quality.isDrm = val ?? false;
                                      if (quality.isDrm) {
                                        quality.mp4Controller.clear();
                                      }
                                    });
                                  },
                                ),
                                // رابط MP4
                                if (!quality.isDrm) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: quality.mp4Controller,
                                    keyboardType: TextInputType.url,
                                    decoration: const InputDecoration(
                                      labelText: 'رابط تحميل الفيديو MP4 URL (.mp4)',
                                      prefixIcon: Icon(Icons.download),
                                      hintText: 'https://example.com/stream/download.mp4',
                                    ),
                                    validator: (value) {
                                      if (quality.isDrm) return null;
                                      if (value == null || value.trim().isEmpty) {
                                        return 'يرجى إدخال رابط التحميل MP4';
                                      }
                                      if (!_isValidUrl(value.trim())) {
                                        return 'يرجى إدخال رابط ويب صحيح يبدأ بـ http/https';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // الترتيب الرقمي
                    TextFormField(
                      controller: _orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ترتيب عرض الكورس (رقم)',
                        prefixIcon: Icon(Icons.format_list_numbered_rtl),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال رقم الترتيب';
                        }
                        if (int.tryParse(value.trim()) == null) {
                          return 'يرجى إدخال رقم صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // خيار مجاني
                    CheckboxListTile(
                      title: const Text('كورس مجاني (متاح للجميع دون اشتراك)'),
                      subtitle: const Text('تفعيل هذا الخيار يجعل الكورس متاحاً للطلاب كفيديو تجريبي مجاني'),
                      value: _isFree,
                      activeColor: theme.primaryColor,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setState(() {
                          _isFree = value ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 32),

                    // أزرار الحفظ
                    ElevatedButton(
                      onPressed: _saveCourse,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isEdit ? 'تحديث الكورس' : 'حفظ ونشر الكورس الجديد',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// كلاس مساعد لإدارة مدخلات كل جودة فيديو
class VideoQualityInput {
  final TextEditingController nameController;
  final TextEditingController hlsController;
  final TextEditingController mp4Controller;
  bool isDrm;

  VideoQualityInput({
    required String name,
    required String hls,
    required String mp4,
    this.isDrm = false,
  })  : nameController = TextEditingController(text: name),
        hlsController = TextEditingController(text: hls),
        mp4Controller = TextEditingController(text: mp4);

  void dispose() {
    nameController.dispose();
    hlsController.dispose();
    mp4Controller.dispose();
  }
}

