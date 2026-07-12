import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../config/app_constants.dart';

class StudentCard extends StatelessWidget {
  final UserModel student;
  final int indexNumber;
  final ValueChanged<bool>? onSubscriptionToggled;
  final VoidCallback? onResetDeviceId;
  final VoidCallback? onEditName;
  final VoidCallback? onDelete;

  const StudentCard({
    super.key,
    required this.student,
    required this.indexNumber,
    this.onSubscriptionToggled,
    this.onResetDeviceId,
    this.onEditName,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: student.isSubscribed
              ? Colors.amber.withValues(alpha: 0.3)
              : Colors.grey.shade800,
          width: student.isSubscribed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Text(
                  '#$indexNumber',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: student.isSubscribed
                                ? Colors.amber.shade700.withValues(alpha: 0.2)
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: student.isSubscribed
                                  ? Colors.amber.shade700
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            student.isSubscribed ? 'مشترك 💎' : 'غير مشترك 💤',
                            style: TextStyle(
                              fontSize: 11,
                              color: student.isSubscribed ? Colors.amber.shade200 : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Email row with copy button
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.email,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (student.email.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: student.email));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ البريد الإلكتروني'),
                                  duration: Duration(seconds: 1),
                                  backgroundColor: Colors.blueGrey,
                                ),
                              );
                            },
                            child: Tooltip(
                              message: 'نسخ الإيميل',
                              child: Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.grey),
          // Phone, copy buttons, and category
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.phone_iphone_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        student.phone.isNotEmpty ? student.phone : 'لا يوجد هاتف',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (student.phone.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: student.phone));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ رقم الهاتف'),
                              duration: Duration(seconds: 1),
                              backgroundColor: Colors.blueGrey,
                            ),
                          );
                        },
                        child: Tooltip(
                          message: 'نسخ الهاتف',
                          child: Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final subCats = student.subscribedCategories;
                        String categoriesText;
                        if (subCats.isNotEmpty) {
                          categoriesText = subCats
                              .map((catId) => AppConstants.categories[catId] ?? catId)
                              .join('، ');
                        } else {
                          final mainCat = AppConstants.categories[student.category] ?? student.category;
                          categoriesText = mainCat.isNotEmpty ? mainCat : 'لا يوجد قسم';
                        }

                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                title: const Text(
                                  'تفاصيل الطالب',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'أقسام الطالب: ${student.name}',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      student.isSubscribed
                                          ? 'حالة الاشتراك: مشترك 💎'
                                          : 'حالة الاشتراك: غير مشترك 💤',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'الأقسام المشترك بها: $categoriesText',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('إغلاق'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: const Tooltip(
                        message: 'عرض الأقسام',
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: Colors.blueAccent,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Device Lock status
          Row(
            children: [
              Icon(
                student.deviceId.isNotEmpty ? Icons.phonelink_lock_rounded : Icons.phonelink_setup_rounded,
                size: 16,
                color: student.deviceId.isNotEmpty ? Colors.amber : Colors.green,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  student.deviceId.isNotEmpty
                      ? 'مربوط بجهاز: ${student.deviceId.substring(0, student.deviceId.length > 8 ? 8 : student.deviceId.length)}...'
                      : 'غير مربوط بأي جهاز حالياً',
                  style: TextStyle(
                    fontSize: 12,
                    color: student.deviceId.isNotEmpty ? Colors.grey.shade400 : Colors.green.shade400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onEditName != null)
                TextButton.icon(
                  onPressed: onEditName,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('تعديل الاسم', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              if (onResetDeviceId != null)
                TextButton.icon(
                  onPressed: onResetDeviceId,
                  icon: const Icon(Icons.phonelink_erase_rounded, size: 16),
                  label: const Text('إلغاء قفل الجهاز', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.amber,
                    backgroundColor: Colors.amber.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              if (onSubscriptionToggled != null)
                TextButton.icon(
                  onPressed: () => onSubscriptionToggled!(!student.isSubscribed),
                  icon: Icon(
                    student.isSubscribed ? Icons.close_rounded : Icons.workspace_premium_rounded,
                    size: 16,
                  ),
                  label: Text(
                    student.isSubscribed ? 'إلغاء الاشتراك' : 'تفعيل الاشتراك',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: student.isSubscribed ? Colors.redAccent : Colors.green,
                    backgroundColor: (student.isSubscribed ? Colors.redAccent : Colors.green).withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  tooltip: 'حذف الطالب',
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
