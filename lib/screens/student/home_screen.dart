import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courses_provider.dart';
import '../../config/app_constants.dart';
import '../../widgets/subscription_banner.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({Key? key}) : super(key: key);

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  YoutubePlayerController? _youtubeController;
  bool _isYoutubeInitialized = false;
  String? _currentVideoId;
  bool _showYoutubePlaceholder = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coursesProvider = Provider.of<CoursesProvider>(context);
    final videoUrl = coursesProvider.appSettings?.introVideoUrl ?? AppConstants.defaultIntroVideoUrl;
    final videoId = YoutubePlayer.convertUrlToId(videoUrl);

    if (videoId != null && videoId != _currentVideoId) {
      _currentVideoId = videoId;
      _youtubeController?.dispose();
      _youtubeController = null;
      _isYoutubeInitialized = false;
      _showYoutubePlaceholder = true;
    }
  }

  void _initializeAndPlayYoutube() {
    if (_currentVideoId == null) return;
    
    _youtubeController = YoutubePlayerController(
      initialVideoId: _currentVideoId!,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: true,
      ),
    );
    
    setState(() {
      _isYoutubeInitialized = true;
      _showYoutubePlaceholder = false;
    });
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  void _showSubscriptionInfoDialog(BuildContext context, user, ThemeData theme) {
    final isSubscribed = user?.isSubscribed ?? false;
    final subscribedCategories = user?.subscribedCategories as List<String>? ?? [];
    final userCategory = user?.category ?? '';

    const categories = {
      'scientific_1': 'توجيهي علمي فصل أول',
      'literary_1': 'توجيهي أدبي فصل أول',
      'scientific_2': 'توجيهي علمي فصل ثاني',
      'literary_2': 'توجيهي أدبي فصل ثاني',
    };

    // على iOS: عرض معلومات الحساب فقط بدون أي إشارة لاشتراك أو قفل
    if (Platform.isIOS) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_rounded, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('معلومات حسابي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'فصلك الدراسي:',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  categories[userCategory] ?? userCategory,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 14),
                Text(
                  'الأقسام المتاحة لديك:',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 6),
                if (subscribedCategories.isEmpty)
                  const Text(
                    'تواصل مع إدارة المركز لتفعيل حسابك',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.right,
                  )
                else
                  ...subscribedCategories.map((cat) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          categories[cat] ?? cat,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isSubscribed ? Icons.verified_rounded : Icons.lock_outline_rounded,
              color: isSubscribed ? Colors.greenAccent : Colors.orangeAccent,
            ),
            const SizedBox(width: 8),
            const Text('معلومات اشتراكي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: isSubscribed
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSubscribed ? Icons.check_circle : Icons.info_outline,
                      color: isSubscribed ? Colors.greenAccent : Colors.orangeAccent,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSubscribed ? 'أنت مشترك ✅' : 'لا يوجد اشتراك فعّال ⚠️',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSubscribed ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'فصلك الدراسي:',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 4),
              Text(
                categories[userCategory] ?? userCategory,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 14),
              Text(
                'الأقسام المفعّلة لديك:',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 6),
              if (subscribedCategories.isEmpty)
                Text(
                  isSubscribed ? 'جميع الأقسام مفعّلة' : 'لا توجد أقسام مفعّلة بعد',
                  style: TextStyle(
                    color: isSubscribed ? Colors.greenAccent : Colors.grey,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.right,
                )
              else
                ...subscribedCategories.map((cat) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        categories[cat] ?? cat,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final coursesProvider = Provider.of<CoursesProvider>(context);

    final settings = coursesProvider.appSettings;
    final user = auth.currentUserModel;

    final bannerImages = settings?.bannerImages ?? AppConstants.defaultBannerImages;
    final introText = settings?.introText ?? AppConstants.defaultIntroText;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/new_logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                  child: Icon(Icons.person, size: 20, color: theme.primaryColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'أهلاً بك 👋',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  user?.name ?? 'طالبنا العزيز',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [

          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('لا توجد إشعارات حالياً', style: TextStyle(fontFamily: 'Cairo')),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await coursesProvider.loadAppSettings();
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Image Carousel Banner
              if (bannerImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                CarouselSlider(
                  options: CarouselOptions(
                    height: isTablet ? 400.0 : 180.0,
                    autoPlay: true,
                    enlargeCenterPage: true,
                    aspectRatio: 16 / 9,
                    autoPlayInterval: const Duration(seconds: 4),
                    autoPlayAnimationDuration: const Duration(milliseconds: 800),
                    viewportFraction: 0.9,
                  ),
                  items: bannerImages.map((imageUrl) {
                    return Builder(
                      builder: (BuildContext context) {
                        return Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: theme.colorScheme.surface,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imageUrl.startsWith('assets/')
                              ? Image.asset(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) => const Center(
                                    child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                  ),
                                ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],

              // Subscription Banner for unsubscribed students (hidden on iOS)
              if (user != null && !user.isSubscribed && !Platform.isIOS) ...[
                SubscriptionBanner(
                  whatsappNumber: settings?.whatsappNumber ?? AppConstants.defaultWhatsappNumber,
                ),
              ],

              // 3. YouTube Intro Video Player
              if (_currentVideoId != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الفيديو التعريفي بالمنصة 🎥',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: isTablet ? 450.0 : 200.0,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.black,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _showYoutubePlaceholder
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: 'https://img.youtube.com/vi/$_currentVideoId/hqdefault.jpg',
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                    errorWidget: (context, url, error) => const Center(
                                      child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
                                    ),
                                  ),
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.3),
                                  ),
                                  Center(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _initializeAndPlayYoutube,
                                        child: const Icon(
                                          Icons.play_circle_fill_rounded,
                                          size: 72,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : YoutubePlayer(
                                controller: _youtubeController!,
                                showVideoProgressIndicator: true,
                                progressIndicatorColor: theme.primaryColor,
                                progressColors: ProgressBarColors(
                                  playedColor: theme.primaryColor,
                                  handleColor: theme.primaryColor,
                                ),
                                bottomActions: [
                                  const SizedBox(width: 14.0),
                                  CurrentPosition(),
                                  const SizedBox(width: 8.0),
                                  ProgressBar(
                                    isExpanded: true,
                                    colors: ProgressBarColors(
                                      playedColor: theme.primaryColor,
                                      handleColor: theme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  RemainingDuration(),
                                  const FullScreenButton(),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],

              // 2. Welcome & Educational Texts
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: theme.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Al Widad',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        introText,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Static Banner for Sections
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.school_rounded, color: Colors.white, size: 36),
                      SizedBox(height: 10),
                      Text(
                        'متاح علي المنصة دروس\nرياضيات للثانوية العامة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• توجيهي علمي (فصل أول وفصل ثاني)\n• توجيهي أدبي (فصل أول وفصل ثاني)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
