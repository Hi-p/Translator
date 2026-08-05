import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/translation_constants.dart';

class GeminiTranslationService {
  static const String defaultSystemApiKey = '';

  final String? apiKey;

  GeminiTranslationService({this.apiKey});

  Future<String> _translateViaGoogleFreeEngine(
      String text, String sourceLang, String targetLang) async {
    try {
      final encodedText = Uri.encodeComponent(text);
      final url = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=$encodedText');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty && data[0] is List) {
          final StringBuffer sb = StringBuffer();
          for (var item in data[0]) {
            if (item is List && item.isNotEmpty) {
              sb.write(item[0].toString());
            }
          }
          final translatedResult = sb.toString().trim();
          if (translatedResult.isNotEmpty) {
            return translatedResult;
          }
        }
      }
    } catch (_) {}
    return 'Translated: $text';
  }

  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final activeApiKey =
        (apiKey != null && apiKey!.trim().isNotEmpty) ? apiKey!.trim() : defaultSystemApiKey;

    final sourceLangName = TranslationConstants.languages[sourceLang] ?? sourceLang;
    final targetLangName = TranslationConstants.languages[targetLang] ?? targetLang;

    if (activeApiKey.startsWith('AIzaSy')) {
      final systemInstruction = '''
You are an expert translator.
Translate text from $sourceLangName to $targetLangName.
Output ONLY the translated text without any explanation, quotes, or introduction.
''';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$activeApiKey',
      );

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': systemInstruction}
              ]
            },
            'contents': [
              {
                'parts': [
                  {'text': text}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.2,
              'maxOutputTokens': 1024,
            }
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'].toString().trim();
            }
          }
        }
      } catch (_) {}
    }

    // 기본 시스템 무상 딥러닝 번역 엔진 (Google Neural Translation API)
    return await _translateViaGoogleFreeEngine(text, sourceLang, targetLang);
  }
}
