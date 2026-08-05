
class LanguageInfo {
  final String code;
  final String nameKo;
  final String nameEn;
  final String flag;

  const LanguageInfo({
    required this.code,
    required this.nameKo,
    required this.nameEn,
    required this.flag,
  });
}

class TranslationConstants {


  static const List<LanguageInfo> supportedLanguages = [
    LanguageInfo(code: 'ko', nameKo: '한국어', nameEn: 'Korean', flag: '🇰🇷'),
    LanguageInfo(code: 'en', nameKo: '영어', nameEn: 'English', flag: '🇺🇸'),
    LanguageInfo(code: 'ja', nameKo: '일본어', nameEn: 'Japanese', flag: '🇯🇵'),
    LanguageInfo(code: 'zh', nameKo: '중국어', nameEn: 'Chinese', flag: '🇨🇳'),
    LanguageInfo(code: 'es', nameKo: '스페인어', nameEn: 'Spanish', flag: '🇪🇸'),
    LanguageInfo(code: 'fr', nameKo: '프랑스어', nameEn: 'French', flag: '🇫🇷'),
    LanguageInfo(code: 'de', nameKo: '독일어', nameEn: 'German', flag: '🇩🇪'),
    LanguageInfo(code: 'vi', nameKo: '베트남어', nameEn: 'Vietnamese', flag: '🇻🇳'),
    LanguageInfo(code: 'th', nameKo: '태국어', nameEn: 'Thai', flag: '🇹🇭'),
    LanguageInfo(code: 'ru', nameKo: '러시아어', nameEn: 'Russian', flag: '🇷🇺'),
    LanguageInfo(code: 'id', nameKo: '인도네시아어', nameEn: 'Indonesian', flag: '🇮🇩'),
    LanguageInfo(code: 'ar', nameKo: '아랍어', nameEn: 'Arabic', flag: '🇦🇪'),
  ];

  static const Map<String, String> languages = {
    'ko': '한국어',
    'en': '영어',
    'ja': '일본어',
    'zh': '중국어',
    'es': '스페인어',
    'fr': '프랑스어',
    'de': '독일어',
    'vi': '베트남어',
    'th': '태국어',
    'ru': '러시아어',
    'id': '인도네시아어',
    'ar': '아랍어',
  };
}
