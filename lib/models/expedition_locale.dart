class ExpeditionLocale {
  final String languageCode;
  final String nativeName;
  final String englishName;
  final String flagEmoji;

  const ExpeditionLocale({
    required this.languageCode,
    required this.nativeName,
    required this.englishName,
    required this.flagEmoji,
  });

  Map<String, dynamic> toJson() => {
        'languageCode': languageCode,
        'nativeName': nativeName,
        'englishName': englishName,
        'flagEmoji': flagEmoji,
      };

  factory ExpeditionLocale.fromJson(Map<String, dynamic> json) {
    return ExpeditionLocale(
      languageCode: json['languageCode'] as String? ?? 'en',
      nativeName: json['nativeName'] as String? ?? 'English',
      englishName: json['englishName'] as String? ?? 'English',
      flagEmoji: json['flagEmoji'] as String? ?? '🌐',
    );
  }
}
