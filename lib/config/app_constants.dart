class AppConstants {
  // الأقسام الأربعة الثابتة للتطبيق (الفصول الدراسية)
  static const Map<String, String> categories = {
    'scientific_1': 'توجيهي علمي فصل أول',
    'literary_1': 'توجيهي أدبي فصل أول',
    'scientific_2': 'توجيهي علمي فصل ثاني',
    'literary_2': 'توجيهي أدبي فصل ثاني',
  };

  // القيم الافتراضية للإعدادات
  static const String defaultIntroVideoUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  static const String defaultWhatsappNumber = '+970599000000';
  static const String defaultIntroText = 'مرحباً بك في منصة الوداد للرياضيات. تصفح الكورسات وشاهد دروسك أونلاين أو أوفلاين بكل سهولة!';
  static const List<String> defaultBannerImages = [
    'assets/banner_tawjihi_1.png',
    'assets/banner_tawjihi_2.png',
    'assets/banner_tawjihi_3.png',
  ];
}
