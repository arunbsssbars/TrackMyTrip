import '../../models/expedition_locale.dart';

class LocaleDictionaryService {
  static final LocaleDictionaryService _instance = LocaleDictionaryService._internal();
  factory LocaleDictionaryService() => _instance;
  LocaleDictionaryService._internal();

  String _currentLocale = 'en';
  String get currentLocale => _currentLocale;

  void setLocale(String code) {
    if (supportedLocales.any((l) => l.languageCode == code)) {
      _currentLocale = code;
    }
  }

  static const List<ExpeditionLocale> supportedLocales = [
    ExpeditionLocale(
      languageCode: 'en',
      nativeName: 'English',
      englishName: 'English',
      flagEmoji: '🇬🇧',
    ),
    ExpeditionLocale(
      languageCode: 'hi',
      nativeName: 'हिन्दी',
      englishName: 'Hindi',
      flagEmoji: '🇮🇳',
    ),
    ExpeditionLocale(
      languageCode: 'es',
      nativeName: 'Español',
      englishName: 'Spanish',
      flagEmoji: '🇪🇸',
    ),
    ExpeditionLocale(
      languageCode: 'fr',
      nativeName: 'Français',
      englishName: 'French',
      flagEmoji: '🇫🇷',
    ),
    ExpeditionLocale(
      languageCode: 'de',
      nativeName: 'Deutsch',
      englishName: 'German',
      flagEmoji: '🇩🇪',
    ),
  ];

  static const Map<String, Map<String, String>> _dictionaries = {
    'en': {
      'start_trip': 'Start Expedition',
      'record_stoppage': 'Record Stoppage',
      'emergency_sos': 'Emergency SOS',
      'expenses': 'Expenses & Ledger',
      'fuel_tolls': 'Fuel & Tolls',
      'weather': 'Weather & Altitude',
      'settled': 'Settled in Full',
    },
    'hi': {
      'start_trip': 'यात्रा शुरू करें',
      'record_stoppage': 'स्टॉपेज जोड़ें',
      'emergency_sos': 'आपातकालीन सहायता (SOS)',
      'expenses': 'खर्च और हिसाब',
      'fuel_tolls': 'ईंधन और टोल',
      'weather': 'मौसम और ऊंचाई',
      'settled': 'पूरा हिसाब हो गया',
    },
    'es': {
      'start_trip': 'Iniciar Expedición',
      'record_stoppage': 'Registrar Parada',
      'emergency_sos': 'Emergencia SOS',
      'expenses': 'Gastos y Cuentas',
      'fuel_tolls': 'Combustible y Peajes',
      'weather': 'Clima y Altitud',
      'settled': 'Saldado Totalmente',
    },
    'fr': {
      'start_trip': 'Commencer l\'Expédition',
      'record_stoppage': 'Enregistrer l\'Étape',
      'emergency_sos': 'Urgence SOS',
      'expenses': 'Dépenses et Comptes',
      'fuel_tolls': 'Carburant et Péages',
      'weather': 'Météo et Altitude',
      'settled': 'Intégralement Réglé',
    },
    'de': {
      'start_trip': 'Expedition Starten',
      'record_stoppage': 'Stopp Erfassen',
      'emergency_sos': 'Notfall SOS',
      'expenses': 'Ausgaben & Buchung',
      'fuel_tolls': 'Treibstoff & Maut',
      'weather': 'Wetter & Höhenlage',
      'settled': 'Vollständig Beglichen',
    },
  };

  /// Translates a key with fallback to English
  String translate(String key, {String? locale}) {
    final targetLang = locale ?? _currentLocale;
    final dict = _dictionaries[targetLang] ?? _dictionaries['en']!;
    return dict[key] ?? _dictionaries['en']![key] ?? key;
  }
}
