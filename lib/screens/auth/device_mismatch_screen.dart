import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_routes.dart';
import '../../config/app_constants.dart';

class DeviceMismatchScreen extends StatelessWidget {
  const DeviceMismatchScreen({super.key});

  Future<void> _contactSupport(BuildContext context) async {
    const message = 'مرحباً، أواجه مشكلة في تسجيل الدخول. يظهر لي أن الحساب مسجل على جهاز آخر وأريد إعادة تعيين معرّف الجهاز الخاص بي.';
    final whatsappUrl = 'https://wa.me/${AppConstants.defaultWhatsappNumber}?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(whatsappUrl);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح تطبيق الواتساب تلقائياً، يرجى التواصل على الرقم: ${AppConstants.defaultWhatsappNumber}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء محاولة الاتصال: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Warning Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.phonelink_lock_rounded,
                    size: 64,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Mismatch Title
                const Text(
                  'تنبيه أمان: جهاز غير مصرح به!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Details Card
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'عذراً، هذا الحساب مسجل بالفعل على جهاز آخر!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لحماية خصوصيتك وضمان أمان حسابك، تُتيح منصة الوداد استخدام الحساب من جهاز واحد فقط في نفس الوقت. إذا قمت بتغيير جهازك مؤخراً، أو إذا كنت تعتقد أن هناك خطأ ما، يرجى النقر على الزر أدناه للتواصل مع الدعم الفني عبر واتساب لإعادة تعيين الجهاز المعتمد.',
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Whatsapp Contact Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _contactSupport(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFF25D366).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text(
                      'تواصل معنا عبر واتساب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Back to Login Button
                TextButton(
                  onPressed: () async {
                    await Provider.of<AuthProvider>(context, listen: false).signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.login,
                        (route) => false,
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade400,
                  ),
                  child: const Text(
                    'تسجيل الخروج والعودة لصفحة الدخول',
                    style: TextStyle(
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
