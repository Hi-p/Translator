import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:web/web.dart' as web;
import 'dart:js_interop';

class SpeechModal extends StatefulWidget {
  final Function(String recognizedText) onSpeechRecognized;

  const SpeechModal({
    super.key,
    required this.onSpeechRecognized,
  });

  @override
  State<SpeechModal> createState() => _SpeechModalState();
}

class _SpeechModalState extends State<SpeechModal>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _recognizedText = '';
  late AnimationController _animationController;
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  web.SpeechRecognition? _webRecognition;

  final List<String> _sampleSpeechPresets = [
    '안녕하세요, 오늘 날씨가 정말 따뜻하고 좋네요.',
    'Can you recommend a good Italian restaurant nearby?',
    '이 제품의 보증 기간과 수리 정책에 대해 설명해 주세요.',
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  Future<void> _initSpeech() async {
    if (kIsWeb) return;
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
          }
        },
        onError: (_) {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechAvailable = available;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (!kIsWeb) {
      _speech.stop();
    } else {
      try {
        _webRecognition?.stop();
      } catch (_) {}
    }
    super.dispose();
  }

  void _listen() async {
    if (_isListening) {
      if (kIsWeb) {
        try {
          _webRecognition?.stop();
        } catch (_) {}
      } else {
        await _speech.stop();
      }
      setState(() {
        _isListening = false;
      });
      return;
    }

    // 웹(Chrome) 환경에서의 마이크 인식 (Web Speech API)
    if (kIsWeb) {
      try {
        final recognition = web.SpeechRecognition();
        _webRecognition = recognition;
        recognition.continuous = false;
        recognition.interimResults = true;
        recognition.lang = 'ko-KR';

        setState(() {
          _isListening = true;
          _recognizedText = '듣고 있습니다... 말씀해 주세요.';
        });

        recognition.onresult = ((web.SpeechRecognitionEvent event) {
          final results = event.results;
          if (results.length > 0) {
            final res = results.item(0);
            if (res.length > 0) {
              final alt = res.item(0);
              if (mounted) {
                setState(() {
                  _recognizedText = alt.transcript;
                });
              }
            }
          }
        }).toJS;

        recognition.onerror = ((JSObject error) {
          if (mounted) {
            setState(() {
              _isListening = false;
              if (_recognizedText.startsWith('듣고')) {
                _recognizedText = '마이크 권한을 허용해 주시거나 다시 눌러주세요.';
              }
            });
          }
        }).toJS;

        recognition.onend = ((JSObject e) {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        }).toJS;

        recognition.start();
        return;
      } catch (e) {
        // Web Speech API 미지원 시 사용자 직접 입력 텍스트 안내
        setState(() {
          _isListening = false;
          _recognizedText = '마이크 권한 허용 후 다시 눌러주세요.';
        });
        return;
      }
    }

    // 모바일/네이티브 환경 마이크 인식
    if (_speechAvailable) {
      setState(() {
        _isListening = true;
        _recognizedText = '듣고 있는 중입니다...';
      });

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _recognizedText = result.recognizedWords;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
        ),
      );
    }
  }

  void _selectPreset(String presetText) {
    if (_isListening) {
      if (kIsWeb) {
        try {
          _webRecognition?.stop();
        } catch (_) {}
      } else {
        _speech.stop();
      }
    }
    setState(() {
      _isListening = false;
      _recognizedText = presetText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.mic_rounded, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text(
                    '음성 입력 (STT)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 마이크 버튼
          GestureDetector(
            onTap: _listen,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final scale =
                    _isListening ? 1.0 + (_animationController.value * 0.25) : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? Colors.redAccent
                          : Theme.of(context).primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening
                                  ? Colors.redAccent
                                  : Theme.of(context).primaryColor)
                              .withValues(alpha: 0.4),
                          blurRadius: _isListening ? 20 : 8,
                          spreadRadius: _isListening ? 6 : 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isListening ? '마이크에 대고 말씀하세요 (터치하여 중지)' : '마이크를 터치하여 실제 음성 인식 시작',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _isListening ? Colors.redAccent : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // 인식된 텍스트 카드 (실시간 받아쓰기)
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '✓ 실시간 음성 인식 결과',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      if (_recognizedText.isNotEmpty && !_isListening)
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _recognizedText.isEmpty
                            ? '마이크를 눌러 말씀하시거나 아래 샘플을 선택하세요.'
                            : _recognizedText,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: _recognizedText.isEmpty ? Colors.grey : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 빠른 음성 테스트 샘플
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _sampleSpeechPresets.length,
              itemBuilder: (context, index) {
                final preset = _sampleSpeechPresets[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      preset,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _selectPreset(preset),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 번역 적용 버튼
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_recognizedText.isEmpty || _isListening)
                  ? null
                  : () {
                      widget.onSpeechRecognized(_recognizedText);
                      Navigator.pop(context);
                    },
              icon: const Icon(Icons.translate_rounded),
              label: const Text('인식된 음성 번역하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
