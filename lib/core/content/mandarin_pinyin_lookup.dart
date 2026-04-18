import 'dart:convert';

import 'package:flutter/services.dart';

class MandarinPinyinLookup {
  static Map<String, String>? _cache;

  static Future<Map<String, String>> load() async {
    if (_cache != null) return _cache!;

    try {
      final raw = await rootBundle.loadString('assets/mandarin_words.json');
      final decoded = jsonDecode(raw) as List<dynamic>;
      final map = <String, String>{};

      for (final entry in decoded.whereType<Map<String, dynamic>>()) {
        final word = (entry['word'] ?? '').toString().trim();
        final pinyin = (entry['pinyin'] ?? '').toString().trim();
        if (word.isEmpty || pinyin.isEmpty) continue;
        map[word] = pinyin;
      }

      _cache = map;
      return map;
    } catch (_) {
      _cache = <String, String>{};
      return _cache!;
    }
  }
}
