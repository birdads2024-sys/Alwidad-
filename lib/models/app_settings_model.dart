class AppSettingsModel {
  final String introVideoUrl;
  final List<String> bannerImages;
  final String introText;
  final String whatsappNumber;
  final String privacyPolicyUrl;
  final String refundPolicyUrl;

  AppSettingsModel({
    required this.introVideoUrl,
    required this.bannerImages,
    required this.introText,
    required this.whatsappNumber,
    required this.privacyPolicyUrl,
    required this.refundPolicyUrl,
  });

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) {
    return AppSettingsModel(
      introVideoUrl: map['introVideoUrl'] ?? '',
      bannerImages: List<String>.from(map['bannerImages'] ?? []),
      introText: map['introText'] ?? '',
      whatsappNumber: map['whatsappNumber'] ?? '',
      privacyPolicyUrl: map['privacyPolicyUrl'] ?? '',
      refundPolicyUrl: map['refundPolicyUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'introVideoUrl': introVideoUrl,
      'bannerImages': bannerImages,
      'introText': introText,
      'whatsappNumber': whatsappNumber,
      'privacyPolicyUrl': privacyPolicyUrl,
      'refundPolicyUrl': refundPolicyUrl,
    };
  }
}
