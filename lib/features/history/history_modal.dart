import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryItem {
  final String id;
  final String sourceText;
  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final DateTime timestamp;
  final bool isFavorite;

  const HistoryItem({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    required this.timestamp,
    this.isFavorite = false,
  });

  HistoryItem copyWith({bool? isFavorite}) {
    return HistoryItem(
      id: id,
      sourceText: sourceText,
      translatedText: translatedText,
      sourceLang: sourceLang,
      targetLang: targetLang,
      timestamp: timestamp,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceText': sourceText,
        'translatedText': translatedText,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'timestamp': timestamp.toIso8601String(),
        'isFavorite': isFavorite,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] ?? '',
        sourceText: json['sourceText'] ?? '',
        translatedText: json['translatedText'] ?? '',
        sourceLang: json['sourceLang'] ?? 'ko',
        targetLang: json['targetLang'] ?? 'en',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
        isFavorite: json['isFavorite'] ?? false,
      );
}

class HistoryNotifier extends StateNotifier<List<HistoryItem>> {
  static const String _prefsKey = 'polyglot_translation_history';

  HistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        state = list.map((item) => HistoryItem.fromJson(item)).toList();
      }
    } catch (_) {}
  }

  Future<void> _saveHistory(List<HistoryItem> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr =
          jsonEncode(list.map((item) => item.toJson()).toList());
      await prefs.setString(_prefsKey, jsonStr);
    } catch (_) {}
  }

  void addHistory(HistoryItem item) {
    // 중복 추가 방지 (상단 이동)
    final filtered = state.where((h) => h.sourceText != item.sourceText).toList();
    final updated = [item, ...filtered];
    state = updated;
    _saveHistory(updated);
  }

  void toggleFavorite(String id) {
    final updated = [
      for (final item in state)
        if (item.id == id) item.copyWith(isFavorite: !item.isFavorite) else item
    ];
    state = updated;
    _saveHistory(updated);
  }

  void deleteHistory(String id) {
    final updated = state.where((item) => item.id != id).toList();
    state = updated;
    _saveHistory(updated);
  }

  void clearAll() {
    state = [];
    _saveHistory([]);
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryItem>>((ref) {
  return HistoryNotifier();
});

class HistoryModal extends ConsumerStatefulWidget {
  final Function(HistoryItem item)? onSelectHistoryItem;

  const HistoryModal({super.key, this.onSelectHistoryItem});

  @override
  ConsumerState<HistoryModal> createState() => _HistoryModalState();
}

class _HistoryModalState extends ConsumerState<HistoryModal> {
  String _searchQuery = '';
  bool _onlyFavorites = false;

  @override
  Widget build(BuildContext context) {
    final historyList = ref.watch(historyProvider);

    final filteredList = historyList.where((item) {
      final matchesQuery = item.sourceText
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          item.translatedText
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      final matchesFavorite = !_onlyFavorites || item.isFavorite;
      return matchesQuery && matchesFavorite;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text(
                    '번역 히스토리',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (historyList.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(historyProvider.notifier).clearAll();
                      },
                      child: const Text(
                        '전체 삭제',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '목록의 번역 기록을 터치하면 해당 문장이 번역창에 바로 채워집니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // 검색 & 필터
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '번역 기록 검색...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                    SizedBox(width: 4),
                    Text('즐겨찾기'),
                  ],
                ),
                selected: _onlyFavorites,
                onSelected: (selected) {
                  setState(() {
                    _onlyFavorites = selected;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 히스토리 리스트
          Expanded(
            child: filteredList.isEmpty
                ? const Center(
                    child: Text(
                      '저장된 번역 기록이 없습니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            widget.onSelectHistoryItem?.call(item);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${item.sourceLang.toUpperCase()} → ${item.targetLang.toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            item.isFavorite
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color: item.isFavorite
                                                ? Colors.amber
                                                : Colors.grey,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            ref
                                                .read(historyProvider.notifier)
                                                .toggleFavorite(item.id);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            ref
                                                .read(historyProvider.notifier)
                                                .deleteHistory(item.id);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(
                                  item.sourceText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.translatedText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
