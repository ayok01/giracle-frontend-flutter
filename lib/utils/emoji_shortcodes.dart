import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shortcode → unicode emoji lookup, populated once from the bundled
/// `emojibase` dataset (same source as `emoji-picker-element`, which Giracle's
/// Solid client uses for reactions).
class EmojiShortcodes {
  const EmojiShortcodes(this._map);
  final Map<String, String> _map;

  String? lookup(String shortcode) => _map[shortcode.toLowerCase()];

  static Future<EmojiShortcodes> load() async {
    try {
      final raw = await rootBundle.loadString('assets/emoji_shortcodes.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final map = <String, String>{
        for (final entry in decoded.entries) entry.key: entry.value as String,
      };
      return EmojiShortcodes(map);
    } catch (_) {
      return const EmojiShortcodes({});
    }
  }
}

final emojiShortcodesProvider = Provider<EmojiShortcodes>((ref) {
  throw UnimplementedError('emojiShortcodesProvider must be overridden');
});
