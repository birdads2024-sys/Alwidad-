import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courses_provider.dart';
import '../../config/app_constants.dart';
import '../login_screen.dart';
import 'edit_profile_screen.dart';
import 'pdf_files_screen.dart';
import 'questions_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({Key? key}) : super(key: key);


  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج 👤'),
        content: const Text('هل ترغب في تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text('خروج'),
            onPressed: () async {
              Navigator.pop(ctx);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final coursesProvider = Provider.of<CoursesProvider>(context);
    final user = authProvider.currentUserModel;



    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي والمزيد'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // User Header Info Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/new_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => CircleAvatar(
                          radius: 36,
                          backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                          child: Icon(Icons.person, size: 40, color: theme.primaryColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'اسم الطالب',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'البريد الإلكتروني',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الهاتف: ${user?.phone ?? ""}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (user != null && user.isSubscribed && user.subscribedCategories.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: user.subscribedCategories
                                .where((cat) => AppConstants.categories.containsKey(cat))
                                .map((cat) {
                                  final name = AppConstants.categories[cat]!;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      final name = user?.name ?? '';
                      final email = user?.email ?? '';
                      final phone = user?.phone ?? '';
                      Clipboard.setData(ClipboardData(text: 'الاسم: $name\nالبريد: $email\nالهاتف: $phone'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم نسخ بيانات الحساب بنجاح 📋'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actions List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // Edit Profile
                  _buildListTile(
                    context,
                    icon: Icons.edit_outlined,
                    title: 'تعديل الملف الشخصي',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                      );
                    },
                  ),
                  
                  // WhatsApp / Contact for all platforms
                  _buildListTile(
                    context,
                    icon: Icons.chat_rounded,
                    title: Platform.isIOS ? 'تواصل مع الدعم الفني والمساعدة' : 'تواصل معنا للاشتراك عبر واتساب',
                    iconColor: const Color(0xFF25D366),
                    onTap: () async {
                      String phone = coursesProvider.appSettings?.whatsappNumber ?? AppConstants.defaultWhatsappNumber;
                      phone = phone.replaceAll('+', '').replaceAll(' ', '');
                      final messageText = Platform.isIOS ? 'مرحباً، أود الاستفسار وطلب الدعم الفني' : 'اريد تفعيل الاشتراك';
                      final message = Uri.encodeComponent(messageText);
                      final url = 'https://wa.me/$phone?text=$message';
                      final uri = Uri.parse(url);
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('لا يمكن فتح واتساب حالياً')),
                          );
                        }
                      }
                    },
                  ),

                  const Divider(height: 32),

                  // Privacy Policy
                  _buildListTile(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'سياسة الخصوصية',
                    onTap: () async {
                      final url = coursesProvider.appSettings?.privacyPolicyUrl ?? '';
                      if (url.isNotEmpty) {
                        final uri = Uri.parse(url);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('لا يمكن فتح رابط سياسة الخصوصية')),
                            );
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('رابط سياسة الخصوصية غير متوفر حالياً')),
                        );
                      }
                    },
                  ),

                  // Refund Policy
                  _buildListTile(
                    context,
                    icon: Icons.monetization_on_outlined,
                    title: 'سياسة الاسترجاع والاشتراكات',
                    onTap: () async {
                      final url = coursesProvider.appSettings?.refundPolicyUrl ?? '';
                      if (url.isNotEmpty) {
                        final uri = Uri.parse(url);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('لا يمكن فتح رابط سياسة الاسترجاع')),
                            );
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('رابط سياسة الاسترجاع غير متوفر حالياً')),
                        );
                      }
                    },
                  ),

                  const Divider(height: 32),

                  // Logout
                  _buildListTile(
                    context,
                    icon: Icons.logout_rounded,
                    title: 'تسجيل الخروج',
                    iconColor: Colors.amber,
                    onTap: () => _confirmLogout(context),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.primaryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
