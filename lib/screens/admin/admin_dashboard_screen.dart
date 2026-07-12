import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../config/app_constants.dart';
import '../../widgets/student_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/error_widget.dart';
import '../login_screen.dart';
import 'pdf_management_screen.dart';
import 'questions_management_screen.dart';
import 'settings_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  List<UserModel> _students = [];
  bool? _filterSubscribed;
  String _selectedSearchText = '';
  
  int _totalStudents = 0;
  int _subscribedCount = 0;
  int _unsubscribedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Load Stats
      final allStudentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
          
      final allStudents = allStudentsSnap.docs
          .map((doc) => UserModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map)))
          .toList();
          
      _totalStudents = allStudents.length;
      _subscribedCount = allStudents.where((s) => s.isSubscribed).length;
      _unsubscribedCount = _totalStudents - _subscribedCount;

      // 2. Load Filtered List
      final querySnap = await _firestoreService.getStudentsQuery(
        search: _selectedSearchText.isNotEmpty ? _selectedSearchText : null,
        isSubscribed: _filterSubscribed,
      );

      setState(() {
        _students = querySnap.docs
            .map((doc) => UserModel.fromMap(doc.id, Map<String, dynamic>.from(doc.data() as Map)))
            .toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء تحميل البيانات: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _selectedSearchText = _searchController.text.trim();
    });
    _loadDashboardData();
  }

  Future<void> _toggleSubscription(UserModel student, bool value) async {
    try {
      await _firestoreService.updateUserField(student.uid, 'isSubscribed', value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'تم تفعيل الاشتراك بنجاح' : 'تم إلغاء الاشتراك بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تعديل الاشتراك: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _resetDeviceId(UserModel student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('إلغاء قفل الجهاز', style: TextStyle(color: Colors.white)),
        content: Text('هل تريد إلغاء ربط الحساب بجهاز الطالب (${student.name})؟ سيتمكن من تسجيل الدخول من جهاز آخر.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.clearUserDeviceId(student.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء قفل الجهاز بنجاح'), backgroundColor: Colors.green),
          );
          _loadDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _deleteStudent(UserModel student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('حذف الطالب', style: TextStyle(color: Colors.white)),
        content: Text('هل أنت متأكد من حذف حساب الطالب (${student.name}) نهائياً؟ لا يمكن التراجع عن هذا الإجراء.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('حذف الحساب'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(student.uid).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف حساب الطالب بنجاح'), backgroundColor: Colors.green),
          );
          _loadDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _showEditNameDialog(UserModel student) {
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
                  try {
                    await _firestoreService.updateUserField(student.uid, 'name', nameController.text.trim());
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديث الاسم بنجاح', textAlign: TextAlign.right),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadDashboardData();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('فشل تحديث الاسم: $e', textAlign: TextAlign.right),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
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

  void _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الإدارة'),
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded),
          onPressed: _logout,
          tooltip: 'تسجيل الخروج',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDashboardData,
            tooltip: 'تحديث البيانات',
          )
        ],
      ),
      body: Column(
        children: [
          // Quick Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                _buildStatCard('إجمالي الطلاب', '$_totalStudents', Icons.people_rounded, theme.colorScheme.primary),
                const SizedBox(width: 8),
                _buildStatCard('المشتركين', '$_subscribedCount', Icons.workspace_premium_rounded, Colors.amber),
                const SizedBox(width: 8),
                _buildStatCard('غير المشتركين', '$_unsubscribedCount', Icons.people_outline_rounded, Colors.grey),
              ],
            ),
          ),

          // Main Management Navigation Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildNavigationCard(
                  context,
                  title: 'ملفات PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  color: Colors.redAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PdfManagementScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _buildNavigationCard(
                  context,
                  title: 'الاختبارات',
                  icon: Icons.assignment_turned_in_rounded,
                  color: Colors.greenAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QuestionsManagementScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _buildNavigationCard(
                  context,
                  title: 'الإعدادات',
                  icon: Icons.settings_rounded,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          // Search & Filter Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم الطالب...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged();
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => _onSearchChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                // Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<bool?>(
                      value: _filterSubscribed,
                      dropdownColor: theme.colorScheme.surface,
                      icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('جميع الطلاب')),
                        DropdownMenuItem(value: true, child: Text('المشتركين فقط')),
                        DropdownMenuItem(value: false, child: Text('غير المشتركين')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterSubscribed = value;
                        });
                        _loadDashboardData();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          // Students List
          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'جاري تحميل قائمة الطلاب...')
                : _errorMessage != null
                    ? CustomErrorWidget(errorMessage: _errorMessage!, onRetry: _loadDashboardData)
                    : _students.isEmpty
                        ? const EmptyStateWidget(
                            title: 'لا يوجد طلاب مطبقين للفلاتر',
                            message: 'تأكد من كتابة الاسم بشكل صحيح أو تغيير نوع الفلترة.',
                            icon: Icons.people_outline_rounded,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: _students.length,
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              return StudentCard(
                                student: student,
                                indexNumber: _students.length - index,
                                onSubscriptionToggled: (val) => _toggleSubscription(student, val),
                                onResetDeviceId: () => _resetDeviceId(student),
                                onDelete: () => _deleteStudent(student),
                                onEditName: () => _showEditNameDialog(student),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
