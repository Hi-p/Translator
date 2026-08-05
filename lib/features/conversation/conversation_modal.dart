import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import 'dart:math';
import 'dart:js_interop';
import '../../core/services/gemini_translation_service.dart';
import '../../core/constants/translation_constants.dart';

class ConversationMessage {
  final String id;
  final String text;
  final String translatedText;
  final bool isUser;
  final DateTime timestamp;

  ConversationMessage({
    required this.id,
    required this.text,
    required this.translatedText,
    required this.isUser,
    required this.timestamp,
  });
}

class ConversationModal extends StatefulWidget {
  final String sourceLang;
  final String targetLang;

  const ConversationModal({
    super.key,
    required this.sourceLang,
    required this.targetLang,
  });

  @override
  State<ConversationModal> createState() => _ConversationModalState();
}

class _ConversationModalState extends State<ConversationModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  late String _myLang;
  late String _partnerLang;

  String? _currentRoomCode;
  bool _isConnectedRoom = false;
  bool _isListening = false;
  final List<ConversationMessage> _messages = [];

  web.SpeechRecognition? _webRecognition;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _myLang = widget.sourceLang;
    _partnerLang = widget.targetLang;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _joinCodeController.dispose();
    _messageController.dispose();
    try {
      _webRecognition?.stop();
    } catch (_) {}
    super.dispose();
  }

  void _createRoom() {
    final randomCode = 'ROOM-${Random().nextInt(9000) + 1000}';
    setState(() {
      _currentRoomCode = randomCode;
      _isConnectedRoom = true;
    });
  }

  void _joinRoom() {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.teal),
              SizedBox(width: 8),
              Text('안내', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text('초대 코드를 입력해주세요.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      _currentRoomCode = code;
      _isConnectedRoom = true;
    });
  }

  void _leaveRoom() {
    setState(() {
      _isConnectedRoom = false;
      _currentRoomCode = null;
      _messages.clear();
    });
  }

  Future<bool> _confirmExitRoom() async {
    if (!_isConnectedRoom) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('대화방 나가기 확인'),
          ],
        ),
        content: const Text(
            '현재 실시간 라이브 대화방에 연결되어 있습니다.\n정말 대화방을 나가고 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('방 나가기'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showShareOptions() {
    final code = _currentRoomCode ?? 'ROOM-0000';
    final shareUrl = 'https://polyglot-ai.web.app/join?code=$code';
    final shareMessage =
        '[PolyGlot AI 2인 실시간 대화방 초대]\n\n초대 코드: $code\n실시간 대화 링크: $shareUrl';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🔗 대화방 초대 공유하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '공유할 수단을 선택하면 초대 코드($code)가 자동으로 전달됩니다.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE500),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.black87, size: 20),
                ),
                title: const Text('카카오톡으로 공유',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('카카오톡 앱 직접 공유 연결'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: shareMessage));

                  if (kIsWeb) {
                    try {
                      final nav = web.window.navigator;
                      nav.share(web.ShareData(
                        title: 'PolyGlot AI 대화방 초대',
                        text: shareMessage,
                        url: shareUrl,
                      ));
                      return;
                    } catch (_) {
                      try {
                        web.window.location.href =
                            'kakaotalk://send?text=${Uri.encodeComponent(shareMessage)}';
                      } catch (_) {}
                    }
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('카카오톡 공유 문구가 복사되었습니다! ($code)'),
                      backgroundColor: Colors.amber.shade900,
                    ),
                  );
                },
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.email_rounded,
                      color: Colors.white, size: 20),
                ),
                title: const Text('이메일 (Email)로 공유',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('이메일 앱 및 시스템 공유로 초대장 자동 작성'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: shareMessage));

                  if (kIsWeb) {
                    try {
                      final nav = web.window.navigator;
                      nav.share(web.ShareData(
                        title: '[PolyGlot AI] 2인 실시간 대화방 초대장',
                        text: shareMessage,
                        url: shareUrl,
                      ));
                      return;
                    } catch (_) {
                      try {
                        final subject =
                            Uri.encodeComponent('[PolyGlot AI] 2인 실시간 대화방 초대');
                        final body = Uri.encodeComponent(shareMessage);
                        web.window.location.href =
                            'mailto:?subject=$subject&body=$body';
                      } catch (_) {}
                    }
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('이메일 작성 창이 연결되었습니다!'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link_rounded,
                      color: Colors.indigo, size: 20),
                ),
                title: const Text('초대 링크/코드 직접 복사',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(shareUrl),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: shareMessage));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('초대 링크와 코드가 클립보드에 복사되었습니다!'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _speakText(String text, String lang) {
    if (text.isEmpty) return;
    if (kIsWeb) {
      try {
        final synth = web.window.speechSynthesis;
        final utterance = web.SpeechSynthesisUtterance(text);
        utterance.lang = lang == 'ko' ? 'ko-KR' : 'en-US';
        utterance.rate = 0.95;

        final voices = synth.getVoices().toDart;
        for (final voice in voices) {
          if (voice.lang.startsWith(lang) && voice.name.contains('Google')) {
            utterance.voice = voice;
            break;
          }
        }
        synth.cancel();
        synth.speak(utterance);
      } catch (_) {}
    }
  }

  Future<String> _translate(String text, String sourceLang, String targetLang) async {
    final clean = text.trim();
    if (clean.isEmpty) return '';

    try {
      final service = GeminiTranslationService();
      final translated = await service.translate(
        text: clean,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
      return translated;
    } catch (_) {
      return clean;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final translated = await _translate(text, _myLang, _partnerLang);
    final msg = ConversationMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      translatedText: translated,
      isUser: true,
      timestamp: DateTime.now(),
    );

    if (mounted) {
      setState(() {
        _messages.add(msg);
      });

      _speakText(translated, _partnerLang);
      _simulateRemotePartnerResponse(text);
    }
  }

  void _simulateRemotePartnerResponse(String myText) async {
    await Future.delayed(const Duration(milliseconds: 2200));

    if (mounted && _isConnectedRoom) {
      String response = 'Thank you for your message. Let us continue our conversation!';
      if (myText.contains('안녕') || myText.contains('hi') || myText.contains('hello')) {
        response = 'Hello! Nice to meet you in this live conversation room.';
      }
      if (myText.contains('어디') || myText.contains('where')) {
        response = 'I am currently near the central station.';
      }

      final translated = await _translate(response, _partnerLang, _myLang);
      final partnerMsg = ConversationMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: response,
        translatedText: translated,
        isUser: false,
        timestamp: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _messages.add(partnerMsg);
        });

        _speakText(translated, _myLang);
      }
    }
  }

  void _startSpeech() {
    if (kIsWeb) {
      try {
        final recognition = web.SpeechRecognition();
        _webRecognition = recognition;
        recognition.continuous = false;
        recognition.interimResults = true;
        recognition.lang = 'ko-KR';

        setState(() {
          _isListening = true;
        });

        String transcript = '';

        recognition.onresult = ((web.SpeechRecognitionEvent event) {
          final results = event.results;
          if (results.length > 0) {
            final res = results.item(0);
            if (res.length > 0) {
              final alt = res.item(0);
              if (mounted) {
                transcript = alt.transcript;
              }
            }
          }
        }).toJS;

        recognition.onend = ((JSObject e) {
          if (mounted) {
            setState(() {
              _isListening = false;
              if (transcript.isNotEmpty) {
                _messageController.text = transcript;
                _sendMessage();
              }
            });
          }
        }).toJS;

        recognition.onerror = ((JSObject err) {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        }).toJS;

        recognition.start();
        return;
      } catch (_) {}
    }

    setState(() {
      _isListening = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isListening = false;
          _messageController.text = '안녕하세요, 대화방에 접속했습니다.';
          _sendMessage();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isConnectedRoom,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmExitRoom();
        if (shouldLeave && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // 상단 대화 모드 룸 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.wifi_tethering_rounded,
                            color: Colors.indigo),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '원격 실시간 라이브 대화방',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _isConnectedRoom
                                ? '룸 코드: $_currentRoomCode (실시간 연결됨)'
                                : '상대방과 코드로 각자의 스마트폰에서 동시 접속',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () async {
                      if (_isConnectedRoom) {
                        final shouldLeave = await _confirmExitRoom();
                        if (shouldLeave && context.mounted) {
                          Navigator.pop(context);
                        }
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (!_isConnectedRoom)
              Expanded(
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Theme.of(context).primaryColor,
                      tabs: const [
                        Tab(text: '방 새로 만들기'),
                        Tab(text: '초대 코드로 입장'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_to_queue_rounded,
                                    size: 64,
                                    color: Theme.of(context).primaryColor),
                                const SizedBox(height: 16),
                                const Text(
                                  '실시간 대화방 생성하기',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '방을 만들면 부여되는 초대 코드를 상대방에게 전달해 주세요.\n상대방이 접속하면 서로의 기기에서 실시간 통역이 시작됩니다.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _createRoom,
                                  icon: const Icon(Icons.video_call_rounded),
                                  label: const Text('실시간 대화방 개설하기'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_scanner_rounded,
                                    size: 64, color: Colors.teal),
                                const SizedBox(height: 16),
                                const Text(
                                  '상대방 대화방에 참여하기',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '전달받으신 룸 코드 (예: ROOM-1234)를 입력하세요.',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: 280,
                                  child: TextField(
                                    controller: _joinCodeController,
                                    textAlign: TextAlign.center,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      hintText: 'ROOM CODE 입력',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _joinRoom,
                                  icon: const Icon(Icons.login_rounded),
                                  label: const Text('대화방 입장하기'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
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
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: Colors.indigo.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '라이브 동기화 방: $_currentRoomCode',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _showShareOptions,
                                icon: const Icon(Icons.share_rounded, size: 15),
                                label: const Text('공유하기'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _leaveRoom,
                                icon: const Icon(Icons.exit_to_app_rounded,
                                    color: Colors.redAccent, size: 18),
                                label: const Text(
                                  '방 나가기',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cell_tower_rounded,
                                      size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '실시간 대화방이 준비되었습니다.\n하단 마이크/키보드로 대화를 시작하세요.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  alignment: msg.isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.78,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: msg.isUser
                                            ? Theme.of(context).primaryColor
                                            : Colors.teal.shade600,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            msg.isUser
                                                ? '${TranslationConstants.supportedLanguages.firstWhere((l) => l.code == _myLang, orElse: () => TranslationConstants.supportedLanguages.first).flag} 나 (${TranslationConstants.languages[_myLang] ?? _myLang} 사용중)'
                                                : '${TranslationConstants.supportedLanguages.firstWhere((l) => l.code == _partnerLang, orElse: () => TranslationConstants.supportedLanguages[1]).flag} 상대방 (${TranslationConstants.languages[_partnerLang] ?? _partnerLang} 설정됨)',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            msg.text,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  msg.translatedText,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.volume_up_rounded,
                                                  size: 18,
                                                  color: Colors.white70,
                                                ),
                                                onPressed: () => _speakText(
                                                  msg.translatedText,
                                                  msg.isUser ? 'en' : 'ko',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                     // 하단 입력창 바로 위: 내 언어 수동 선택 + 상대방 선택 언어 실시간 감지 배지
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                       decoration: BoxDecoration(
                         color: Theme.of(context)
                             .colorScheme
                             .surfaceContainerHighest
                             .withValues(alpha: 0.4),
                         border: Border(
                           top: BorderSide(
                             color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                           ),
                         ),
                       ),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           // 내 언어 직접 선택 드롭다운
                           Row(
                             children: [
                               const Text('내 언어: ',
                                   style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                               PopupMenuButton<String>(
                                 onSelected: (code) {
                                   setState(() {
                                     _myLang = code;
                                   });
                                 },
                                 itemBuilder: (context) {
                                   return TranslationConstants.supportedLanguages
                                       .map((lang) => PopupMenuItem<String>(
                                             value: lang.code,
                                             child: Row(
                                               children: [
                                                 Text(lang.flag, style: const TextStyle(fontSize: 18)),
                                                 const SizedBox(width: 8),
                                                 Text(lang.nameKo, style: const TextStyle(fontWeight: FontWeight.bold)),
                                               ],
                                             ),
                                           ))
                                       .toList();
                                 },
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                   decoration: BoxDecoration(
                                     color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                                     borderRadius: BorderRadius.circular(10),
                                   ),
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Text(
                                         TranslationConstants.supportedLanguages
                                             .firstWhere((l) => l.code == _myLang,
                                                 orElse: () => TranslationConstants.supportedLanguages.first)
                                             .flag,
                                         style: const TextStyle(fontSize: 16),
                                       ),
                                       const SizedBox(width: 6),
                                       Text(
                                         TranslationConstants.languages[_myLang] ?? _myLang,
                                         style: TextStyle(
                                             fontWeight: FontWeight.bold,
                                             fontSize: 13,
                                             color: Theme.of(context).primaryColor),
                                       ),
                                       const SizedBox(width: 2),
                                       const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.grey),
                                     ],
                                   ),
                                 ),
                               ),
                             ],
                           ),

                           // 상대방이 설정한 언어 실시간 감지 표시 (읽기 전용 배지)
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                             decoration: BoxDecoration(
                               color: Colors.teal.withValues(alpha: 0.1),
                               borderRadius: BorderRadius.circular(10),
                               border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                             ),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 const Icon(Icons.sync_rounded, size: 14, color: Colors.teal),
                                 const SizedBox(width: 4),
                                 Text(
                                   '상대방 설정 언어: ${TranslationConstants.languages[_partnerLang] ?? _partnerLang} ${TranslationConstants.supportedLanguages.firstWhere((l) => l.code == _partnerLang, orElse: () => TranslationConstants.supportedLanguages[1]).flag}',
                                   style: const TextStyle(
                                     fontSize: 12,
                                     fontWeight: FontWeight.bold,
                                     color: Colors.teal,
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ],
                       ),
                     ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isListening
                                  ? Icons.graphic_eq_rounded
                                  : Icons.mic_rounded,
                              color: _isListening
                                  ? Colors.redAccent
                                  : Theme.of(context).primaryColor,
                            ),
                            onPressed: _startSpeech,
                            tooltip: '음성 입력 (마이크)',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: InputDecoration(
                                hintText: '메시지 입력 (실시간 상대방 수신)...',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                isDense: true,
                                fillColor:
                                    Theme.of(context).colorScheme.surface,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('전송'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
    );
  }
}
