import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/translation_constants.dart';
import '../../core/services/gemini_translation_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../auth/auth_modal.dart';
import '../history/history_modal.dart';
import '../camera_ocr/camera_ocr_modal.dart';
import '../speech/speech_modal.dart';
import '../conversation/conversation_modal.dart';
import '../premium/paywall_bottom_sheet.dart';
import '../premium/ad_banner_widget.dart';
import '../premium/premium_state.dart';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

final apiKeyProvider = StateProvider<String>((ref) => '');
final sourceLangProvider = StateProvider<String>((ref) => 'ko');
final targetLangProvider = StateProvider<String>((ref) => 'en');
final inputTextProvider = StateProvider<String>((ref) => '');
final translatedTextProvider = StateProvider<String>((ref) => '');
final isLoadingProvider = StateProvider<bool>((ref) => false);

class TranslationScreen extends ConsumerStatefulWidget {
  const TranslationScreen({super.key});

  @override
  ConsumerState<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends ConsumerState<TranslationScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();

  void _showSpeechModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SpeechModal(
        onSpeechRecognized: (recognizedText) {
          _controller.text = recognizedText;
          ref.read(inputTextProvider.notifier).state = recognizedText;
          _translate();
        },
      ),
    );
  }

  void _showConversationModal() {
    final isPro = ref.read(isProUserProvider);
    if (!isPro) {
      showPaywallBottomSheet(context);
      return;
    }

    final sourceLang = ref.read(sourceLangProvider);
    final targetLang = ref.read(targetLangProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ConversationModal(
        sourceLang: sourceLang,
        targetLang: targetLang,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _warmupWebVoices();
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _warmupWebVoices() {
    try {
      final synth = web.window.speechSynthesis;
      synth.getVoices();
      synth.onvoiceschanged = ((JSObject e) {}).toJS;
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;

    final targetLang = ref.read(targetLangProvider);
    final Map<String, String> langMap = {
      'ko': 'ko-KR',
      'en': 'en-US',
      'ja': 'ja-JP',
      'zh': 'zh-CN',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'vi': 'vi-VN',
      'th': 'th-TH',
      'ru': 'ru-RU',
      'id': 'id-ID',
      'ar': 'ar-SA',
    };
    final langCode = langMap[targetLang] ?? 'en-US';

    if (kIsWeb) {
      try {
        final synth = web.window.speechSynthesis;

        // 첫 새로고침 시 Chrome 원어민 보이스 비동기 로딩 대기
        var voices = synth.getVoices().toDart;
        if (voices.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 150));
          voices = synth.getVoices().toDart;
        }

        final utterance = web.SpeechSynthesisUtterance(text);
        utterance.lang = langCode;
        utterance.rate = 0.95;
        utterance.pitch = 1.0;

        // Chrome의 Google 고음질 원어민 보이스 우선 지정
        for (final voice in voices) {
          if (voice.lang.startsWith(targetLang) ||
              voice.lang.contains(langCode)) {
            if (voice.name.contains('Google')) {
              utterance.voice = voice;
              break;
            }
          }
        }

        synth.cancel();
        synth.speak(utterance);
        return;
      } catch (e) {
        try {
          final encodedText = Uri.encodeComponent(text);
          final audio = web.HTMLAudioElement();
          audio.src =
              'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$targetLang&q=$encodedText';
          audio.play();
          return;
        } catch (_) {}
      }
    }

    try {
      await _flutterTts.setLanguage(langCode);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  void _swapLanguages() {
    final source = ref.read(sourceLangProvider);
    final target = ref.read(targetLangProvider);
    ref.read(sourceLangProvider.notifier).state = target;
    ref.read(targetLangProvider.notifier).state = source;

    final input = _controller.text;
    final translated = ref.read(translatedTextProvider);
    if (translated.isNotEmpty) {
      _controller.text = translated;
      ref.read(translatedTextProvider.notifier).state = input;
    }
  }

  void _clearAllInputs() {
    _controller.clear();
    ref.read(inputTextProvider.notifier).state = '';
    ref.read(translatedTextProvider.notifier).state = '';
  }

  Future<void> _translate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(isLoadingProvider.notifier).state = true;

    final apiKey = ref.read(apiKeyProvider);
    final service = GeminiTranslationService(apiKey: apiKey);

    final sourceLang = ref.read(sourceLangProvider);
    final targetLang = ref.read(targetLangProvider);
    final result = await service.translate(
      text: text,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );

    ref.read(translatedTextProvider.notifier).state = result;
    ref.read(isLoadingProvider.notifier).state = false;

    // 히스토리 자동 저장
    ref.read(historyProvider.notifier).addHistory(
          HistoryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sourceText: text,
            translatedText: result,
            sourceLang: sourceLang,
            targetLang: targetLang,
            timestamp: DateTime.now(),
          ),
        );
  }

  void _showCameraOcrModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CameraOcrModal(
        onTextExtracted: (extractedText) {
          _controller.text = extractedText;
          ref.read(inputTextProvider.notifier).state = extractedText;
          _translate();
        },
      ),
    );
  }

  void _showApiKeyDialog() {
    _apiKeyController.text = ref.read(apiKeyProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Gemini API 키 설정',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '현재 시스템 기본 제공 API 키로 100% 자동 작동 중입니다.\n개별 전용 키를 사용하고 싶으신 경우 아래에 입력하세요.',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  hintText: '미입력 시 기본 제공 API 사용 중 (개별 키 입력 가능)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),

              // API 키 발급 방법 가이드 카드
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.help_outline_rounded,
                            size: 18, color: Colors.indigo),
                        SizedBox(width: 6),
                        Text(
                          '💡 무료 API 키 발급 방법 (10초 소요)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '1. Google AI Studio (aistudio.google.com) 접속\n'
                      '2. 구글 계정으로 로그인\n'
                      '3. [Get API key] ➔ [Create API key] 클릭\n'
                      '4. 발급된 키(AIzaSy...)를 위 입력창에 붙여넣기',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        if (kIsWeb) {
                          try {
                            web.window.open(
                              'https://aistudio.google.com/app/apikey',
                              '_blank',
                            );
                          } catch (_) {}
                        }
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.open_in_new_rounded,
                              size: 14, color: Colors.indigo),
                          SizedBox(width: 4),
                          Text(
                            'Google AI Studio 바로가기 🔗',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(apiKeyProvider.notifier).state =
                  _apiKeyController.text.trim();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gemini API 키가 저장되었습니다.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceLang = ref.watch(sourceLangProvider);
    final targetLang = ref.watch(targetLangProvider);
    final translatedText = ref.watch(translatedTextProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final isPro = ref.watch(isProUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PolyGlot AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.record_voice_over_rounded),
            onPressed: _showConversationModal,
            tooltip: '2인 대화 번역 모드',
          ),
          IconButton(
            icon: const Icon(Icons.key_rounded),
            onPressed: _showApiKeyDialog,
            tooltip: 'API 키 설정',
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => HistoryModal(
                  onSelectHistoryItem: (item) {
                    _controller.text = item.sourceText;
                    ref.read(inputTextProvider.notifier).state = item.sourceText;
                    ref.read(sourceLangProvider.notifier).state = item.sourceLang;
                    ref.read(targetLangProvider.notifier).state = item.targetLang;
                    _translate();
                  },
                ),
              );
            },
            tooltip: '번역 기록',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => const AuthModal(),
              );
            },
            tooltip: '프로필 / 로그인',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            
            // Usage limit info for free tier
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isPro 
                      ? '👑 PRO 요금제 사용 중: 무제한 번역 및 실시간 대화방 가능'
                      : '무료 요금제: 일일 번역 25회 (대화방 PRO 전용)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPro ? Colors.amber.shade700 : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isPro ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (!isPro)
                    InkWell(
                      onTap: () => showPaywallBottomSheet(context),
                      child: Text(
                        'PRO 업그레이드',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Language Bar (12개 다국어 선택 & 50% 정중앙 스왑)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Source Language Popup Menu (오직 [🇰🇷 한국어 ▾] 영역 클릭시에만 팝업)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: PopupMenuButton<String>(
                          onSelected: (code) {
                            if (code == targetLang) {
                              _swapLanguages();
                            } else {
                              ref.read(sourceLangProvider.notifier).state = code;
                            }
                          },
                          itemBuilder: (context) {
                            return TranslationConstants.supportedLanguages
                                .map((lang) => PopupMenuItem<String>(
                                      value: lang.code,
                                      child: Row(
                                        children: [
                                          Text(lang.flag,
                                              style: const TextStyle(fontSize: 18)),
                                          const SizedBox(width: 10),
                                          Text(lang.nameKo,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 6),
                                          Text('(${lang.nameEn})',
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ))
                                .toList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  TranslationConstants.supportedLanguages
                                      .firstWhere((l) => l.code == sourceLang,
                                          orElse: () => TranslationConstants
                                              .supportedLanguages.first)
                                      .flag,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  TranslationConstants.languages[sourceLang] ??
                                      sourceLang,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down_rounded,
                                    color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Center Swap Button
                    IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded),
                      onPressed: _swapLanguages,
                      tooltip: '언어 전환',
                    ),

                    // Target Language Popup Menu (오직 [영어 🇺🇸 ▾] 영역 클릭시에만 팝업)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<String>(
                          onSelected: (code) {
                            if (code == sourceLang) {
                              _swapLanguages();
                            } else {
                              ref.read(targetLangProvider.notifier).state = code;
                            }
                          },
                          itemBuilder: (context) {
                            return TranslationConstants.supportedLanguages
                                .map((lang) => PopupMenuItem<String>(
                                      value: lang.code,
                                      child: Row(
                                        children: [
                                          Text(lang.flag,
                                              style: const TextStyle(fontSize: 18)),
                                          const SizedBox(width: 10),
                                          Text(lang.nameKo,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 6),
                                          Text('(${lang.nameEn})',
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ))
                                .toList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  TranslationConstants.languages[targetLang] ??
                                      targetLang,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  TranslationConstants.supportedLanguages
                                      .firstWhere((l) => l.code == targetLang,
                                          orElse: () => TranslationConstants
                                              .supportedLanguages[1])
                                      .flag,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down_rounded,
                                    color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Input & Output Cards
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Input Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _controller,
                              minLines: 7,
                              maxLines: 14,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                              ),
                              decoration: const InputDecoration(
                                hintText: '번역할 내용을 입력하세요...',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              onChanged: (val) {
                                setState(() {});
                                ref.read(inputTextProvider.notifier).state = val;
                                if (val.trim().isEmpty) {
                                  ref.read(translatedTextProvider.notifier).state = '';
                                }
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.mic_none_rounded),
                                      onPressed: _showSpeechModal,
                                      tooltip: '음성 입력',
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.camera_alt_outlined),
                                      onPressed: _showCameraOcrModal,
                                      tooltip: '이미지 번역',
                                    ),
                                    if (_controller.text.isNotEmpty ||
                                        translatedText.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: _clearAllInputs,
                                        tooltip: '전체 지우기',
                                      ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed:
                                      isLoading ? null : _translate,
                                  icon: isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.translate_rounded),
                                  label: const Text('번역하기'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Result Output Card
                    if (translatedText.isNotEmpty || isLoading)
                      Card(
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '번역 결과',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Icons.volume_up_outlined,
                                            size: 20),
                                        onPressed: () => _speak(translatedText),
                                        tooltip: '듣기',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.copy_rounded,
                                            size: 20),
                                        onPressed: () {},
                                        tooltip: '복사',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                translatedText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!isPro)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: AdBannerWidget(),
              ),
          ],
        ),
      ),
    );
  }
}
