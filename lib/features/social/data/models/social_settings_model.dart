
class SocialSettings {
  final String whatsappNumber;
  final String instagramUrl;
  final String tiktokUrl;
  final String websiteUrl;
  final String customContactName;

  const SocialSettings({
    this.whatsappNumber = '',
    this.instagramUrl = '',
    this.tiktokUrl = '',
    this.websiteUrl = '',
    this.customContactName = '',
  });

  SocialSettings copyWith({
    String? whatsappNumber,
    String? instagramUrl,
    String? tiktokUrl,
    String? websiteUrl,
    String? customContactName,
  }) {
    return SocialSettings(
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      tiktokUrl: tiktokUrl ?? this.tiktokUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      customContactName: customContactName ?? this.customContactName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'whatsappNumber': whatsappNumber,
      'instagramUrl': instagramUrl,
      'tiktokUrl': tiktokUrl,
      'websiteUrl': websiteUrl,
      'customContactName': customContactName,
    };
  }

  factory SocialSettings.fromMap(Map<String, dynamic> map) {
    return SocialSettings(
      whatsappNumber: map['whatsappNumber'] ?? '',
      instagramUrl: map['instagramUrl'] ?? '',
      tiktokUrl: map['tiktokUrl'] ?? '',
      websiteUrl: map['websiteUrl'] ?? '',
      customContactName: map['customContactName'] ?? '',
    );
  }
}
