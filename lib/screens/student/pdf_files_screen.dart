import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courses_provider.dart';
import '../../config/app_constants.dart';
import 'webview_screen.dart';
import '../../widgets/shimmer_loading.dart';

class PdfFilesScreen extends StatefulWidget {
  const PdfFilesScreen({Key? key}) : super(key: key);

  @override
  State<PdfFilesScreen> createState() => _PdfFilesScreenState();
}

class _PdfFilesScreenState extends State<PdfFilesScreen> {
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

    // جلب ملفات القسم المختار عند التغيير فقط
    if (_selectedCategoryId != null && _selectedCategoryId != _lastLoadedCategoryId) {
      _lastLoadedCategoryId = _selectedCategoryId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<CoursesProvider>(context, listen: false)
            .loadPdfFiles(_selectedCategoryId!);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفات PDF والملخصات'),
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

          // PDF List
          Expanded(
            child: _selectedCategoryId == null
                ? const Center(child: Text('الرجاء اختيار قسم لعرض الملفات'))
                : Consumer<CoursesProvider>(
                    builder: (context, coursesProvider, child) {
                      if (coursesProvider.isLoadingPdfs &&
                          coursesProvider.pdfFiles.isEmpty) {
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
                            await coursesProvider
                                .loadPdfFiles(_selectedCategoryId!);
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
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Colors.red.withValues(alpha: 0.15),
                                  child: const Icon(Icons.picture_as_pdf,
                                      color: Colors.red),
                                ),
                                title: Text(
                                  pdf.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility,
                                          color: Colors.blue),
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
                                      icon: const Icon(Icons.download_rounded,
                                          color: Colors.green),
                                      tooltip: 'تحميل',
                                      onPressed: () async {
                                        final uri = Uri.parse(pdf.driveUrl);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode
                                                  .externalApplication);
                                        } else {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'لا يمكن فتح رابط التحميل')),
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
                  ),
          ),
        ],
      ),
    );
  }
}
