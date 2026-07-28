import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionBanner extends StatelessWidget {
  final String whatsappNumber;
  final String message;

  const SubscriptionBanner({
    super.key,
    required this.whatsappNumber,
    this.message = 'اشترك الآن لتفعيل كافة الدروس والفيديوهات وتحميلها للمشاهدة بدون إنترنت!',
  });

  void _contactWhatsApp(BuildContext context) async {
    final cleanNumber = whatsappNumber.replaceAll('+', '').trim();
    final messageText = Platform.isIOS ? "مرحباً، أود الاستفسار وطلب الدعم الفني" : "اريد تفعيل الاشتراك";
    final url = Uri.parse('https://wa.me/$cleanNumber?text=${Uri.encodeComponent(messageText)}');
    
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح واتساب حالياً. يرجى المحاولة لاحقاً.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isIos = Platform.isIOS;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor,
            theme.primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.star_rounded,
              size: 100,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIos ? Icons.support_agent_rounded : Icons.workspace_premium_rounded,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isIos ? 'الدعم الفني والمساعدة 💡' : 'باقة الاشتراك المميز ✨',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isIos ? 'تواصل مع الدعم الفني للاستفسارات والمساعدة الفنية في تفعيل حسابك والدروس.' : message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _contactWhatsApp(context),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green),
                    label: Text(
                      isIos ? 'تواصل مع الدعم الفني عبر واتساب' : 'تفعيل الاشتراك عبر واتساب',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: theme.colorScheme.primary,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
