import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'app.dart';
import 'utils/emoji_shortcodes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create();
  final shortcodes = await EmojiShortcodes.load();

  runApp(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        emojiShortcodesProvider.overrideWithValue(shortcodes),
      ],
      child: const GiracleApp(),
    ),
  );
}
