import 'package:flutter/material.dart';
import '../../models/app_settings_model.dart';
import '../../services/firestore_service.dart';
import '../../config/app_constants.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import 'change_password_screen.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  void _logout() async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A24),
          title: const Text('تسجيل الخروج', textAlign: TextAlign.right, style: TextStyle(color: Colors.white)),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من لوحة التحكم؟', textAlign: TextAlign.right, style: TextStyle(color: Colors.white70)),
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
                await _authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('تسجيل خروج'),
            ),
          ],
        );
      },
    );
  }

  final _settingsFormKey = GlobalKey<FormState>();

  final _introVideoUrlController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _introTextController = TextEditingController();
  final _privacyPolicyController = TextEditingController();
  final _refundPolicyController = TextEditingController();

  List<String> _bannerImages = [];
  bool _isLoadingSettings = true;
  bool _isSavingSettings = false;
  String? _settingsError;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoadingSettings = true;
      _settingsError = null;
    });

    try {
      AppSettingsModel? settings = await _firestoreService.getAppSettings();
      
      // Fallback to default constants if settings document is empty
      settings ??= AppSettingsModel(
        introVideoUrl: AppConstants.defaultIntroVideoUrl,
        bannerImages: List.from(AppConstants.defaultBannerImages),
        introText: AppConstants.defaultIntroText,
        whatsappNumber: AppConstants.defaultWhatsappNumber,
        privacyPolicyUrl: 'سياسة الخصوصية لمنصة الوداد التعليمية...',
        refundPolicyUrl: 'سياسة الاسترجاع الخاصة بالمنصة...',
      );

      _introVideoUrlController.text = settings.introVideoUrl;
      _whatsappController.text = settings.whatsappNumber;
      _introTextController.text = settings.introText;
      _privacyPolicyController.text = settings.privacyPolicyUrl;
      _refundPolicyController.text = settings.refundPolicyUrl;
      _bannerImages = List.from(settings.bannerImages);
      
    } catch (e) {
      _settingsError = 'حدث خطأ أثناء تحميل الإعدادات: $e';
    } finally {
      setState(() {
        _isLoadingSettings = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_settingsFormKey.currentState!.validate()) return;

    setState(() {
      _isSavingSettings = true;
    });

    try {
      final updatedSettings = AppSettingsModel(
        introVideoUrl: _introVideoUrlController.text.trim(),
        bannerImages: _bannerImages,
        introText: _introTextController.text.trim(),
        whatsappNumber: _whatsappController.text.trim(),
        privacyPolicyUrl: _privacyPolicyController.text.trim(),
        refundPolicyUrl: _refundPolicyController.text.trim(),
      );

      await _firestoreService.updateAppSettings(updatedSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ الإعدادات: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _isSavingSettings = false;
      });
    }
  }


  void _addBannerUrl() {
    final bannerController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            title: const Text('إضافة رابط بانر جديد', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      controller: bannerController,
                      labelText: 'رابط الصورة المباشر',
                      hintText: 'https://i.postimg.cc/.../image.png',
                      prefixIcon: const Icon(Icons.image_rounded),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder(
                      valueListenable: bannerController,
                      builder: (ctx, val, _) {
                        final url = bannerController.text.trim();
                        if (url.isEmpty) return const SizedBox.shrink();
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, e, st) => Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.redAccent, size: 20),
                                    SizedBox(width: 6),
                                    Text('تعذّر تحميل الصورة - تأكد من الرابط',
                                        style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final url = bannerController.text.trim();
                        if (url.isEmpty) return;

                        setDialogState(() => isSaving = true);

                        final newList = List<String>.from(_bannerImages)..add(url);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final updatedSettings = AppSettingsModel(
                            introVideoUrl: _introVideoUrlController.text.trim(),
                            bannerImages: newList,
                            introText: _introTextController.text.trim(),
                            whatsappNumber: _whatsappController.text.trim(),
                            privacyPolicyUrl: _privacyPolicyController.text.trim(),
                            refundPolicyUrl: _refundPolicyController.text.trim(),
                          );
                          await _firestoreService.updateAppSettings(updatedSettings);

                          if (mounted) {
                            setState(() => _bannerImages = newList);
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('✅ تم إضافة البانر وحفظه في Firebase بنجاح'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('❌ فشل الحفظ: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('إضافة وحفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteBannerUrl(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('حذف البانر', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من حذف هذا البانر؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final newList = List<String>.from(_bannerImages)..removeAt(index);
    try {
      final updatedSettings = AppSettingsModel(
        introVideoUrl: _introVideoUrlController.text.trim(),
        bannerImages: newList,
        introText: _introTextController.text.trim(),
        whatsappNumber: _whatsappController.text.trim(),
        privacyPolicyUrl: _privacyPolicyController.text.trim(),
        refundPolicyUrl: _refundPolicyController.text.trim(),
      );
      await _firestoreService.updateAppSettings(updatedSettings);
      if (mounted) {
        setState(() => _bannerImages = newList);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ تم حذف البانر من Firebase'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل الحذف: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _introVideoUrlController.dispose();
    _whatsappController.dispose();
    _introTextController.dispose();
    _privacyPolicyController.dispose();
    _refundPolicyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoadingSettings) {
      return const Scaffold(
        body: LoadingWidget(message: 'جاري تحميل الإعدادات...'),
      );
    }

    if (_settingsError != null) {
      return Scaffold(
        body: CustomErrorWidget(errorMessage: _settingsError!, onRetry: _loadSettings),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات التطبيق'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Settings Form
            Form(
              key: _settingsFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Information Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.video_library_rounded, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'الفيديو التعريفي والدعم',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: Colors.grey),
                          CustomTextField(
                            controller: _introVideoUrlController,
                            labelText: 'رابط فيديو يوتيوب التعريفي (Intro Video URL)',
                            hintText: 'https://www.youtube.com/watch?v=...',
                            prefixIcon: const Icon(Icons.play_circle_outline_rounded),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال رابط الفيديو';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _whatsappController,
                            labelText: 'رقم واتساب للدعم الفني (شامل رمز الدولة)',
                            hintText: '970599000000',
                            prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال رقم واتساب للدعم';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _introTextController,
                            labelText: 'نص الترحيب بالصفحة الرئيسية',
                            prefixIcon: const Icon(Icons.text_fields_rounded),
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال نص الترحيب';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Banners Management Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.view_carousel_rounded, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'إدارة البانرات الإعلانية',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                                onPressed: _addBannerUrl,
                                tooltip: 'إضافة بانر',
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: Colors.grey),
                          if (_bannerImages.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'لا توجد صور بانرات حالياً. سيتم استخدام الصور الافتراضية.',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _bannerImages.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _bannerImages[index],
                                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textDirection: TextDirection.ltr,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                        onPressed: () => _deleteBannerUrl(index),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Policies Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.policy_rounded, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'السياسات والشروط',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: Colors.grey),
                          CustomTextField(
                            controller: _privacyPolicyController,
                            labelText: 'سياسة الخصوصية (Privacy Policy)',
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال سياسة الخصوصية';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _refundPolicyController,
                            labelText: 'سياسة الاسترجاع (Refund Policy)',
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال سياسة الاسترجاع';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Settings Button
                  ElevatedButton(
                    onPressed: _isSavingSettings ? null : _saveSettings,
                    child: _isSavingSettings
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Text('حفظ جميع الإعدادات العامة'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Divider(height: 1, color: Colors.grey),
            const SizedBox(height: 24),

            // Section 2: Change Password Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_reset_rounded, color: theme.colorScheme.secondary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'تغيير كلمة مرور المشرف',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لحماية حساب المشرف الخاص بك، ننصح بتحديث كلمة المرور بشكل دوري لتأمين المنصة.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: Colors.white,
                        shadowColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
                      ),
                      child: const Text('تغيير كلمة المرور'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
